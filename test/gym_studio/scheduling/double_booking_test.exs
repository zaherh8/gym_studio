defmodule GymStudio.Scheduling.DoubleBookingTest do
  use GymStudio.DataCase

  alias GymStudio.Scheduling

  import GymStudio.AccountsFixtures

  setup do
    client1 = user_fixture(%{role: :client})
    client2 = user_fixture(%{role: :client})
    trainer = user_fixture(%{role: :trainer})
    scheduled_at = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

    {:ok, client1: client1, client2: client2, trainer: trainer, scheduled_at: scheduled_at}
  end

  describe "double-booking prevention" do
    test "prevents booking same trainer at same time twice", %{
      client1: client1,
      client2: client2,
      trainer: trainer,
      scheduled_at: scheduled_at
    } do
      attrs1 = %{
        client_id: client1.id,
        trainer_id: trainer.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      assert {:ok, _session} = Scheduling.book_session(attrs1)

      attrs2 = %{
        client_id: client2.id,
        trainer_id: trainer.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      assert {:error, :slot_taken} = Scheduling.book_session(attrs2)
    end

    test "allows rebooking after cancellation", %{
      client1: client1,
      client2: client2,
      trainer: trainer,
      scheduled_at: scheduled_at
    } do
      attrs1 = %{
        client_id: client1.id,
        trainer_id: trainer.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      assert {:ok, session} = Scheduling.book_session(attrs1)

      # Cancel the first session
      assert {:ok, _cancelled} = Scheduling.cancel_session(session, client1.id, "changed mind")

      # Now booking the same slot should work
      attrs2 = %{
        client_id: client2.id,
        trainer_id: trainer.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      assert {:ok, _session2} = Scheduling.book_session(attrs2)
    end

    test "allows different trainers at same time", %{
      client1: client1,
      client2: client2,
      scheduled_at: scheduled_at
    } do
      trainer2 = user_fixture(%{role: :trainer})

      attrs1 = %{
        client_id: client1.id,
        trainer_id: user_fixture(%{role: :trainer}).id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      attrs2 = %{
        client_id: client2.id,
        trainer_id: trainer2.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60
      }

      assert {:ok, _} = Scheduling.book_session(attrs1)
      assert {:ok, _} = Scheduling.book_session(attrs2)
    end
  end
end
