defmodule MachinistTest do
  use ExUnit.Case, async: true
  # doctest Machinist

  describe "a default example" do
    defmodule Example1 do
      defstruct state: 1

      use Machinist

      transitions do
        from(1, to: 2, event: "next")
        from(2, to: 3, event: "next")
      end
    end

    test "all transitions" do
      assert {:ok, %Example1{state: 2} = step_2} = Example1.transit(%Example1{}, event: "next")
      assert {:ok, %Example1{state: 3} = step_3} = Example1.transit(step_2, event: "next")

      assert {:error, :not_allowed} = Example1.transit(step_3, event: "next")
    end
  end

  describe "an example with custom state field" do
    defmodule Example2 do
      defstruct step: 1

      use Machinist

      transitions field: :step do
        from(1, to: 2, event: "next")
        from(2, to: 3, event: "next")
      end
    end

    test "all transitions" do
      assert {:ok, %Example2{step: 2} = step_2} = Example2.transit(%Example2{}, event: "next")
      assert {:ok, %Example2{step: 3} = step_3} = Example2.transit(step_2, event: "next")

      assert {:error, :not_allowed} = Example2.transit(step_3, event: "next")
    end
  end

  describe "an example with two modules handling the same struct" do
    defmodule Candidate do
      defstruct state: :new
    end

    defmodule SelectionProcess.V1 do
      defstruct step: 1

      use Machinist

      transitions Candidate do
        from(:new, to: :registered, event: "register")
        from(:registered, to: :enrolled, event: "enroll")
      end
    end

    defmodule SelectionProcess.V2 do
      defstruct step: 1

      use Machinist

      transitions Candidate do
        from(:new, to: :registered, event: "register")
        from(:registered, to: :interviewed, event: "interviewed")
        from(:interviewed, to: :enrolled, event: "enroll")
      end
    end

    test "all transitions for V1" do
      {:ok, %Candidate{state: :registered} = registered_candidate} =
        SelectionProcess.V1.transit(%Candidate{}, event: "register")

      {:ok, %Candidate{state: :enrolled} = enrolled_candidate} =
        SelectionProcess.V1.transit(registered_candidate, event: "enroll")

      {:error, :not_allowed} =
        SelectionProcess.V1.transit(registered_candidate, event: "register")

      {:error, :not_allowed} = SelectionProcess.V1.transit(enrolled_candidate, event: "enroll")
    end

    test "all transitions for V2" do
      {:ok, %Candidate{state: :registered} = registered_candidate} =
        SelectionProcess.V2.transit(%Candidate{}, event: "register")

      {:ok, %Candidate{state: :interviewed} = interviewed_candidate} =
        SelectionProcess.V2.transit(registered_candidate, event: "interviewed")

      {:ok, %Candidate{state: :enrolled} = enrolled_candidate} =
        SelectionProcess.V2.transit(interviewed_candidate, event: "enroll")

      {:error, :not_allowed} = SelectionProcess.V2.transit(%Candidate{}, event: "enroll")

      {:error, :not_allowed} =
        SelectionProcess.V2.transit(registered_candidate, event: "register")

      {:error, :not_allowed} = SelectionProcess.V2.transit(enrolled_candidate, event: "enroll")
      {:error, :not_allowed} = SelectionProcess.V2.transit(enrolled_candidate, event: "register")
    end
  end

  describe "an example a module handling a different struct with custom state attr" do
    defmodule User do
      defstruct step: 1
    end

    defmodule Example4 do
      use Machinist

      transitions User, field: :step do
        from(1, to: 2, event: "next")
      end
    end

    test "all transitions" do
      {:ok, %User{step: 2} = user_step2} = Example4.transit(%User{}, event: "next")
      {:error, :not_allowed} = Example4.transit(user_step2, event: "next")
    end
  end
end
