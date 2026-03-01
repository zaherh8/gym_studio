defmodule GymStudio.Scheduling.TrainerAvailabilityTest do
  use GymStudio.DataCase, async: true

  alias GymStudio.Scheduling
  alias GymStudio.Scheduling.TrainerAvailability

  setup do
    user =
      %GymStudio.Accounts.User{}
      |> GymStudio.Accounts.User.registration_changeset(%{
        name: "Test Trainer",
        phone_number: "+96179999901",
        email: "avail_test@test.com",
        password: "password123456",
        password_confirmation: "password123456",
        role: :trainer
      })
      |> GymStudio.Accounts.User.confirm_changeset()
      |> GymStudio.Repo.insert!()

    %{trainer: user}
  end

  describe "TrainerAvailability schema" do
    test "valid changeset", %{trainer: trainer} do
      changeset =
        TrainerAvailability.changeset(%TrainerAvailability{}, %{
          trainer_id: trainer.id,
          day_of_week: 1,
          start_time: ~T[07:00:00],
          end_time: ~T[22:00:00]
        })

      assert changeset.valid?
    end

    test "invalid day_of_week", %{trainer: trainer} do
      changeset =
        TrainerAvailability.changeset(%TrainerAvailability{}, %{
          trainer_id: trainer.id,
          day_of_week: 8,
          start_time: ~T[07:00:00],
          end_time: ~T[22:00:00]
        })

      refute changeset.valid?
    end

    test "end_time must be after start_time", %{trainer: trainer} do
      changeset =
        TrainerAvailability.changeset(%TrainerAvailability{}, %{
          trainer_id: trainer.id,
          day_of_week: 1,
          start_time: ~T[22:00:00],
          end_time: ~T[07:00:00]
        })

      refute changeset.valid?
    end
  end

  describe "set_trainer_availability/3" do
    test "creates new availability", %{trainer: trainer} do
      assert {:ok, avail} =
               Scheduling.set_trainer_availability(trainer.id, 1, %{
                 start_time: ~T[07:00:00],
                 end_time: ~T[22:00:00]
               })

      assert avail.day_of_week == 1
      assert avail.start_time == ~T[07:00:00]
    end

    test "upserts existing availability", %{trainer: trainer} do
      {:ok, _} =
        Scheduling.set_trainer_availability(trainer.id, 1, %{
          start_time: ~T[07:00:00],
          end_time: ~T[22:00:00]
        })

      {:ok, updated} =
        Scheduling.set_trainer_availability(trainer.id, 1, %{
          start_time: ~T[08:00:00],
          end_time: ~T[20:00:00]
        })

      assert updated.start_time == ~T[08:00:00]
      assert length(Scheduling.list_trainer_availabilities(trainer.id)) == 1
    end
  end

  describe "list_trainer_availabilities/1" do
    test "returns all days ordered", %{trainer: trainer} do
      for day <- [3, 1, 5] do
        Scheduling.set_trainer_availability(trainer.id, day, %{
          start_time: ~T[07:00:00],
          end_time: ~T[22:00:00]
        })
      end

      avails = Scheduling.list_trainer_availabilities(trainer.id)
      assert length(avails) == 3
      assert Enum.map(avails, & &1.day_of_week) == [1, 3, 5]
    end
  end

  describe "delete_trainer_availability/2" do
    test "removes availability for a day", %{trainer: trainer} do
      Scheduling.set_trainer_availability(trainer.id, 1, %{
        start_time: ~T[07:00:00],
        end_time: ~T[22:00:00]
      })

      assert :ok = Scheduling.delete_trainer_availability(trainer.id, 1)
      assert Scheduling.list_trainer_availabilities(trainer.id) == []
    end
  end
end
