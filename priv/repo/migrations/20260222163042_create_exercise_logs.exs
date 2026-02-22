defmodule GymStudio.Repo.Migrations.CreateExerciseLogs do
  use Ecto.Migration

  def change do
    create table(:exercise_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :training_session_id,
          references(:training_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :exercise_id, references(:exercises, type: :binary_id, on_delete: :restrict),
        null: false

      add :client_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :logged_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :sets, :integer
      add :reps, :integer
      add :weight_kg, :decimal
      add :duration_seconds, :integer
      add :notes, :text
      add :order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_logs, [:training_session_id])
    create index(:exercise_logs, [:client_id])
    create index(:exercise_logs, [:exercise_id])
    create index(:exercise_logs, [:logged_by_id])
  end
end
