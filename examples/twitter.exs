use Dataflow
alias Dataflow.Transforms.{Core, IO, Windowing, Aggregation}
alias Dataflow.DirectRunner

alias Dataflow.Utils.Time, as: DTime
require DTime

parse_as_timestamp = fn string ->
  string
  |> Timex.parse!("{WDshort} {Mshort} {0D} {h24}:{0m}:{0s} {Z} {YYYY}")
  |> DateTime.to_unix
  |> DTime.timestamp(:seconds)
end

p = Pipeline.new runner: DirectRunner

p
~> "Read Stream" -- IO.read_stream(fn -> ExTwitter.stream_filter(track: "tech,technology,Apple,Google,Twitter,Facebook,Microsoft,iPhone,Mac,Android,computers,CompSci,science", language: "en") end)
~> "Extract Timestamps" -- Windowing.with_timestamps(&parse_as_timestamp.(&1.created_at), delay_watermark: {30, :seconds, :event_time})

# The Java version combines stream reading and extraction, so to keep the comparison valid,
# duplicate tweets after both have been done.

~> Core.flat_map(fn tweet -> for _ <- 1..1000, do: tweet end)

~> "Window Elements" -- Windowing.window(into: {:sliding, size: {3, :minutes}, period: {15, :seconds}})
~> "Extract Hashtags" -- Core.flat_map(fn tweet ->
  case tweet.entities[:hashtags] do
    nil -> []
    [] -> []
    list ->
      list
      |> Enum.map(fn %{text: text} -> text end)
  end
 end)
~> Aggregation.count_elements()
~> "Generate Prefixes" -- Core.flat_map(fn {tag, count} ->
  len = String.length tag
  for i <- 0..(len-1), downcased = String.downcase(tag), prefix = String.slice(downcased, 0..i), do: {prefix, {tag, count}}
 end)
~> Aggregation.top_per_key(3, compare: fn {_tag1, count1}, {_tag2, count2} -> count1 <= count2 end)
~> "Discard Exact Counts" -- Core.map(fn {prefix, tcs} -> {prefix, Enum.map(tcs, fn {tag, _count} -> tag end)} end)
#~> "DisplayDebug" -- %Core.ParDo{do_fn: %Dataflow.Transforms.Fns.DoFn{process: fn el -> Apex.ap(el); [] end}}
~> Core.each(fn x -> Elixir.IO.puts "#{inspect x}" end)
#~> IO.send_to_process(autocomplete, mode: :batch)

Pipeline.run p, sync: true
#Dataflow.Utils.PipelineVisualiser.visualise p
#Apex.ap Pipeline._get_state(p)
