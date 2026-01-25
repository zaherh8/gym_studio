defmodule GymStudio.Repo do
  use Ecto.Repo,
    otp_app: :gym_studio,
    adapter: Ecto.Adapters.Postgres
end
