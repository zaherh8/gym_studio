defmodule GymStudio.Repo.Migrations.CreateTrainerAndClientProfiles do
  use Ecto.Migration

  def change do
    create table(:trainers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :bio, :text
      add :specializations, {:array, :string}, default: []
      add :photo_url, :string
      add :status, :string, null: false, default: "pending"
      add :approved_at, :utc_datetime
      add :approved_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trainers, [:user_id])
    create index(:trainers, [:status])

    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :emergency_contact_name, :string
      add :emergency_contact_phone, :string
      add :health_notes, :text
      add :goals, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:clients, [:user_id])
  end
end
