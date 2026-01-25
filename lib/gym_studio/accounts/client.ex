defmodule GymStudio.Accounts.Client do
  @moduledoc """
  Client profile schema.

  Clients are users with the :client role who can book training sessions
  and purchase session packages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field :emergency_contact_name, :string
    field :emergency_contact_phone, :string
    field :health_notes, :string
    field :goals, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a client profile.
  """
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:user_id, :emergency_contact_name, :emergency_contact_phone, :health_notes, :goals])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
    |> validate_phone_format()
  end

  defp validate_phone_format(changeset) do
    case get_change(changeset, :emergency_contact_phone) do
      nil ->
        changeset

      phone ->
        if Regex.match?(~r/^\+?[0-9\s\-\(\)]{8,20}$/, phone) do
          changeset
        else
          add_error(changeset, :emergency_contact_phone, "must be a valid phone number")
        end
    end
  end
end
