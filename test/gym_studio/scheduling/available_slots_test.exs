defmodule GymStudio.Scheduling.AvailableSlotsTest do
  use GymStudio.DataCase, async: true

  alias GymStudio.Scheduling

  setup do
    trainer =
      %GymStudio.Accounts.User{}
      |> GymStudio.Accounts.User.registration_changeset(%{
        name: "Slots Trainer",
        phone_number: "+96179999903",
        email: "slots_test@test.com",
        password: "password123456",
        password_confirmation: "password123456",
        role: :trainer
      })
      |> GymStudio.Accounts.User.confirm_changeset()
      |> GymStudio.Repo.insert!()

    client =
      %GymStudio.Accounts.User{}
      |> GymStudio.Accounts.User.registration_changeset(%{
        name: "Slots Client",
        phone_number: "+96179999904",
        email: "slots_client@test.com",
        password: "password123456",
        password_confirmation: "password123456",
        role: :client
      })
      |> GymStudio.Accounts.User.confirm_changeset()
      |> GymStudio.Repo.insert!()

    # Set availability for Monday (day 1): 9 AM - 12 PM
    Scheduling.set_trainer_availability(trainer.id, 1, %{
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00]
    })

    %{trainer: trainer, client: client}
  end

  # Find next Monday from today
  defp next_monday do
    today = Date.utc_today()
    days_until_monday = rem(8 - Date.day_of_week(today), 7)
    days_until_monday = if days_until_monday == 0, do: 7, else: days_until_monday
    Date.add(today, days_until_monday)
  end

  describe "get_trainer_available_slots/2" do
    test "returns slots within availability window", %{trainer: trainer} do
      monday = next_monday()
      slots = Scheduling.get_trainer_available_slots(trainer.id, monday)

      assert length(slots) == 3
      hours = Enum.map(slots, & &1.hour)
      assert hours == [9, 10, 11]
    end

    test "returns empty for day with no availability", %{trainer: trainer} do
      # Tuesday (day 2) has no availability set
      tuesday = Date.add(next_monday(), 1)
      slots = Scheduling.get_trainer_available_slots(trainer.id, tuesday)
      assert slots == []
    end

    test "excludes booked hours", %{trainer: trainer, client: client} do
      monday = next_monday()
      scheduled_at = DateTime.new!(monday, ~T[10:00:00], "Etc/UTC")

      GymStudio.Repo.insert!(%GymStudio.Scheduling.TrainingSession{
        client_id: client.id,
        trainer_id: trainer.id,
        scheduled_at: scheduled_at,
        duration_minutes: 60,
        status: "confirmed"
      })

      slots = Scheduling.get_trainer_available_slots(trainer.id, monday)
      hours = Enum.map(slots, & &1.hour)
      assert 10 not in hours
      assert 9 in hours
      assert 11 in hours
    end

    test "excludes all-day time off", %{trainer: trainer} do
      monday = next_monday()
      Scheduling.create_time_off(%{trainer_id: trainer.id, date: monday})

      slots = Scheduling.get_trainer_available_slots(trainer.id, monday)
      assert slots == []
    end

    test "excludes partial time off", %{trainer: trainer} do
      monday = next_monday()

      Scheduling.create_time_off(%{
        trainer_id: trainer.id,
        date: monday,
        start_time: ~T[09:00:00],
        end_time: ~T[11:00:00]
      })

      slots = Scheduling.get_trainer_available_slots(trainer.id, monday)
      hours = Enum.map(slots, & &1.hour)
      assert hours == [11]
    end
  end

  describe "get_all_available_slots/1" do
    test "returns slots with trainer info", %{trainer: trainer} do
      monday = next_monday()
      slots = Scheduling.get_all_available_slots(monday)

      assert length(slots) > 0
      first = hd(slots)
      assert first.trainer_id == trainer.id
      assert first.trainer_name == "Slots Trainer"
    end
  end
end
