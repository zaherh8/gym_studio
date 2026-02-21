defmodule GymStudio.Scheduling.TrainingSession do
  @moduledoc """
  TrainingSession schema representing a booked training session.

  ## Booking Flow
  1. Client books a session with status "pending"
  2. Admin/Trainer approves the session, assigns trainer, and changes status to "confirmed"
  3. After the session, trainer marks it as "completed" with optional notes
  4. Session can be cancelled by client, trainer, or admin at any time

  ## Statuses
  - `pending` - Session is awaiting approval
  - `confirmed` - Session is approved and trainer is assigned
  - `completed` - Session has been completed
  - `cancelled` - Session was cancelled
  - `no_show` - Client did not attend the session
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @statuses ~w(pending confirmed completed cancelled no_show)
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "training_sessions" do
    belongs_to :client, User
    belongs_to :trainer, User
    belongs_to :package, GymStudio.Packages.SessionPackage
    belongs_to :approved_by, User
    belongs_to :cancelled_by, User

    field :scheduled_at, :utc_datetime
    field :duration_minutes, :integer, default: 60
    field :status, :string, default: "pending"
    field :notes, :string
    field :trainer_notes, :string
    field :approved_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Changeset for booking a training session by a client.

  Used when a client creates a new booking. The session starts in "pending" status.

  ## Required fields
  - client_id
  - scheduled_at
  - duration_minutes

  ## Optional fields
  - notes (client notes about the session)
  - package_id (if booking from a package)
  """
  def changeset(training_session, attrs) do
    training_session
    |> cast(attrs, [:client_id, :package_id, :scheduled_at, :duration_minutes, :notes])
    |> validate_required([:client_id, :scheduled_at, :duration_minutes])
    |> validate_number(:duration_minutes, greater_than: 0)
    |> validate_scheduled_at_in_future()
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:package_id)
    |> put_change(:status, "pending")
  end

  @doc """
  Changeset for approving a training session.

  Used by admin/trainer to approve a pending session and assign a trainer.

  ## Required fields
  - trainer_id (the assigned trainer)
  - approved_by_id (the admin/trainer who approved it)

  ## Changes
  - Sets status to "confirmed"
  - Sets approved_at to current UTC time
  """
  def approval_changeset(training_session, attrs) do
    training_session
    |> cast(attrs, [:trainer_id, :approved_by_id])
    |> validate_required([:trainer_id, :approved_by_id])
    |> validate_status_is("pending", "Only pending sessions can be approved")
    |> foreign_key_constraint(:trainer_id)
    |> foreign_key_constraint(:approved_by_id)
    |> put_change(:status, "confirmed")
    |> put_change(:approved_at, DateTime.utc_now(:second))
  end

  @doc """
  Changeset for completing a training session.

  Used by trainer to mark a session as completed after it has taken place.

  ## Optional fields
  - trainer_notes (feedback about the session)

  ## Changes
  - Sets status to "completed"
  """
  def completion_changeset(training_session, attrs) do
    training_session
    |> cast(attrs, [:trainer_notes])
    |> validate_status_is("confirmed", "Only confirmed sessions can be completed")
    |> put_change(:status, "completed")
  end

  @doc """
  Changeset for cancelling a training session.

  Used by client, trainer, or admin to cancel a session.

  ## Required fields
  - cancelled_by_id (who cancelled the session)
  - cancellation_reason

  ## Changes
  - Sets status to "cancelled"
  - Sets cancelled_at to current UTC time
  """
  def cancellation_changeset(training_session, attrs) do
    training_session
    |> cast(attrs, [:cancelled_by_id, :cancellation_reason])
    |> validate_required([:cancelled_by_id, :cancellation_reason])
    |> validate_status_in(
      ["pending", "confirmed"],
      "Only pending or confirmed sessions can be cancelled"
    )
    |> foreign_key_constraint(:cancelled_by_id)
    |> put_change(:status, "cancelled")
    |> put_change(:cancelled_at, DateTime.utc_now(:second))
  end

  @doc """
  Changeset for marking a session as no-show.

  Used by trainer or admin when a client doesn't attend a confirmed session.

  ## Changes
  - Sets status to "no_show"
  """
  def no_show_changeset(training_session, _attrs \\ %{}) do
    training_session
    |> change()
    |> validate_status_is("confirmed", "Only confirmed sessions can be marked as no-show")
    |> put_change(:status, "no_show")
  end

  # Private validation helpers

  defp validate_scheduled_at_in_future(changeset) do
    scheduled_at = get_field(changeset, :scheduled_at)

    if scheduled_at && DateTime.compare(scheduled_at, DateTime.utc_now()) == :lt do
      add_error(changeset, :scheduled_at, "must be in the future")
    else
      changeset
    end
  end

  defp validate_status_is(changeset, expected_status, message) do
    current_status = get_field(changeset, :status)

    if current_status != expected_status do
      add_error(changeset, :status, message)
    else
      changeset
    end
  end

  defp validate_status_in(changeset, allowed_statuses, message) do
    current_status = get_field(changeset, :status)

    if current_status not in allowed_statuses do
      add_error(changeset, :status, message)
    else
      changeset
    end
  end
end
