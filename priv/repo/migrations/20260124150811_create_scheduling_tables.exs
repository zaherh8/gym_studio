defmodule GymStudio.Repo.Migrations.CreateSchedulingTables do
  use Ecto.Migration

  def change do
    create table(:time_slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:training_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, on_delete: :nothing, type: :binary_id), null: false
      add :trainer_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :package_id, references(:session_packages, on_delete: :nothing, type: :binary_id)
      add :scheduled_at, :utc_datetime, null: false
      add :duration_minutes, :integer, null: false, default: 60
      add :status, :string, null: false, default: "pending"
      add :notes, :text
      add :trainer_notes, :text
      add :approved_by_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :approved_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancelled_by_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :cancellation_reason, :text

      timestamps(type: :utc_datetime)
    end

    create index(:training_sessions, [:client_id])
    create index(:training_sessions, [:trainer_id])
    create index(:training_sessions, [:scheduled_at])
    create index(:training_sessions, [:status])
  end
end
