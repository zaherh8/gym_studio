defmodule GymStudio.Scheduling.TimeSlot do
  @moduledoc """
  TimeSlot schema representing available booking time slots for training sessions.

  Time slots define the recurring weekly availability for bookings. Each slot
  specifies a day of the week (1-7, where 1 is Monday) and a start/end time range.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "time_slots" do
    field :day_of_week, :integer
    field :start_time, :time
    field :end_time, :time
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a time slot.

  ## Validations
  - day_of_week must be between 1 and 7 (1 = Monday, 7 = Sunday)
  - start_time and end_time are required
  - end_time must be after start_time
  """
  def changeset(time_slot, attrs) do
    time_slot
    |> cast(attrs, [:day_of_week, :start_time, :end_time, :active])
    |> validate_required([:day_of_week, :start_time, :end_time])
    |> validate_number(:day_of_week, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> validate_time_range()
  end

  defp validate_time_range(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
