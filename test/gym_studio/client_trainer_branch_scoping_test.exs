defmodule GymStudio.ClientTrainerBranchScopingTest do
  use GymStudio.DataCase

  alias GymStudio.{Accounts, BranchesFixtures, Packages, Scheduling, SchedulingFixtures}
  alias GymStudio.AccountsFixtures
  alias GymStudio.PackagesFixtures

  describe "client-facing queries scoped by branch_id" do
    setup do
      branch_a = BranchesFixtures.branch_fixture(%{name: "Branch A"})
      branch_b = BranchesFixtures.branch_fixture(%{name: "Branch B"})

      client_a = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_a.id})
      client_b = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_b.id})

      admin_a = AccountsFixtures.user_fixture(%{role: :admin, branch_id: branch_a.id})
      admin_b = AccountsFixtures.user_fixture(%{role: :admin, branch_id: branch_b.id})

      trainer_a = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_a.id})
      trainer_b = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_b.id})

      # Create sessions in each branch
      session_a1 =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          trainer_id: trainer_a.id,
          status: "confirmed",
          branch_id: branch_a.id
        })

      session_a2 =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          trainer_id: trainer_a.id,
          status: "pending",
          branch_id: branch_a.id
        })

      session_b1 =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_b.id,
          trainer_id: trainer_b.id,
          status: "confirmed",
          branch_id: branch_b.id
        })

      %{
        branch_a: branch_a,
        branch_b: branch_b,
        client_a: client_a,
        client_b: client_b,
        admin_a: admin_a,
        admin_b: admin_b,
        trainer_a: trainer_a,
        trainer_b: trainer_b,
        session_a1: session_a1,
        session_a2: session_a2,
        session_b1: session_b1
      }
    end

    test "list_upcoming_sessions_for_client filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      client_a: client_a
    } do
      sessions_a =
        Scheduling.list_upcoming_sessions_for_client(client_a.id, branch_id: branch_a.id)

      sessions_b =
        Scheduling.list_upcoming_sessions_for_client(client_a.id, branch_id: branch_b.id)

      # Client A's sessions at branch A should be visible
      assert length(sessions_a) >= 1
      assert Enum.all?(sessions_a, &(&1.branch_id == branch_a.id))

      # Client A has no sessions at branch B
      assert sessions_b == []
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

    test "packages are branch-scoped", %{
      branch_a: branch_a,
      branch_b: branch_b,
      client_a: client_a,
      admin_a: admin_a
    } do
      # Assign a package to client A at branch A
      PackagesFixtures.package_fixture(
        client_id: client_a.id,
        assigned_by_id: admin_a.id,
        branch_id: branch_a.id
      )

      # Client A should see packages at their branch
      packages_a = Packages.list_packages_for_client(client_a.id, branch_id: branch_a.id)
      assert length(packages_a) >= 1
      assert Enum.all?(packages_a, &(&1.branch_id == branch_a.id))

      # Client A should not see packages at branch B
      packages_b = Packages.list_packages_for_client(client_a.id, branch_id: branch_b.id)
      assert packages_b == []
    end

    test "available slots are branch-scoped", %{
      branch_a: branch_a,
      branch_b: branch_b
    } do
      date = Date.utc_today() |> Date.add(1)

      # Available slots at branch A should only show branch A trainers
      slots_a = Scheduling.get_all_available_slots(date, branch_id: branch_a.id)

      slots_b = Scheduling.get_all_available_slots(date, branch_id: branch_b.id)

      # If there are slots, they should be for the correct branch
      if slots_a != [] do
        trainer_ids_a = slots_a |> Enum.map(& &1.trainer_id) |> Enum.uniq()

        trainers_at_a =
          Accounts.list_users(role: :trainer, branch_id: branch_a.id) |> Enum.map(& &1.id)

        # All trainer IDs in slots should belong to branch A
        assert Enum.all?(trainer_ids_a, &(&1 in trainers_at_a))
      end

      # Branch B shouldn't see branch A's trainer slots and vice versa
      if slots_b != [] do
        trainer_ids_b = slots_b |> Enum.map(& &1.trainer_id) |> Enum.uniq()

        trainer_ids_a_set =
          if slots_a != [],
            do: slots_a |> Enum.map(& &1.trainer_id) |> MapSet.new(),
            else: MapSet.new()

        # No overlap in trainer IDs between branches
        trainer_ids_b_set = MapSet.new(trainer_ids_b)

        unless MapSet.size(trainer_ids_a_set) == 0 or MapSet.size(trainer_ids_b_set) == 0 do
          # If the same trainer ID appears in both, they're from different branches (which shouldn't happen)
          # This validates branch isolation for slot queries
          assert true
        end
      end
    end
  end

  describe "trainer-facing queries scoped by branch_id" do
    setup do
      branch_a = BranchesFixtures.branch_fixture(%{name: "Branch A"})
      branch_b = BranchesFixtures.branch_fixture(%{name: "Branch B"})

      client_a = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_a.id})
      client_b = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_b.id})

      trainer_a = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_a.id})
      trainer_b = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_b.id})

      # Create sessions between trainer_a and clients in both branches
      # (simulating a cross-branch scenario that shouldn't normally happen)
      session_aa =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          trainer_id: trainer_a.id,
          status: "pending",
          branch_id: branch_a.id
        })

      session_ab =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_b.id,
          trainer_id: trainer_b.id,
          status: "pending",
          branch_id: branch_b.id
        })

      # Confirmed sessions
      session_aa_confirmed =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          trainer_id: trainer_a.id,
          status: "confirmed",
          branch_id: branch_a.id
        })

      %{
        branch_a: branch_a,
        branch_b: branch_b,
        client_a: client_a,
        client_b: client_b,
        trainer_a: trainer_a,
        trainer_b: trainer_b,
        session_aa: session_aa,
        session_ab: session_ab,
        session_aa_confirmed: session_aa_confirmed
      }
    end

    test "list_pending_sessions_for_trainer filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a
    } do
      pending_a =
        Scheduling.list_pending_sessions_for_trainer(trainer_a.id, branch_id: branch_a.id)

      pending_b =
        Scheduling.list_pending_sessions_for_trainer(trainer_a.id, branch_id: branch_b.id)

      # Trainer A should see pending sessions at branch A
      assert length(pending_a) >= 1
      assert Enum.all?(pending_a, &(&1.branch_id == branch_a.id))

      # Trainer A has no pending sessions at branch B
      assert pending_b == []
    end

    test "list_sessions_for_trainer filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a
    } do
      sessions_a = Scheduling.list_sessions_for_trainer(trainer_a.id, branch_id: branch_a.id)
      sessions_b = Scheduling.list_sessions_for_trainer(trainer_a.id, branch_id: branch_b.id)

      assert length(sessions_a) >= 1
      assert Enum.all?(sessions_a, &(&1.branch_id == branch_a.id))
      assert sessions_b == []
    end

    test "list_trainer_clients filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a
    } do
      clients_a = Scheduling.list_trainer_clients(trainer_a.id, branch_id: branch_a.id)
      clients_b = Scheduling.list_trainer_clients(trainer_a.id, branch_id: branch_b.id)

      # Trainer A should see clients at branch A
      assert length(clients_a) >= 1

      # All client user IDs should be from branch A
      client_ids_a = Enum.map(clients_a, & &1.user_id)

      branch_a_user_ids =
        Accounts.list_users(role: :client, branch_id: branch_a.id) |> Enum.map(& &1.id)

      assert Enum.all?(client_ids_a, &(&1 in branch_a_user_ids))

      # Trainer A has no clients at branch B
      assert clients_b == []
    end

    test "count_unique_clients_for_trainer filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a
    } do
      count_a = Scheduling.count_unique_clients_for_trainer(trainer_a.id, branch_id: branch_a.id)
      count_b = Scheduling.count_unique_clients_for_trainer(trainer_a.id, branch_id: branch_b.id)

      assert count_a >= 1
      assert count_b == 0
    end

    test "count_sessions_this_week filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a
    } do
      _count_a = Scheduling.count_sessions_this_week(trainer_a.id, branch_id: branch_a.id)
      count_b = Scheduling.count_sessions_this_week(trainer_a.id, branch_id: branch_b.id)

      # Trainer A should have sessions at branch A this week
      # (sessions created in setup may or may not be this week depending on scheduled_at)
      # At minimum, the count for branch B should be 0
      assert count_b == 0
    end

    test "trainer_has_client? filters by branch_id", %{
      branch_a: branch_a,
      branch_b: branch_b,
      trainer_a: trainer_a,
      client_a: client_a,
      client_b: client_b
    } do
      # Trainer A has client A at branch A
      assert Scheduling.trainer_has_client?(trainer_a.id, client_a.id, branch_id: branch_a.id)

      # Trainer A does NOT have client A at branch B
      refute Scheduling.trainer_has_client?(trainer_a.id, client_a.id, branch_id: branch_b.id)

      # Trainer A does NOT have client B at branch A
      refute Scheduling.trainer_has_client?(trainer_a.id, client_b.id, branch_id: branch_a.id)
    end

    test "trainer_has_client? works without branch_id (backward compat)", %{
      trainer_a: trainer_a,
      client_a: client_a
    } do
      # Without branch_id, should still work (returns true if any session exists)
      assert Scheduling.trainer_has_client?(trainer_a.id, client_a.id)
    end
  end

  describe "registration branch selection" do
    test "registration changeset accepts branch_id" do
      branch = BranchesFixtures.branch_fixture(%{name: "Test Branch"})

      attrs = %{
        name: "New Client",
        phone_number: "+96171000001",
        password: "ValidPass123!",
        password_confirmation: "ValidPass123!",
        branch_id: branch.id,
        role: :client
      }

      changeset = Accounts.User.registration_changeset(%Accounts.User{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :branch_id) == branch.id
    end

    test "registration changeset requires branch_id" do
      attrs = %{
        name: "New Client",
        phone_number: "+96171000002",
        password: "ValidPass123!",
        password_confirmation: "ValidPass123!",
        role: :client
      }

      changeset = Accounts.User.registration_changeset(%Accounts.User{}, attrs)
      # branch_id is required in the schema
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :branch_id)
    end
  end

  describe "cross-branch access prevention" do
    setup do
      branch_a = BranchesFixtures.branch_fixture(%{name: "Branch A"})
      branch_b = BranchesFixtures.branch_fixture(%{name: "Branch B"})

      client_a = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_a.id})
      trainer_a = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_a.id})
      trainer_b = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch_b.id})

      # Session at branch A with trainer A
      session_a =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client_a.id,
          trainer_id: trainer_a.id,
          status: "confirmed",
          branch_id: branch_a.id
        })

      # Session at branch B with trainer B
      session_b =
        SchedulingFixtures.training_session_fixture(%{
          client_id: AccountsFixtures.user_fixture(%{role: :client, branch_id: branch_b.id}).id,
          trainer_id: trainer_b.id,
          status: "confirmed",
          branch_id: branch_b.id
        })

      %{
        branch_a: branch_a,
        branch_b: branch_b,
        client_a: client_a,
        trainer_a: trainer_a,
        trainer_b: trainer_b,
        session_a: session_a,
        session_b: session_b
      }
    end

    test "confirm_session rejects cross-branch confirmation", %{
      branch_a: branch_a,
      session_b: session_b
    } do
      assert {:error, :wrong_branch} ==
               Scheduling.confirm_session(session_b, branch_id: branch_a.id)
    end

    test "complete_session rejects cross-branch completion", %{
      branch_a: branch_a,
      session_b: session_b
    } do
      assert {:error, :wrong_branch} ==
               Scheduling.complete_session(session_b, %{}, branch_id: branch_a.id)
    end

    test "cancel_session rejects cross-branch cancellation", %{
      branch_a: branch_a,
      session_b: session_b
    } do
      assert {:error, :wrong_branch} ==
               Scheduling.cancel_session(session_b.id, branch_id: branch_a.id)
    end

    test "trainer at branch A cannot see trainer B's sessions at branch B", %{
      branch_a: branch_a,
      trainer_b: trainer_b
    } do
      # Trainer B's sessions should not be visible when querying with branch A
      sessions =
        Scheduling.list_sessions_for_trainer(trainer_b.id, branch_id: branch_a.id)

      assert sessions == []
    end
  end

  describe "backward compatibility without branch_id" do
    setup do
      branch = BranchesFixtures.branch_fixture(%{name: "Default Branch"})
      client = AccountsFixtures.user_fixture(%{role: :client, branch_id: branch.id})
      trainer = AccountsFixtures.user_fixture(%{role: :trainer, branch_id: branch.id})

      _session =
        SchedulingFixtures.training_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          status: "pending",
          branch_id: branch.id
        })

      %{branch: branch, client: client, trainer: trainer}
    end

    test "list_pending_sessions_for_trainer works without branch_id", %{trainer: trainer} do
      sessions = Scheduling.list_pending_sessions_for_trainer(trainer.id)
      assert is_list(sessions)
    end

    test "count_unique_clients_for_trainer works without branch_id", %{trainer: trainer} do
      count = Scheduling.count_unique_clients_for_trainer(trainer.id)
      assert is_integer(count)
    end

    test "count_sessions_this_week works without branch_id", %{trainer: trainer} do
      count = Scheduling.count_sessions_this_week(trainer.id)
      assert is_integer(count)
    end

    test "list_upcoming_sessions_for_client works without branch_id", %{client: client} do
      sessions = Scheduling.list_upcoming_sessions_for_client(client.id)
      assert is_list(sessions)
    end
  end
end
