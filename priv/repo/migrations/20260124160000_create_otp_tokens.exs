defmodule GymStudio.Repo.Migrations.CreateOtpTokens do
  use Ecto.Migration

  def change do
    create table(:otp_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_number, :string, null: false
      add :hashed_code, :string, null: false
      add :purpose, :string, null: false
      add :attempts, :integer, default: 0, null: false
      add :expires_at, :utc_datetime, null: false
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:otp_tokens, [:phone_number, :purpose])
    create index(:otp_tokens, [:expires_at])
  end
end
