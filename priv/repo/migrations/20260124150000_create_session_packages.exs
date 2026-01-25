defmodule GymStudio.Repo.Migrations.CreateSessionPackages do
  use Ecto.Migration

  def change do
    create table(:session_packages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, on_delete: :restrict, type: :binary_id), null: false
      add :package_type, :string, null: false
      add :total_sessions, :integer, null: false
      add :used_sessions, :integer, null: false, default: 0
      add :assigned_by_id, references(:users, on_delete: :restrict, type: :binary_id), null: false
      add :expires_at, :utc_datetime
      add :active, :boolean, default: true
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:session_packages, [:client_id])
    create index(:session_packages, [:active])
    create index(:session_packages, [:client_id, :active])
  end
end
