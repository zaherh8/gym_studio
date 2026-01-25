defmodule GymStudio.SchedulingTest do
  use GymStudio.DataCase

  alias GymStudio.Scheduling

  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  describe "training_sessions" do
    alias GymStudio.Scheduling.TrainingSession

    setup do
      client = user_fixture(%{role: :client})
      trainer = user_fixture(%{role: :trainer})
      admin = user_fixture(%{role: :admin})

      {:ok, client: client, trainer: trainer, admin: admin}
    end

    test "book_session/1 creates a pending session", %{client: client} do
      scheduled_at = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      attrs = %{
        client_id: client.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60,
        notes: "First session"
      }

      assert {:ok, %TrainingSession{} = session} = Scheduling.book_session(attrs)
      assert session.client_id == client.id
      assert session.scheduled_at == scheduled_at
      assert session.duration_minutes == 60
      assert session.notes == "First session"
      assert session.status == "pending"
      assert is_nil(session.trainer_id)
      assert is_nil(session.approved_by_id)
    end

    test "book_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scheduling.book_session(%{})
    end

    test "book_session/1 requires scheduled_at to be in the future", %{client: client} do
      past_time = DateTime.utc_now() |> DateTime.add(-1, :day)

      attrs = %{
        client_id: client.id,
        scheduled_at: past_time,
        duration_minutes: 60
      }

      assert {:error, changeset} = Scheduling.book_session(attrs)
      assert "must be in the future" in errors_on(changeset).scheduled_at
    end

    test "approve_session/3 approves pending session and assigns trainer", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session = training_session_fixture(%{client_id: client.id})

      assert {:ok, %TrainingSession{} = updated_session} =
               Scheduling.approve_session(session, trainer.id, admin.id)

      assert updated_session.status == "confirmed"
      assert updated_session.trainer_id == trainer.id
      assert updated_session.approved_by_id == admin.id
      assert %DateTime{} = updated_session.approved_at
    end

    test "approve_session/3 fails for non-pending sessions", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      another_trainer = user_fixture(%{role: :trainer})

      assert {:error, changeset} =
               Scheduling.approve_session(session, another_trainer.id, admin.id)

      assert "Only pending sessions can be approved" in errors_on(changeset).status
    end

    test "cancel_session/3 cancels pending or confirmed sessions", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      pending_session = training_session_fixture(%{client_id: client.id})

      assert {:ok, %TrainingSession{} = cancelled_session} =
               Scheduling.cancel_session(pending_session, client.id, "Schedule conflict")

      assert cancelled_session.status == "cancelled"
      assert cancelled_session.cancelled_by_id == client.id
      assert cancelled_session.cancellation_reason == "Schedule conflict"
      assert %DateTime{} = cancelled_session.cancelled_at

      # Test cancelling confirmed session
      confirmed_session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      assert {:ok, %TrainingSession{} = cancelled_confirmed} =
               Scheduling.cancel_session(confirmed_session, trainer.id, "Trainer unavailable")

      assert cancelled_confirmed.status == "cancelled"
      assert cancelled_confirmed.cancelled_by_id == trainer.id
    end

    test "cancel_session/3 fails for completed sessions", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      {:ok, completed_session} = Scheduling.complete_session(session)

      assert {:error, changeset} =
               Scheduling.cancel_session(completed_session, client.id, "Changed my mind")

      assert "Only pending or confirmed sessions can be cancelled" in errors_on(changeset).status
    end

    test "complete_session/2 marks confirmed session as completed", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      assert {:ok, %TrainingSession{} = completed_session} =
               Scheduling.complete_session(session, %{
                 trainer_notes: "Excellent workout today"
               })

      assert completed_session.status == "completed"
      assert completed_session.trainer_notes == "Excellent workout today"
    end

    test "complete_session/2 fails for non-confirmed sessions", %{client: client} do
      pending_session = training_session_fixture(%{client_id: client.id})

      assert {:error, changeset} = Scheduling.complete_session(pending_session)
      assert "Only confirmed sessions can be completed" in errors_on(changeset).status
    end

    test "mark_no_show/1 marks confirmed session as no-show", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      assert {:ok, %TrainingSession{} = no_show_session} = Scheduling.mark_no_show(session)
      assert no_show_session.status == "no_show"
    end

    test "mark_no_show/1 fails for non-confirmed sessions", %{client: client} do
      pending_session = training_session_fixture(%{client_id: client.id})

      assert {:error, changeset} = Scheduling.mark_no_show(pending_session)
      assert "Only confirmed sessions can be marked as no-show" in errors_on(changeset).status
    end

    test "get_session!/1 returns the session with preloaded associations", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      fetched_session = Scheduling.get_session!(session.id)

      assert fetched_session.id == session.id
      assert %GymStudio.Accounts.User{} = fetched_session.client
      assert %GymStudio.Accounts.User{} = fetched_session.trainer
      assert %GymStudio.Accounts.User{} = fetched_session.approved_by
    end

    test "list_sessions_for_client/2 returns all sessions for a client", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session1 = training_session_fixture(%{client_id: client.id})

      session2 =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      # Create session for different client
      other_client = user_fixture(%{role: :client})
      _other_session = training_session_fixture(%{client_id: other_client.id})

      sessions = Scheduling.list_sessions_for_client(client.id)

      session_ids = Enum.map(sessions, & &1.id)
      assert length(sessions) == 2
      assert session1.id in session_ids
      assert session2.id in session_ids
    end

    test "list_sessions_for_client/2 filters by status", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      _pending = training_session_fixture(%{client_id: client.id})

      confirmed =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      sessions = Scheduling.list_sessions_for_client(client.id, status: "confirmed")

      assert length(sessions) == 1
      assert hd(sessions).id == confirmed.id
    end

    test "list_sessions_for_trainer/2 returns all sessions for a trainer", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      session1 =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      session2 =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      # Create session for different trainer
      other_trainer = user_fixture(%{role: :trainer})

      _other_session =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: other_trainer.id,
          approved_by_id: admin.id
        })

      sessions = Scheduling.list_sessions_for_trainer(trainer.id)

      session_ids = Enum.map(sessions, & &1.id)
      assert length(sessions) == 2
      assert session1.id in session_ids
      assert session2.id in session_ids
    end

    test "list_pending_sessions/0 returns only pending sessions", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      pending1 = training_session_fixture(%{client_id: client.id})
      pending2 = training_session_fixture(%{client_id: client.id})

      _confirmed =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id
        })

      pending_sessions = Scheduling.list_pending_sessions()

      session_ids = Enum.map(pending_sessions, & &1.id)
      assert pending1.id in session_ids
      assert pending2.id in session_ids
      assert Enum.all?(pending_sessions, &(&1.status == "pending"))
    end

    test "list_upcoming_sessions/1 returns sessions within specified days", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
      next_week = DateTime.utc_now() |> DateTime.add(10, :day) |> DateTime.truncate(:second)

      upcoming =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id,
          scheduled_at: tomorrow
        })

      _far_future =
        confirmed_session_fixture(%{
          client_id: client.id,
          trainer_id: trainer.id,
          approved_by_id: admin.id,
          scheduled_at: next_week
        })

      sessions = Scheduling.list_upcoming_sessions(7)

      session_ids = Enum.map(sessions, & &1.id)
      assert upcoming.id in session_ids
      assert length(sessions) == 1
    end
  end

  describe "time_slots" do
    alias GymStudio.Scheduling.TimeSlot

    test "create_time_slot/1 with valid data creates a time slot" do
      attrs = %{
        day_of_week: 1,
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        active: true
      }

      assert {:ok, %TimeSlot{} = time_slot} = Scheduling.create_time_slot(attrs)
      assert time_slot.day_of_week == 1
      assert time_slot.start_time == ~T[09:00:00]
      assert time_slot.end_time == ~T[10:00:00]
      assert time_slot.active == true
    end

    test "create_time_slot/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scheduling.create_time_slot(%{})
    end

    test "create_time_slot/1 validates day_of_week range" do
      attrs = %{
        day_of_week: 8,
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00]
      }

      assert {:error, changeset} = Scheduling.create_time_slot(attrs)
      assert "must be less than or equal to 7" in errors_on(changeset).day_of_week
    end

    test "create_time_slot/1 validates end_time is after start_time" do
      attrs = %{
        day_of_week: 1,
        start_time: ~T[10:00:00],
        end_time: ~T[09:00:00]
      }

      assert {:error, changeset} = Scheduling.create_time_slot(attrs)
      assert "must be after start time" in errors_on(changeset).end_time
    end

    test "update_time_slot/2 with valid data updates the time slot" do
      time_slot = time_slot_fixture()

      update_attrs = %{
        active: false,
        start_time: ~T[08:00:00]
      }

      assert {:ok, %TimeSlot{} = updated_slot} =
               Scheduling.update_time_slot(time_slot, update_attrs)

      assert updated_slot.active == false
      assert updated_slot.start_time == ~T[08:00:00]
    end

    test "list_time_slots/0 returns all time slots" do
      time_slot1 = time_slot_fixture(%{day_of_week: 1})
      time_slot2 = time_slot_fixture(%{day_of_week: 2})

      time_slots = Scheduling.list_time_slots()
      time_slot_ids = Enum.map(time_slots, & &1.id)

      assert time_slot1.id in time_slot_ids
      assert time_slot2.id in time_slot_ids
    end

    test "list_time_slots/1 with active_only option filters inactive slots" do
      active_slot = time_slot_fixture(%{active: true})
      inactive_slot = time_slot_fixture(%{active: false, start_time: ~T[11:00:00], end_time: ~T[12:00:00]})

      time_slots = Scheduling.list_time_slots(active_only: true)
      time_slot_ids = Enum.map(time_slots, & &1.id)

      assert active_slot.id in time_slot_ids
      refute inactive_slot.id in time_slot_ids
    end

    test "get_available_slots/1 returns slots for specific day" do
      monday_slot = time_slot_fixture(%{day_of_week: 1})
      _tuesday_slot = time_slot_fixture(%{day_of_week: 2, start_time: ~T[11:00:00], end_time: ~T[12:00:00]})

      # Get a Monday (day_of_week = 1)
      monday_date = ~D[2026-02-02]

      slots = Scheduling.get_available_slots(monday_date)
      slot_ids = Enum.map(slots, & &1.id)

      assert monday_slot.id in slot_ids
      assert length(slots) == 1
    end

    test "get_available_slots/1 only returns active slots" do
      active_slot = time_slot_fixture(%{day_of_week: 1, active: true})

      _inactive_slot =
        time_slot_fixture(%{day_of_week: 1, active: false, start_time: ~T[11:00:00], end_time: ~T[12:00:00]})

      monday_date = ~D[2026-02-02]
      slots = Scheduling.get_available_slots(monday_date)

      assert length(slots) == 1
      assert hd(slots).id == active_slot.id
    end

    test "get_time_slot!/1 returns the time slot" do
      time_slot = time_slot_fixture()
      fetched_slot = Scheduling.get_time_slot!(time_slot.id)

      assert fetched_slot.id == time_slot.id
    end

    test "delete_time_slot/1 deletes the time slot" do
      time_slot = time_slot_fixture()

      assert {:ok, %TimeSlot{}} = Scheduling.delete_time_slot(time_slot)
      assert_raise Ecto.NoResultsError, fn -> Scheduling.get_time_slot!(time_slot.id) end
    end
  end

  describe "booking flow integration" do
    setup do
      client = user_fixture(%{role: :client})
      trainer = user_fixture(%{role: :trainer})
      admin = user_fixture(%{role: :admin})

      {:ok, client: client, trainer: trainer, admin: admin}
    end

    test "complete booking flow from pending to completed", %{
      client: client,
      trainer: trainer,
      admin: admin
    } do
      # Step 1: Client books a session
      scheduled_at = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      {:ok, session} =
        Scheduling.book_session(%{
          client_id: client.id,
          scheduled_at: scheduled_at,
          duration_minutes: 60,
          notes: "Looking forward to this session"
        })

      assert session.status == "pending"
      assert is_nil(session.trainer_id)

      # Step 2: Admin approves and assigns trainer
      {:ok, session} = Scheduling.approve_session(session, trainer.id, admin.id)

      assert session.status == "confirmed"
      assert session.trainer_id == trainer.id
      assert session.approved_by_id == admin.id

      # Step 3: Trainer completes the session
      {:ok, session} =
        Scheduling.complete_session(session, %{
          trainer_notes: "Great progress on form"
        })

      assert session.status == "completed"
      assert session.trainer_notes == "Great progress on form"
    end

    test "booking cancellation flow", %{client: client} do
      # Client books a session
      {:ok, session} =
        Scheduling.book_session(%{
          client_id: client.id,
          scheduled_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second),
          duration_minutes: 60
        })

      # Client cancels before approval
      {:ok, cancelled} = Scheduling.cancel_session(session, client.id, "Emergency came up")

      assert cancelled.status == "cancelled"
      assert cancelled.cancelled_by_id == client.id
      assert cancelled.cancellation_reason == "Emergency came up"
    end
  end
end
