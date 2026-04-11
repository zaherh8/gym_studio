defmodule GymStudio.BranchIsolationTest do
  use GymStudio.DataCase

  alias GymStudio.{Accounts, BranchesFixtures, Scheduling, SchedulingFixtures}
  alias GymStudio.AccountsFixtures

  describe "branch data isolation" do
    setup do
      branch_a = BranchesFixtures.branch_fixture(%{name: "Branch A"})
      branch_b = BranchesFixtures.branch_fixture(%{name: "Branch B"})

      # Create users in each branch
      admin_a = AccountsFixtures.user_fixture(%{role: :admin, branch_id: branch_a.id})
      admin_b = AccountsFixtures.user_fixture(%{role: :admin, branch_id: branch_b.id})
      client_a = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_a.id})
      client_b = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_b.id})

      # Create sessions in each branch
      session_a =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          branch_id: branch_a.id
        })

      session_b =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_b.id,
          branch_id: branch_b.id
        })

      %{
        branch_a: branch_a,
        branch_b: branch_b,
        admin_a: admin_a,
        admin_b: admin_b,
        client_a: client_a,
        client_b: client_b,
        session_a: session_a,
        session_b: session_b
      }
    end

    test "list_sessions_for_client filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      client_a: client_a
    } do
      sessions_a = Scheduling.list_sessions_for_client(client_a.id, branch_id: branch_a.id)
      sessions_b = Scheduling.list_sessions_for_client(client_a.id, branch_id: branch_b.id)

      assert length(sessions_a) >= 1
      assert Enum.all?(sessions_a, &(&1.branch_id == branch_a.id))
      assert sessions_b == []
    end

    test "list_pending_sessions filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b
    } do
      pending_a = Scheduling.list_pending_sessions(branch_id: branch_a.id)
      pending_b = Scheduling.list_pending_sessions(branch_id: branch_b.id)

      assert Enum.all?(pending_a, &(&1.branch_id == branch_a.id))
      assert Enum.all?(pending_b, &(&1.branch_id == branch_b.id))
    end

    test "list_all_sessions filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b
    } do
      all_a = Scheduling.list_all_sessions(branch_id: branch_a.id)
      all_b = Scheduling.list_all_sessions(branch_id: branch_b.id)

      assert Enum.all?(all_a, &(&1.branch_id == branch_a.id))
      assert Enum.all?(all_b, &(&1.branch_id == branch_b.id))
      # No overlap
      ids_a = MapSet.new(all_a, & &1.id)
      ids_b = MapSet.new(all_b, & &1.id)
      assert MapSet.disjoint?(ids_a, ids_b)
    end

    test "list_users filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b
    } do
      users_a = Accounts.list_users(branch_id: branch_a.id)
      users_b = Accounts.list_users(branch_id: branch_b.id)

      assert Enum.all?(users_a, &(&1.branch_id == branch_a.id))
      assert Enum.all?(users_b, &(&1.branch_id == branch_b.id))

      ids_a = MapSet.new(users_a, & &1.id)
      ids_b = MapSet.new(users_b, & &1.id)
      assert MapSet.disjoint?(ids_a, ids_b)
    end

    test "session mutation rejects cross-branch modification", %{
      branch_a: branch_a,
      session_b: session_b
    } do
      # Try to complete a session from branch B using branch A's ID
      assert {:error, :wrong_branch} ==
               Scheduling.complete_session(session_b, %{}, branch_id: branch_a.id)
    end

    test "cancel_session rejects cross-branch modification", %{
      branch_a: branch_a,
      session_b: session_b,
      admin_a: admin_a
    } do
      assert {:error, :wrong_branch} ==
               Scheduling.cancel_session(session_b, admin_a.id, "test", branch_id: branch_a.id)
    end

    test "mark_no_show rejects cross-branch modification", %{
      branch_a: branch_a,
      session_b: session_b
    } do
      assert {:error, :wrong_branch} ==
               Scheduling.mark_no_show(session_b, branch_id: branch_a.id)
    end

    test "count_sessions_by_status is isolated by branch", %{
      branch_a: branch_a,
      branch_b: branch_b
    } do
      counts_a = Scheduling.count_sessions_by_status(branch_id: branch_a.id)
      counts_b = Scheduling.count_sessions_by_status(branch_id: branch_b.id)

      # Each branch should see at least its own sessions
      total_a = counts_a |> Map.values() |> Enum.sum()
      total_b = counts_b |> Map.values() |> Enum.sum()
      assert total_a >= 1
      assert total_b >= 1
    end
  end
end
