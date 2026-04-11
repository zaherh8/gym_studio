defmodule GymStudio.Repo.Migrations.AddBranchIdToTables do
  use Ecto.Migration

  def up do
    # 1. Add nullable branch_id to all target tables
    alter table(:users) do
      add :branch_id, references(:branches, on_delete: :restrict), null: true
    end

    alter table(:session_packages) do
      add :branch_id, references(:branches, on_delete: :restrict), null: true
    end

    alter table(:training_sessions) do
      add :branch_id, references(:branches, on_delete: :restrict), null: true
    end

    alter table(:trainer_availabilities) do
      add :branch_id, references(:branches, on_delete: :restrict), null: true
    end

    alter table(:trainer_time_offs) do
      add :branch_id, references(:branches, on_delete: :restrict), null: true
    end

    # 2. Backfill all existing records to Branch 1 (Sin El Fil)
    # Using execute to run raw SQL for backfill
    execute "UPDATE users SET branch_id = 1 WHERE branch_id IS NULL"
    execute "UPDATE session_packages SET branch_id = 1 WHERE branch_id IS NULL"
    execute "UPDATE training_sessions SET branch_id = 1 WHERE branch_id IS NULL"
    execute "UPDATE trainer_availabilities SET branch_id = 1 WHERE branch_id IS NULL"
    execute "UPDATE trainer_time_offs SET branch_id = 1 WHERE branch_id IS NULL"

    # 3. Make branch_id NOT NULL
    alter table(:users) do
      modify :branch_id, :bigint, null: false
    end

    alter table(:session_packages) do
      modify :branch_id, :bigint, null: false
    end

    alter table(:training_sessions) do
      modify :branch_id, :bigint, null: false
    end

    alter table(:trainer_availabilities) do
      modify :branch_id, :bigint, null: false
    end

    alter table(:trainer_time_offs) do
      modify :branch_id, :bigint, null: false
    end

    # 4. Add indexes
    create index(:users, [:branch_id])
    create index(:session_packages, [:branch_id])
    create index(:training_sessions, [:branch_id])
    create index(:trainer_availabilities, [:branch_id])
    create index(:trainer_time_offs, [:branch_id])

    # 5. Composite indexes for common query patterns
    create index(:training_sessions, [:branch_id, :status])
    create index(:training_sessions, [:branch_id, :trainer_id])
    create index(:session_packages, [:branch_id, :active])
    create index(:trainer_availabilities, [:branch_id, :trainer_id])
  end

  def down do
    drop index(:trainer_availabilities, [:branch_id, :trainer_id])
    drop index(:session_packages, [:branch_id, :active])
    drop index(:training_sessions, [:branch_id, :trainer_id])
    drop index(:training_sessions, [:branch_id, :status])
    drop index(:trainer_time_offs, [:branch_id])
    drop index(:trainer_availabilities, [:branch_id])
    drop index(:training_sessions, [:branch_id])
    drop index(:session_packages, [:branch_id])
    drop index(:users, [:branch_id])

    alter table(:users) do
      remove :branch_id
    end

    alter table(:session_packages) do
      remove :branch_id
    end

    alter table(:training_sessions) do
      remove :branch_id
    end

    alter table(:trainer_availabilities) do
      remove :branch_id
    end

    alter table(:trainer_time_offs) do
      remove :branch_id
    end
  end
end
