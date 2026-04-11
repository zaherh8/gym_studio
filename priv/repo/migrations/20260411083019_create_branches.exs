defmodule GymStudio.Repo.Migrations.CreateBranches do
  use Ecto.Migration

  def change do
    create table(:branches) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :address, :text
      add :capacity, :integer, null: false
      add :phone, :string
      add :latitude, :float
      add :longitude, :float
      add :operating_hours, :map
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:branches, [:slug])
  end
end
