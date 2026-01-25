defmodule GymStudio.Repo.Migrations.AddRolePhoneActiveToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "client"
      add :phone_number, :string, null: false
      add :active, :boolean, null: false, default: true
    end

    create unique_index(:users, [:phone_number])
    create index(:users, [:role])
    create index(:users, [:active])
  end
end
