defmodule GymStudio.Notifications.Notification do
  @moduledoc """
  Schema for in-app notifications.

  Notifications are used to inform users about important events such as:
  - Session booking confirmations
  - Session cancellations
  - Package assignments
  - Session reminders

  ## Types
  - `:booking_confirmed` - When a booking request is approved
  - `:booking_cancelled` - When a session is cancelled
  - `:session_reminder` - Reminder before upcoming session
  - `:package_assigned` - When admin assigns a new package
  - `:trainer_approved` - When trainer profile is approved
  - `:general` - General announcements
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @types ~w(booking_confirmed booking_cancelled session_reminder package_assigned trainer_approved general)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :title, :string
    field :message, :string
    field :type, :string
    field :read_at, :utc_datetime
    field :action_url, :string
    field :metadata, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc "Returns the list of valid notification types"
  def types, do: @types

  @doc """
  Changeset for creating a notification.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :title, :message, :type, :action_url, :metadata])
    |> validate_required([:user_id, :title, :message, :type])
    |> validate_inclusion(:type, @types)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for marking a notification as read.
  """
  def read_changeset(notification) do
    notification
    |> change(%{read_at: DateTime.utc_now(:second)})
  end
end
