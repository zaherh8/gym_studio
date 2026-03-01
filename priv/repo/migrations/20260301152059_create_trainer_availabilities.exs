defmodule GymStudio.Repo.Migrations.CreateTrainerAvailabilities do
  use Ecto.Migration

  def change do
    create table(:trainer_availabilities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trainer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trainer_availabilities, [:trainer_id, :day_of_week])
    create index(:trainer_availabilities, [:trainer_id])
  end
end
