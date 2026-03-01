defmodule GymStudio.Scheduling.TrainerTimeOff do
  @moduledoc """
  Schema for trainer time-off entries (specific dates or partial days).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "trainer_time_offs" do
    belongs_to :trainer, User
    field :date, :date
    field :start_time, :time
    field :end_time, :time
    field :reason, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(time_off, attrs) do
    time_off
    |> cast(attrs, [:trainer_id, :date, :start_time, :end_time, :reason])
    |> validate_required([:trainer_id, :date])
    |> validate_time_range()
  end

  defp validate_time_range(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    cond do
      is_nil(start_time) && is_nil(end_time) ->
        changeset

      is_nil(start_time) || is_nil(end_time) ->
        add_error(changeset, :end_time, "both start and end time must be set, or neither")

      Time.compare(start_time, end_time) != :lt ->
        add_error(changeset, :end_time, "must be after start time")

      true ->
        changeset
    end
  end
end
