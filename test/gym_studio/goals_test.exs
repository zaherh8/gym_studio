defmodule GymStudio.GoalsTest do
  use GymStudio.DataCase

  alias GymStudio.Goals
  alias GymStudio.Goals.FitnessGoal

  import GymStudio.AccountsFixtures
  import GymStudio.GoalsFixtures

  setup do
    user = user_fixture(%{role: :client})
    client_fixture(%{user_id: user.id})
    %{user: user}
  end

  describe "list_goals/2" do
    test "returns goals for a client", %{user: user} do
      g1 = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id, "title" => "G1"})
      g2 = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id, "title" => "G2"})

      goals = Goals.list_goals(user.id)
      goal_ids = Enum.map(goals, & &1.id)
      assert g1.id in goal_ids
      assert g2.id in goal_ids
      assert length(goals) == 2
    end

    test "filters by status", %{user: user} do
      goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id, "title" => "Active"})

      achieved =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "title" => "Done",
          "status" => "achieved"
        })

      assert [^achieved] = Goals.list_goals(user.id, status: "achieved")
      assert length(Goals.list_goals(user.id)) == 2
    end

    test "does not return other clients' goals", %{user: user} do
      other = user_fixture(%{role: :client})
      client_fixture(%{user_id: other.id})
      goal_fixture(%{"client_id" => other.id, "created_by_id" => other.id})

      assert Goals.list_goals(user.id) == []
    end
  end

  describe "get_goal!/1" do
    test "returns the goal", %{user: user} do
      goal = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id})
      assert Goals.get_goal!(goal.id).id == goal.id
    end
  end

  describe "create_goal/1" do
    test "creates with valid attrs", %{user: user} do
      attrs = %{
        "client_id" => user.id,
        "created_by_id" => user.id,
        "title" => "Lose 5kg",
        "target_value" => "5",
        "target_unit" => "kg_loss"
      }

      assert {:ok, %FitnessGoal{} = goal} = Goals.create_goal(attrs)
      assert goal.title == "Lose 5kg"
      assert goal.status == "active"
      assert Decimal.equal?(goal.current_value, Decimal.new(0))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Goals.create_goal(%{})
      assert errors_on(changeset) |> Map.has_key?(:title)
      assert errors_on(changeset) |> Map.has_key?(:target_value)
    end
  end

  describe "update_goal/2" do
    test "updates the goal", %{user: user} do
      goal = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id})
      assert {:ok, updated} = Goals.update_goal(goal, %{"title" => "Updated"})
      assert updated.title == "Updated"
    end
  end

  describe "delete_goal/1" do
    test "deletes active goal", %{user: user} do
      goal = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id})
      assert {:ok, _} = Goals.delete_goal(goal)
      assert_raise Ecto.NoResultsError, fn -> Goals.get_goal!(goal.id) end
    end

    test "refuses to delete achieved goal", %{user: user} do
      goal =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "status" => "achieved"
        })

      assert {:error, :not_active} = Goals.delete_goal(goal)
    end
  end

  describe "achieve_goal/1" do
    test "sets status to achieved with timestamp", %{user: user} do
      goal = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id})
      assert {:ok, achieved} = Goals.achieve_goal(goal)
      assert achieved.status == "achieved"
      assert achieved.achieved_at != nil
    end
  end

  describe "abandon_goal/1" do
    test "sets status to abandoned", %{user: user} do
      goal = goal_fixture(%{"client_id" => user.id, "created_by_id" => user.id})
      assert {:ok, abandoned} = Goals.abandon_goal(goal)
      assert abandoned.status == "abandoned"
    end
  end

  describe "update_progress/2" do
    test "updates current_value", %{user: user} do
      goal =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "target_value" => "100"
        })

      assert {:ok, updated} = Goals.update_progress(goal, "50")
      assert Decimal.equal?(updated.current_value, Decimal.new("50"))
      assert updated.status == "active"
    end

    test "auto-achieves when current >= target", %{user: user} do
      goal =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "target_value" => "100"
        })

      assert {:ok, updated} = Goals.update_progress(goal, "100")
      assert updated.status == "achieved"
      assert updated.achieved_at != nil
    end

    test "auto-achieves when current exceeds target", %{user: user} do
      goal =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "target_value" => "50"
        })

      assert {:ok, updated} = Goals.update_progress(goal, "55")
      assert updated.status == "achieved"
    end
  end
end
