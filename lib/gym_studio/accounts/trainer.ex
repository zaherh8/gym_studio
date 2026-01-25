defmodule GymStudio.Accounts.Trainer do
  @moduledoc """
  Trainer profile schema.

  Trainers are users with the :trainer role who have been approved by an admin.
  They can be assigned to training sessions and manage their schedules.

  ## Statuses
  - `:pending` - Awaiting admin approval
  - `:approved` - Active and can be assigned sessions
  - `:suspended` - Temporarily deactivated
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @statuses ~w(pending approved suspended)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "trainers" do
    field :bio, :string
    field :specializations, {:array, :string}, default: []
    field :photo_url, :string
    field :status, :string, default: "pending"
    field :approved_at, :utc_datetime

    belongs_to :user, User
    belongs_to :approved_by, User

    timestamps(type: :utc_datetime)
  end

  @doc "Returns the list of valid statuses"
  def statuses, do: @statuses

  @doc """
  Changeset for creating or updating a trainer profile.
  """
  def changeset(trainer, attrs) do
    trainer
    |> cast(attrs, [:user_id, :bio, :specializations, :photo_url])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for approving a trainer.
  """
  def approval_changeset(trainer, %User{} = approved_by) do
    trainer
    |> change(%{
      status: "approved",
      approved_at: DateTime.utc_now(:second),
      approved_by_id: approved_by.id
    })
  end

  @doc """
  Changeset for changing trainer status.
  """
  def status_changeset(trainer, status) when status in @statuses do
    trainer
    |> change(%{status: status})
  end

  def status_changeset(_trainer, _status) do
    raise ArgumentError, "Invalid status. Must be one of: #{inspect(@statuses)}"
  end
end
