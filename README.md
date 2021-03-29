# Machinist

This  is a small library that allows you to implement finite state machines with Elixir in a simple way. It provides a simple DSL for declaring combinations of transitions based on events.

* [Installation](#Installation)
* [Usage](#Usage)
* [Documentation](https://hexdocs.pm/machinist)

## Installation

You can install `machinist` by adding it  to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:machinist, "~> 0.1.0"}
  ]
end
```

## Usage

A good example is how we would implement the behaviour of a door. With `machinist` would be this way:

```elixir
def House.Door do
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
```

By defining this rules we get the function `Door.transit/2` to transit between states. This function returns either `{:ok, struct_with_new_state}` or `{:error, message}`. Lets see this in practice:

By default our `Door` is `locked`

```elixir
iex> door = %House.Door{}
%Door{state: :locked}
```

So lets change its state to `unlocked`

```elixir
iex> {:ok, door} = House.Door.transit(door, event: "unlock")
{:ok, %Door{state: :unlocked}}
```

If we try to make a transition that not follow the rules, we get an error:

```elixir
iex> House.Door.transit(door, event: "close")
{:error, "can't transit from unlocked to closed"}
```

### Setting different field name that holds the state

By default `machinist` expects the struct or map passed as the first argument has the key `state`, if you hold state in a different field, just pass the name as an atom, as follow:

```elixir
transitions field: :door_state do
  # ...
end
```

And then `machinist` will set state in that field

```elixir
iex> House.Door.transit(door, event: "unlock")
{:ok, %Door{door_state: :unlocked}}
```

### Implementing different versions of a state machine

Let's suppose we want to build a selection process app that handles applications of candidates and they may possibly going through different versions of the process. For example:

A Selection Process **V1** with the following sequence of stages: [Registration] -> [**Code test**] -> [Enrollment]

And a Selection Process **V2** with these ones: [Registration] -> [**Interview**] -> [Enrollment]

The difference here is in **V1** candidates must take a **Code Test** and V2 an **Interview**.

So, we could have a `%Candidate{}` struct that holds these fields:

```elixir
defmodule SelectionProcess.Candidate do
  defstruct [:name, :state, test_score: 0]
end
```

And a `SelectionProcess` module that implements the state machine. Notice this time we don't want to implement the rules in the module that holds the state, in this case it makes more sense the `SelectionProcess` keep the rules, also because we want more than one state machine version handling candidates as mentioned before. This is our **V1** of the process:

```elixir
defmodule SelectionProcess.V1 do
  use Machinist

  alias SelectionProcess.Candidate

  @minimum_score 100

  transitions do
    from :new,           to: :registered,    event: "register"
    from :registered,    to: :started_test,  event: "start_test"
    from :started_test,  to: &check_score/1, event: "send_test"
    from :test_approved, to: :enrolled,      event: "enroll"
  end

  defp check_score(%Candidate{test_score: score}) do
    if score >= @minimum_score, do: :test_approved, else: :test_reproved
  end
end
```

Also notice we can pass a *function* to the option `to:` instead of an *atom*, in order to decide the state based on the candidate `test_score` value.

Internally  `machinist` calls the func by providing the same first parameter of `transit/2` function.

In the **version 2**, we replaced the `Code Test` stage by the `Interview` that has some states.

```elixir
defmodule SelectionProcess.V2 do
  use Machinist

  alias __MODULE__.Candidate

  transitions do
    from :new,                 to: :registered,          event: "register"
    from :registered,          to: :interview_scheduled, event: "schedule_interview"
    from :interview_scheduled, to: :approved,            event: "approve_interview"
    from :interview_scheduled, to: :repproved,           event: "reprove_interview"
    from :approved,            to: :enrolled,            event: "enroll"
  end
end
```

Now lets see how this could be used:

**V1:** A `registered` candidate wants to start its test.

```elixir
iex> candidate1 = %Candidate{name: "Ada", state: :registered}
iex> SelectionProcess.V1.transit(candidate1, event: "start_test")
%{:ok, %Candidate{state: :test_started}}
```

**V2:** A `registered` candidate wants to schedule the interview

```elixir
iex> candidate2 = %Candidate{name: "John Doe", state: :registered}
iex> SelectionProcess.V2.transit(candidate1, event: "schedule_interview")
%{:ok, %Candidate{state: :interview_scheduled}}
```

That's great because we also can implement many state machines for only one entity and test different scenarios, evaluate and collect data for deciding which one is better.

`machinist` gives us this flexibility since it's just pure Elixir.
