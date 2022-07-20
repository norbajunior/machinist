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
  Defines an `event` block grouping a same-event `from` -> `to` transitions
  with a guard function that should evaluates a condition and returns a new state.

      event "update_score"", guard: &check_score/1 do
        from :test, to: :approved
        from :test, to: :reproved
      end

      defp check_score(%{score: score}) do
        if score >= 70, do: :approved, else: :reproved
      end
  """
  defmacro event(event, [guard: func], do: {:__block__, line, content}) do
    content = prepare_transitions(event, func, content)

    quote bind_quoted: [content: content, line: line] do
      {:__block__, line, content}
    end
  end

  defmacro event(_event, _f, do: {:from, _line, [_from, [do: _block]]} = content) do
    raise Machinist.NoLongerSupportedSyntaxError, content
  end

  @doc """
  Defines an `event` block grouping a same-event `from` -> `to` transitions

      event "form_submitted" do
        from :form1, to: :form2
        from :form2, to: :test
      end
  """
  defmacro event(event, do: {:__block__, line, content}) do
    content = prepare_transitions(event, content)

    quote bind_quoted: [content: content, line: line] do
      {:__block__, line, content}
    end
  end

  defmacro event(event, do: content) do
    content = prepare_transition(event, content)

    quote bind_quoted: [content: content] do
      [do: content]
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

  defmacro from(state, to: {:&, _, _} = new_state_func, event: event) do
    raise Machinist.NoLongerSupportedSyntaxError,
      state: state,
      to: new_state_func,
      event: event
  end

  defmacro from(state, to: new_state, event: event) do
    define_transition(state, to: new_state, event: event)
  end

  defp prepare_transitions(_event, []), do: []

  defp prepare_transitions(event, [head | tail]) do
    [prepare_transition(event, head) | prepare_transitions(event, tail)]
  end

  defp prepare_transitions(event, guard_func, [head | _]) do
    prepare_transition(event, guard_func, head)
  end

  defp prepare_transition(event, {:from, _line, [from, to]}) do
    define_transition(from, to ++ [event: event])
  end

  defp prepare_transition(event, guard_func, {:from, _line, [from, _to]}) do
    define_transition(from, to: guard_func, event: event)
  end

  defp define_transitions(_state, []), do: []

  defp define_transitions(state, [{:to, _line, [new_state, [event: event]]} | transitions]) do
    [
      define_transition(state, to: new_state, event: event)
      | define_transitions(state, transitions)
    ]
  end

  defp define_transitions(state, [{:&, _, _} = new_state_func, [event: event]]) do
    raise Machinist.NoLongerSupportedSyntaxError,
      state: state,
      to: new_state_func,
      event: event
  end

  defp define_transition(state, to: new_state, event: event) do
    quote do
      @impl true
      def transit(%@__struct__{@__attr__ => unquote(state)} = resource, event: unquote(event)) do
        value = __set_new_state__(resource, unquote(new_state))

        {:ok, Map.put(resource, @__attr__, value)}
      end
    end
  end

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

defmodule Machinist.NoLongerSupportedSyntaxError do
  defexception [:message]

  @impl true
  def exception({:from, _line, [from, [do: block]]} = content) do
    {:__block__, _line, to_statements} = block

    new_dsl =
      for {_, _line, to} <- to_statements do
        "from(:#{from}, to: #{List.first(to)})\n"
      end

    msg = """

    #{IO.ANSI.reset()}`event` block can't support `from` blocks inside anymore

    Instead of this:

    #{Macro.to_string(content)}

    Do this:

    #{new_dsl}
    """

    %__MODULE__{message: msg}
  end

  @impl true
  def exception(state: state, to: new_state_func, event: event) do
    new_dsl = ~s"""
    event "#{event}", guard: #{Macro.to_string(new_state_func)} do
      from :#{state}, to: :your_new_state
    end
    """

    msg = """

    #{IO.ANSI.reset()}`from` macro does not accept a function as a value to `:to` anymore

    Instead use the `event` macro passing the function as a guard option:

    #{new_dsl}
    """

    %__MODULE__{message: msg}
  end
end
