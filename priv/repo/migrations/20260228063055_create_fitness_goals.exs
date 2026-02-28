defmodule GymStudio.Repo.Migrations.CreateFitnessGoals do
  use Ecto.Migration

  def change do
    create table(:fitness_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :title, :string, null: false, size: 255
      add :description, :text
      add :target_value, :decimal, null: false
      add :target_unit, :string, null: false
      add :current_value, :decimal, default: 0, null: false
      add :status, :string, default: "active", null: false
      add :target_date, :date
      add :achieved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:fitness_goals, [:client_id])
    create index(:fitness_goals, [:created_by_id])
  end
end
