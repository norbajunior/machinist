defmodule Machinist do
  @external_resource "README.md"

  @moduledoc """
  `Machinist` is a small library that allows you to implement finite state
  machines in a simple way. It provides a simple DSL to write combinations of
  transitions based on events.

  #{File.read!("README.md") |> String.split("<!-- MDOC -->") |> Enum.fetch!(1)}
  """

  @doc false
  defmacro __using__(_) do
    quote do
      @__attr__ :state

      @behaviour Machinist.Transition

      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Defines a block of transitions.

  By default `transitions/1` expects the module using `Machinist` has a struct
  defined with a `state` attribute

      transitions do
        # ...
      end
  """
  defmacro transitions(do: block) do
    quote do
      @__struct__ __MODULE__

      unquote(block)
    end
  end

  @doc """
  Defines a block of transitions for a specific struct or defines a block of
  transitions just passing the `attr` option to define the attribute holding the state

  ## Examples

  ### A Candidate being handled by two different versions of a SelectionProcess

      defmodule Candidate do
        defstruct state: :new
      end

      defmodule SelectionProcess.V1 do
        use Machinist

        transitions Candidate do
          from :new, to: :registered, event: "register"
        end
      end

      defmodule SelectionProcess.V2 do
        use Machinist

        transitions Candidate do
          from :new, to: :enrolled, event: "enroll"
        end
      end

  ### Providing the `attr` option to define the attribute holding the state

      defmodule Candidate do
        defstruct candidate_state: :new

        use Machinist

        transitions attr: :candidate_state do
          from :new, to: :registered, event: "register"
        end
      end
  """
  defmacro transitions(list_or_struct, block)

  defmacro transitions([attr: attr], do: block) do
    quote do
      @__attr__ unquote(attr)
      @__struct__ __MODULE__

      unquote(block)
    end
  end

  defmacro transitions(struct, do: block) do
    quote do
      @__struct__ unquote(struct)

      unquote(block)
    end
  end

  @doc """
  Defines a block of transitions for a specific struct with `attr` option
  defining the attribute holding the state

      transitions Candidate, attr: :candidate_state do
        # ...
      end
  """
  defmacro transitions(struct, [attr: attr], do: block) do
    quote do
      @__attr__ unquote(attr)
      @__struct__ unquote(struct)

      unquote(block)
    end
  end

  @doc """
  Defines a state transition with the given `state`, and the list of options `[to: new_state, event: event]`

      from 1, to: 2, event: "next"

  It's also possible to define a `from` any state transition to another specific one, by just passing an underscore variable in place of a real state value

      from _state, to: :expired, event: "enrollment_expired"
  """
  defmacro from(state, do: {_, _line, to_statements}) do
    define_transitions(state, to_statements)
  end

  defmacro from(state, to: new_state, event: event) do
    define_transition(state, to: new_state, event: event)
  end

  @doc false
  defp define_transitions(_state, []), do: []

  @doc false
  defp define_transitions(state, [{:to, _line, [new_state, [event: event]]} | transitions]) do
    [
      define_transition(state, to: new_state, event: event)
      | define_transitions(state, transitions)
    ]
  end

  @doc false
  defp define_transition(state, to: new_state, event: event) do
    quote do
      @impl true
      def transit(%@__struct__{@__attr__ => unquote(state)} = resource, event: unquote(event)) do
        value = __set_new_state__(resource, unquote(new_state))

        {:ok, Map.put(resource, @__attr__, value)}
      end
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote do
      @impl true
      def transit(_resource, _opts) do
        {:error, :not_allowed}
      end

      defp __set_new_state__(resource, new_state) do
        if is_function(new_state) do
          new_state.(resource)
        else
          new_state
        end
      end
    end
  end
end
