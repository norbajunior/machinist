defmodule Machinist do
  @moduledoc """
  `Machinist` is a small library that allows you to implement finite state machines
  in a simple way. It provides a simple DSL to write combinations of
  transitions based on events.

  A good example is how we would implement the functioning of a door. With `machinist` would be this way:

      defmodule Door do
        defstruct [state: :locked]

        use Machinist

        transitions do
          from :locked,   to: :unlocked, event: "unlock"
          from :unlocked, to: :locked,   event: "lock"
          from :unlocked, to: :opened,   event: "open"
          from :opened,   to: :closed,   event: "close"
          from :closed,   to: :opened,   event: "open"
          from :closed,   to: :locked,   event: "lock"
        end
      end

  By defining this rules with `transitions` and `from` macros, `machinist` generates and inject into the module `Door` `transit/2` functions like this one:

      def transit(%Door{state: :locked} = struct, event: "unlock") do
        {:ok, %Door{struct | state: :unlocked}}
      end

  _The functions `transit/2` implements the behaviour_ `Machinist.Transition`

  So that we can transit between states by relying on the **state** + **event** pattern matching.

  Let's see this in practice:

  By default our `Door` is `locked`

      iex> door_locked = %Door{}
      iex> %Door{state: :locked}

  So let's change its state to `unlocked` and `opened`

      iex> {:ok, door_unlocked} = Door.transit(door_locked, event: "unlock")
      iex> {:ok, %Door{state: :unlocked}}
      iex> {:ok, door_opened} = Door.transit(door_unlocked, event: "open")
      iex> {:ok, %Door{state: :opened}}

  If we try to make a transition that not follow the rules, we got an error:


      iex> Door.transit(door_opened, event: "lock")
      iex> {:error, :not_allowed}

  ### Group same-state `from` definitions

  In the example above we also could group the `from :unlocked` definitions like this:

      # ...
      transitions do
        from :locked,   to: :unlocked, event: "unlock"
        from :unlocked do
          to :locked, event: "lock"
          to :opened, event: "open"
        end
        from :opened,   to: :closed,   event: "close"
        from :closed,   to: :opened,   event: "open"
        from :closed,   to: :locked,   event: "lock"
      end
      # ...

  This is an option for a better organization and an increase of readability when having
  a large number of `from` definitions with a same state.

  ### Setting different attribute name that holds the state

  By default `machinist` expects the struct being updated holds a `state` attribute,
  if you hold state in a different attribute, just pass the name as an atom, as follows:


      transitions attr: :door_state do
        # ...
      end

  And then `machinist` will set state in that attribute


      iex> Door.transit(door, event: "unlock")
      iex> {:ok, %Door{door_state: :unlocked}}

  ### Implementing different versions of a state machine

  Let's suppose we want to build a selection process app that handles applications
  of candidates and they may possibly going through different versions of the process. For example:

  A Selection Process **V1** with the following sequence of stages: [Registration] -> [**Code test**] -> [Enrollment]

  And a Selection Process **V2** with these ones: [Registration] -> [**Interview**] -> [Enrollment]

  The difference here is in **V1** candidates must take a **Code Test** and V2 an **Interview**.

  So, we could have a `%Candidate{}` struct that holds these attributes:


      defmodule SelectionProcess.Candidate do
        defstruct [:name, :state, test_score: 0]
      end

  And a `SelectionProcess` module that implements the state machine.
  Notice this time we don't want to implement the rules in the module that holds
  the state, in this case it makes more sense the `SelectionProcess` keep the rules,
  also because we want more than one state machine version handling candidates as mentioned before.
  This is our **V1** of the process:

      defmodule SelectionProcess.V1 do
        use Machinist

        alias SelectionProcess.Candidate

        @minimum_score 100

        transitions Candidate do
          from :new,           to: :registered,    event: "register"
          from :registered,    to: :started_test,  event: "start_test"
          from :started_test,  to: &check_score/1, event: "send_test"
          from :approved,      to: :enrolled,      event: "enroll"
        end

        defp check_score(%Candidate{test_score: score}) do
          if score >= @minimum_score, do: :approved, else: :reproved
        end
      end

  In this code we pass the `Candidate` module as a parameter to `transitions`
  to tell `machinist` that we expect `V1.transit/2` functions with a `%Candidate{}`
  struct as first argument and not the `%SelectionProcess.V1{}` which would be by default.

      def transit(%Candidate{state: :new} = struct, event: "register") do
        {:ok, %Candidate{struct | state: :registered}}
      end

  Also notice we provided the *function* `&check_score/1` to the option `to:` instead of an *atom*, in order to decide the state based on the candidate `test_score` value.

  In the **version 2**, we replaced the `Code Test` stage by the `Interview` which has different state transitions:

      defmodule SelectionProcess.V2 do
        use Machinist

        alias SelectionProcess.Candidate

        transitions Candidate do
          from :new,                 to: :registered,          event: "register"
          from :registered,          to: :interview_scheduled, event: "schedule_interview"
          from :interview_scheduled, to: :approved,            event: "approve_interview"
          from :interview_scheduled, to: :repproved,           event: "reprove_interview"
          from :approved,            to: :enrolled,            event: "enroll"
        end
      end

  Now let's see how this could be used:

  **V1:** A `registered` candidate wants to start its test.

      iex> candidate1 = %Candidate{name: "Ada", state: :registered}
      iex> SelectionProcess.V1.transit(candidate1, event: "start_test")
      iex> %{:ok, %Candidate{state: :test_started}}

  **V2:** A `registered` candidate wants to schedule the interview

      iex> candidate2 = %Candidate{name: "Jose", state: :registered}
      iex> SelectionProcess.V2.transit(candidate1, event: "schedule_interview")
      iex> %{:ok, %Candidate{state: :interview_scheduled}}

  That's great because we also can implement many state machines for only one
  entity and test different scenarios, evaluate and collect data for deciding which one is better.

  `machinist` gives us this flexibility since it's just pure Elixir.

  ### Transiting from any state to another

  Sometimes we need to define a `from` _any state_ transition.

  Still in the selection process example, a candidate can abandon the process in a given state and we want to be able to transit him/her to `application_expired` from any state. To do so we just define a `from` with an underscore variable in order the current state to be ignored.

      defmodule SelectionProcess.V2 do
        use Machinist

        alias SelectionProcess.Candidate

        transitions Candidate do
          # ...
          from _state, to: :application_expired, event: "application_expired"
        end
      end

  ## How does the DSL works?

  The use of `transitions` in combination with each `from` statement will be
  transformed in functions that will be injected into the module that is using `machinist`.

  This implementation:

      defmodule Door do
        defstruct state: :locked

        use Machinist

        transitions do
          from :locked,   to: :unlocked, event: "unlock"
          from :unlocked, to: :locked,   event: "lock"
          from :unlocked, to: :opened,   event: "open"
          from :opened,   to: :closed,   event: "close"
          from :closed,   to: :opened,   event: "open"
          from :closed,   to: :locked,   event: "lock"
        end
      end

  is the same as:

      defmodule Door do
        defstruct state: :locked

        def transit(%__MODULE__{state: :locked} = struct, event: "unlock") do
          {:ok, %__MODULE__{struct | state: :unlocked}}
        end

        def transit(%__MODULE__{state: :unlocked} = struct, event: "lock") do
          {:ok, %__MODULE__{struct | state: :locked}}
        end

        def transit(%__MODULE__{state: :unlocked} = struct, event: "open") do
          {:ok, %__MODULE__{struct | state: :opened}}
        end

        def transit(%__MODULE__{state: :opened} = struct, event: "close") do
          {:ok, %__MODULE__{struct | state: :closed}}
        end

        def transit(%__MODULE__{state: :closed} = struct, event: "open") do
          {:ok, %__MODULE__{struct | state: :opened}}
        end

        def transit(%__MODULE__{state: :closed} = struct, event: "lock") do
          {:ok, %__MODULE__{struct | state: :locked}}
        end
        # a catchall function in case of unmatched clauses
        def transit(_, _), do: {:error, :not_allowed}
      end

  So, as we can see, we can eliminate a lot of boilerplate with `machinist` making
  it easier to maintain and less prone to errors.
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

      defp __set_new_state__(resource, new_state) when is_function(new_state) do
        new_state.(resource)
      end

      defp __set_new_state__(_, new_state), do: new_state
    end
  end
end
