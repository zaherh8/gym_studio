defmodule GymStudio.Repo.Migrations.AddTrainerScheduledAtUniqueIndex do
  use Ecto.Migration

  def change do
    # Drop the old index if it exists from a previous attempt
    execute(
      "DROP INDEX IF EXISTS training_sessions_trainer_scheduled_active_index",
      "SELECT 1"
    )

    create unique_index(:training_sessions, [:trainer_id, :scheduled_at],
             name: :training_sessions_trainer_scheduled_at_active_index,
             where: "status != 'cancelled'"
           )
  end
end
