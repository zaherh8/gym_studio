defmodule GymStudio.Scheduling.TrainerClientsTest do
  use GymStudio.DataCase

  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  alias GymStudio.Scheduling

  setup do
    trainer_user = user_fixture(%{role: :trainer, name: "Coach Dan"})
    trainer = trainer_fixture(%{user_id: trainer_user.id})
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer
      |> GymStudio.Accounts.Trainer.approval_changeset(admin)
      |> GymStudio.Repo.update!()

    %{trainer_user: trainer_user, trainer: trainer, admin: admin}
  end

  describe "list_trainer_clients/2" do
    test "returns empty list when no sessions", %{trainer_user: trainer_user} do
      assert Scheduling.list_trainer_clients(trainer_user.id) == []
    end

    test "returns unique clients with stats", %{trainer_user: trainer_user} do
      client = user_fixture(%{role: :client, name: "Alice"})
      _c = client_fixture(%{user_id: client.id})

      _s1 =
        training_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      _s2 =
        training_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer_user.id,
          status: "completed",
          scheduled_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      [result] = Scheduling.list_trainer_clients(trainer_user.id)
      assert result.name == "Alice"
      assert result.total_sessions == 2
    end

    test "search filters by name", %{trainer_user: trainer_user} do
      alice = user_fixture(%{role: :client, name: "Alice"})
      _ac = client_fixture(%{user_id: alice.id})
      bob = user_fixture(%{role: :client, name: "Bob"})
      _bc = client_fixture(%{user_id: bob.id})

      _s1 =
        training_session_fixture(%{
          client_id: alice.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      _s2 =
        training_session_fixture(%{
          client_id: bob.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      results = Scheduling.list_trainer_clients(trainer_user.id, search: "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice"
    end
  end

  describe "trainer_has_client?/2" do
    test "returns true when trainer has session with client", %{trainer_user: trainer_user} do
      client = user_fixture(%{role: :client})
      _c = client_fixture(%{user_id: client.id})

      _s =
        training_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      assert Scheduling.trainer_has_client?(trainer_user.id, client.id)
    end

    test "returns false when no sessions", %{trainer_user: trainer_user} do
      client = user_fixture(%{role: :client})
      _c = client_fixture(%{user_id: client.id})

      refute Scheduling.trainer_has_client?(trainer_user.id, client.id)
    end
  end
end
