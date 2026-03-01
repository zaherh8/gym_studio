defmodule GymStudio.Repo.Migrations.CreateTrainerTimeOffs do
  use Ecto.Migration

  def change do
    create table(:trainer_time_offs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trainer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :start_time, :time
      add :end_time, :time
      add :reason, :string

      timestamps(type: :utc_datetime)
    end

    create index(:trainer_time_offs, [:trainer_id])
    create index(:trainer_time_offs, [:date])
    create index(:trainer_time_offs, [:trainer_id, :date])
  end
end
