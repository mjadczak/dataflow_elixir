defmodule Dataflow.PTransform do
  @moduledoc """

  """

  alias Dataflow.Pipeline.NestedInput
  alias Dataflow.PValue

  @callback apply(transform :: struct, input :: Dataflow.Pipeline.NestedState.t) :: Dataflow.PValue.value

  defmacro __using__(opts) do
    code =
      [
        quote do
          @behaviour unquote(__MODULE__)
          alias unquote(__MODULE__)
          import unquote(__MODULE__), only: [fresh_pvalue: 1]
          import Dataflow, only: [~>: 2]
        end
      ]

    using =
      case Keyword.get opts, :make_fun do
        nil -> []
        funs when is_list(funs) ->
          [
            quote do
              defmacro __using__(_opts) do
                funs = unquote(funs)
                quote do
                  import unquote(__MODULE__), only: unquote(funs)
                end
              end
            end
          ]
      end

    quote do unquote_splicing(code ++ using) end
  end

  def fresh_pvalue(%NestedInput{state: state}) do
    #todo LABEL????

    %PValue{
      id: NestedInput.fresh_id(state),
      #label: ???,
      producer: NestedInput.peek_context(state)
    }
  end

end