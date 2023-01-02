defmodule MachinistTest do
  use ExUnit.Case, async: true

  describe "a default example" do
    defmodule Example1 do
      defstruct state: 1

      use Machinist

      transitions do
        from 1, to: 2, event: "next"
        from 2, to: 3, event: "next"
      end
    end

    test "all transitions" do
      assert {:ok, %Example1{state: 2} = step_2} = Example1.transit(%Example1{}, event: "next")
      assert {:ok, %Example1{state: 3} = step_3} = Example1.transit(step_2, event: "next")

      assert {:error, :not_allowed} = Example1.transit(step_3, event: "next")
    end
  end

  describe "an example with custom state attribute" do
    defmodule Example2 do
      defstruct step: 1

      use Machinist

      transitions attr: :step do
        from 1, to: 2, event: "next"
        from 2, to: 3, event: "next"
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
        from :new, to: :registered, event: "register"
        from :registered, to: :enrolled, event: "enroll"
      end
    end

    defmodule SelectionProcess.V2 do
      defstruct step: 1

      use Machinist

      transitions Candidate do
        from :new, to: :registered, event: "register"
        from :registered, to: :interviewed, event: "interviewed"
        from :interviewed, to: :enrolled, event: "enroll"
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

  describe "an example of a module handling a different struct with custom state attr" do
    defmodule User do
      defstruct step: 1
    end

    defmodule Example4 do
      use Machinist

      transitions User, attr: :step do
        from 1, to: 2, event: "next"
      end
    end

    test "all transitions" do
      {:ok, %User{step: 2} = user_step2} = Example4.transit(%User{}, event: "next")
      {:error, :not_allowed} = Example4.transit(user_step2, event: "next")
    end
  end

  describe "an example of a transition from any state to a specific one" do
    defmodule Example5 do
      defstruct state: :new

      use Machinist

      transitions do
        from :new, to: :registered, event: "register"
        from :registered, to: :interview_scheduled, event: "schedule_interview"

        from :interview_scheduled do
          to :approved, event: "approve_interview"
          to :repproved, event: "reprove_interview"
        end

        from :approved, to: :enrolled, event: "enroll"
        from _state, to: :application_expired, event: "application_expired"
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
  end

  describe "a example with passing a block of transitions to from" do
    defmodule Example6 do
      defstruct state: :test

      use Machinist

      transitions do
        from(:test, to: :test1, event: "test1")

        from :test1 do
          to :test2, event: "test2"
          to :test3, event: "test3"
          to :test4, event: "test4"
        end
      end
    end

    test "all transitions" do
      assert {:ok, example} = Example6.transit(%Example6{}, event: "test1")
      assert {:ok, %Example6{state: :test2}} = Example6.transit(example, event: "test2")
      assert {:ok, %Example6{state: :test3}} = Example6.transit(example, event: "test3")
      assert {:ok, %Example6{state: :test4}} = Example6.transit(example, event: "test4")
    end
  end

  describe "an example of an event block" do
    defmodule Example7 do
      defstruct status: nil, state: :new

      use Machinist

      transitions do
        from :new, to: :form, event: "start"

        event "form_submitted" do
          from :form, to: :form2
          from :form2, to: :tests_in_progress
        end

        event "update_test_score", guard: &check_status/1 do
          from :tests_in_progress, to: :tests_in_progress
          from :tests_in_progress, to: :tests_reproved
          from :tests_in_progress, to: :tests_approved
        end
      end

      defp check_status(%Example7{status: :approved}) do
        :tests_approved
      end

      defp check_status(%Example7{status: :reproved}) do
        :tests_reproved
      end

      defp check_status(%Example7{status: :in_progress}) do
        :tests_in_progress
      end
    end

    test "transits from new to form" do
      assert {:ok, %Example7{state: :form}} = Example7.transit(%Example7{}, event: "start")
    end

    test "transits from form to form2" do
      assert {:ok, %Example7{state: :form2}} =
               Example7.transit(%Example7{state: :form}, event: "form_submitted")
    end

    test "transits from test_in_progress to approved" do
      example = %Example7{state: :tests_in_progress, status: :approved}

      assert {:ok, %Example7{state: :tests_approved}} =
               Example7.transit(example, event: "update_test_score")
    end

    test "transits from test_in_progress to reproved" do
      example = %Example7{state: :tests_in_progress, status: :reproved}

      assert {:ok, %Example7{state: :tests_reproved}} =
               Example7.transit(example, event: "update_test_score")
    end

    test "transits from test_in_progress to test_in_progress" do
      example = %Example7{state: :tests_in_progress, status: :in_progress}

      assert {:ok, %Example7{state: :tests_in_progress}} =
               Example7.transit(example, event: "update_test_score")
    end
  end

  describe "an example of a from block within an event block" do
    @error_message """

    \e[0m`event` block can't support `from` blocks inside anymore

    Instead of this:

    from(:tests_approved) do
      to(:interview_1)
      to(:interview_2)
    end

    Do this:

    from(:tests_approved, to: interview_1)
    from(:tests_approved, to: interview_2)

    """

    test "raises an error when using this deprecated form" do
      assert_raise Machinist.NoLongerSupportedSyntaxError, @error_message, fn ->
        defmodule Example8 do
          defstruct status: nil, state: :tests_in_progress

          use Machinist

          transitions do
            event "start_interview", guard: &which_interview/1 do
              from :tests_approved do
                to :interview_1
                to :interview_2
              end
            end
          end

          defp which_interview(example8) do
            :interview_1
          end
        end
      end
    end
  end

  describe "an example of a :to option with a func as an unsupported value" do
    @error_message """

    \e[0m`from` macro does not accept a function as a value to `:to` anymore

    Instead use the `event` macro passing the function as a guard option:

    event "start_interview", guard: &which_interview/1 do
      from :score_updated, to: :your_new_state
    end

    """

    test "raises an error when using this deprecated form" do
      assert_raise Machinist.NoLongerSupportedSyntaxError, @error_message, fn ->
        defmodule Example9 do
          defstruct score: 0, state: :new

          use Machinist

          transitions do
            from :score_updated, to: &which_interview/1, event: "start_interview"
          end

          defp which_interview(%Example9{score: score}) do
            if score >= 70, do: :interview_1, else: :interview_2
          end
        end
      end
    end
  end

  describe "an example of a `from` block with a :to option with a func as an unsupported value" do
    @error_message """

    \e[0m`from` macro does not accept a function as a value to `:to` anymore

    Instead use the `event` macro passing the function as a guard option:

    event "start_interview", guard: &which_interview/1 do
      from :score_updated, to: :your_new_state
    end

    """

    test "raises an error when using this deprecated form" do
      assert_raise Machinist.NoLongerSupportedSyntaxError, @error_message, fn ->
        defmodule Example10 do
          defstruct score: 0, state: :new

          use Machinist

          transitions do
            from :score_updated do
              to(&which_interview/1, event: "start_interview")
            end
          end

          defp which_interview(%Example10{score: score}) when score >= 70 do
            :interview_1
          end

          defp which_interview(_), do: :interview_2
        end
      end
    end
  end
end
