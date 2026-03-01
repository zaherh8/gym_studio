defmodule GymStudio.Scheduling.TrainerAvailability do
  @moduledoc """
  Schema for trainer weekly availability (working hours per day of week).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "trainer_availabilities" do
    belongs_to :trainer, User
    field :day_of_week, :integer
    field :start_time, :time
    field :end_time, :time
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @day_names %{
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday",
    7 => "Sunday"
  }

  def day_name(day_of_week), do: Map.get(@day_names, day_of_week, "Unknown")

  def changeset(availability, attrs) do
    availability
    |> cast(attrs, [:trainer_id, :day_of_week, :start_time, :end_time, :active])
    |> validate_required([:trainer_id, :day_of_week, :start_time, :end_time])
    |> validate_number(:day_of_week, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> validate_time_range()
    |> unique_constraint([:trainer_id, :day_of_week])
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
