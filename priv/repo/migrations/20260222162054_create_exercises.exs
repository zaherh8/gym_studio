defmodule GymStudio.Repo.Migrations.CreateExercises do
  use Ecto.Migration

  def change do
    create table(:exercises, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :category, :string, null: false
      add :muscle_group, :string
      add :equipment, :string
      add :tracking_type, :string, null: false
      add :description, :text
      add :is_custom, :boolean, default: false, null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exercises, [:name])
    create index(:exercises, [:category])
    create index(:exercises, [:created_by_id])
  end
end
