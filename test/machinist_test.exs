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

    test "__states__/0" do
      assert Example1.__states__() == [1, 2, 3]
    end

    test "__events__/0" do
      assert Example1.__events__() == ~w(next)
    end

    test "__transitions__/0" do
      assert Example1.__transitions__() == [
               [from: 1, to: 2, event: "next"],
               [from: 2, to: 3, event: "next"]
             ]
    end
  end

  describe "an example with custom state attribute" do
    defmodule Example2 do
      defstruct step: 1

      use Machinist

      transitions attr: :step do
        from(1, to: 2, event: "next")
        from(2, to: 3, event: "next")
      end
    end

    test "all transitions" do
      assert {:ok, %Example2{step: 2} = step_2} = Example2.transit(%Example2{}, event: "next")
      assert {:ok, %Example2{step: 3} = step_3} = Example2.transit(step_2, event: "next")

      assert {:error, :not_allowed} = Example2.transit(step_3, event: "next")
    end

    test "__states__/0" do
      assert Example2.__states__() == [1, 2, 3]
    end

    test "__events__/0" do
      assert Example2.__events__() == ~w(next)
    end

    test "__transitions__/0" do
      assert Example2.__transitions__() == [
               [from: 1, to: 2, event: "next"],
               [from: 2, to: 3, event: "next"]
             ]
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

    test "__states__/0" do
      assert SelectionProcess.V1.__states__() == ~w(new registered enrolled)a
      assert SelectionProcess.V2.__states__() == ~w(new registered interviewed enrolled)a
    end

    test "__events__/0" do
      assert SelectionProcess.V1.__events__() == ~w(register enroll)
      assert SelectionProcess.V2.__events__() == ~w(register interviewed enroll)
    end

    test "__transitions__/0" do
      assert SelectionProcess.V1.__transitions__() == [
               [from: :new, to: :registered, event: "register"],
               [from: :registered, to: :enrolled, event: "enroll"]
             ]

      assert SelectionProcess.V2.__transitions__() == [
               [from: :new, to: :registered, event: "register"],
               [from: :registered, to: :interviewed, event: "interviewed"],
               [from: :interviewed, to: :enrolled, event: "enroll"]
             ]
    end
  end

  describe "an example of a module handling a different struct with custom state attr" do
    defmodule User do
      defstruct step: 1
    end

    defmodule Example4 do
      use Machinist

      transitions User, attr: :step do
        from(1, to: 2, event: "next")
      end
    end

    test "all transitions" do
      {:ok, %User{step: 2} = user_step2} = Example4.transit(%User{}, event: "next")
      {:error, :not_allowed} = Example4.transit(user_step2, event: "next")
    end

    test "__states__/0" do
      assert Example4.__states__() == [1, 2]
    end

    test "__events__/0" do
      assert Example4.__events__() == ~w(next)
    end

    test "__transitions__/0" do
      assert Example4.__transitions__() == [[from: 1, to: 2, event: "next"]]
    end
  end

  describe "an example of a transition from any state to a specific one" do
    defmodule Example5 do
      defstruct state: :new

      use Machinist

      transitions do
        from(:new, to: :registered, event: "register")
        from(:registered, to: :interview_scheduled, event: "schedule_interview")

        from :interview_scheduled do
          to(:approved, event: "approve_interview")
          to(:reproved, event: "reprove_interview")
        end

        from(:approved, to: :enrolled, event: "enroll")
        from(_state, to: :application_expired, event: "application_expired")
      end
    end

    test "all transitions" do
      {:ok, %Example5{state: :application_expired}} =
        Example5.transit(%Example5{state: :new}, event: "application_expired")

      {:ok, %Example5{state: :application_expired}} =
        Example5.transit(%Example5{state: :registered}, event: "application_expired")

      {:ok, %Example5{state: :application_expired}} =
        Example5.transit(%Example5{state: :interview_scheduled}, event: "application_expired")

      {:ok, %Example5{state: :application_expired}} =
        Example5.transit(%Example5{state: :approved}, event: "application_expired")
    end

    test "__states__/0" do
      assert Example5.__states__() ==
               ~w(new registered interview_scheduled approved reproved enrolled)a
    end

    test "__events__/0" do
      assert Example5.__events__() ==
               ~w(register schedule_interview approve_interview reprove_interview enroll application_expired)
    end

    test "__transitions__/0" do
      assert Example5.__transitions__() == [
               [from: :new, to: :registered, event: "register"],
               [from: :registered, to: :interview_scheduled, event: "schedule_interview"],
               [from: :interview_scheduled, to: :approved, event: "approve_interview"],
               [from: :interview_scheduled, to: :reproved, event: "reprove_interview"],
               [from: :approved, to: :enrolled, event: "enroll"],
               [from: :new, to: :application_expired, event: "application_expired"],
               [from: :registered, to: :application_expired, event: "application_expired"],
               [
                 from: :interview_scheduled,
                 to: :application_expired,
                 event: "application_expired"
               ],
               [from: :approved, to: :application_expired, event: "application_expired"],
               [from: :reproved, to: :application_expired, event: "application_expired"],
               [from: :enrolled, to: :application_expired, event: "application_expired"]
             ]
    end
  end

  describe "a example with passing a block of transitions to from" do
    defmodule Example6 do
      defstruct state: :test

      use Machinist

      transitions do
        from(:test, to: :test1, event: "test1")

        from :test1 do
          to(:test2, event: "test2")
          to(:test3, event: "test3")
          to(:test4, event: "test4")
        end
      end
    end

    test "all transitions" do
      IO.inspect(Example6.__transitions__())
      assert {:ok, example} = Example6.transit(%Example6{}, event: "test1")
      assert {:ok, %Example6{state: :test2}} = Example6.transit(example, event: "test2")
      assert {:ok, %Example6{state: :test3}} = Example6.transit(example, event: "test3")
      assert {:ok, %Example6{state: :test4}} = Example6.transit(example, event: "test4")
    end

    test "__states__/0" do
      assert Example6.__states__() == ~w(test test1 test2 test3 test4)a
    end

    test "__events__/0" do
      assert Example6.__events__() == ~w(test1 test2 test3 test4)
    end

    test "__transitions__/0" do
      assert Example6.__transitions__() == [
               [from: :test, to: :test1, event: "test1"],
               [from: :test1, to: :test2, event: "test2"],
               [from: :test1, to: :test3, event: "test3"],
               [from: :test1, to: :test4, event: "test4"]
             ]
    end
  end
end
