defmodule GymStudio.Repo.Migrations.CreateBodyMetrics do
  use Ecto.Migration

  def change do
    create table(:body_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :logged_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :date, :date, null: false
      add :weight_kg, :decimal
      add :body_fat_pct, :decimal
      add :chest_cm, :decimal
      add :waist_cm, :decimal
      add :hips_cm, :decimal
      add :bicep_cm, :decimal
      add :thigh_cm, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:body_metrics, [:user_id])
    create index(:body_metrics, [:logged_by_id])
    create unique_index(:body_metrics, [:user_id, :date])
  end
end
