defmodule GymStudio.Scheduling.TrainerTimeOffTest do
  use GymStudio.DataCase, async: true

  alias GymStudio.Scheduling
  alias GymStudio.Scheduling.TrainerTimeOff

  setup do
    user =
      %GymStudio.Accounts.User{}
      |> GymStudio.Accounts.User.registration_changeset(%{
        name: "Test Trainer TO",
        phone_number: "+96179999902",
        email: "timeoff_test@test.com",
        password: "password123456",
        password_confirmation: "password123456",
        role: :trainer
      })
      |> GymStudio.Accounts.User.confirm_changeset()
      |> GymStudio.Repo.insert!()

    %{trainer: user}
  end

  describe "TrainerTimeOff schema" do
    test "valid all-day changeset", %{trainer: trainer} do
      changeset =
        TrainerTimeOff.changeset(%TrainerTimeOff{}, %{
          trainer_id: trainer.id,
          date: ~D[2026-04-01]
        })

      assert changeset.valid?
    end

    test "valid partial-day changeset", %{trainer: trainer} do
      changeset =
        TrainerTimeOff.changeset(%TrainerTimeOff{}, %{
          trainer_id: trainer.id,
          date: ~D[2026-04-01],
          start_time: ~T[09:00:00],
          end_time: ~T[12:00:00]
        })

      assert changeset.valid?
    end

    test "invalid when only start_time set", %{trainer: trainer} do
      changeset =
        TrainerTimeOff.changeset(%TrainerTimeOff{}, %{
          trainer_id: trainer.id,
          date: ~D[2026-04-01],
          start_time: ~T[09:00:00]
        })

      refute changeset.valid?
    end
  end

  describe "create_time_off/1" do
    test "creates time off", %{trainer: trainer} do
      assert {:ok, to} =
               Scheduling.create_time_off(%{
                 trainer_id: trainer.id,
                 date: ~D[2026-04-01],
                 reason: "Vacation"
               })

      assert to.reason == "Vacation"
    end
  end

  describe "list_trainer_time_offs/2" do
    test "filters by date range", %{trainer: trainer} do
      Scheduling.create_time_off(%{trainer_id: trainer.id, date: ~D[2026-03-01]})
      Scheduling.create_time_off(%{trainer_id: trainer.id, date: ~D[2026-04-01]})
      Scheduling.create_time_off(%{trainer_id: trainer.id, date: ~D[2026-05-01]})

      results =
        Scheduling.list_trainer_time_offs(trainer.id,
          from_date: ~D[2026-03-15],
          to_date: ~D[2026-04-15]
        )

      assert length(results) == 1
    end
  end

  describe "delete_time_off/1" do
    test "deletes existing time off", %{trainer: trainer} do
      {:ok, to} = Scheduling.create_time_off(%{trainer_id: trainer.id, date: ~D[2026-04-01]})
      assert {:ok, _} = Scheduling.delete_time_off(to.id)
    end

    test "returns error for non-existent", _context do
      assert {:error, :not_found} = Scheduling.delete_time_off(Ecto.UUID.generate())
    end
  end
end
