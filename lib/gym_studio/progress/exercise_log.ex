defmodule GymStudio.Progress.ExerciseLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "exercise_logs" do
    belongs_to :training_session, GymStudio.Scheduling.TrainingSession
    belongs_to :exercise, GymStudio.Progress.Exercise
    belongs_to :client, GymStudio.Accounts.User
    belongs_to :logged_by, GymStudio.Accounts.User

    field :sets, :integer
    field :reps, :integer
    field :weight_kg, :decimal
    field :duration_seconds, :integer
    field :notes, :string
    field :order, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(exercise_log, attrs) do
    exercise_log
    |> cast(attrs, [
      :training_session_id,
      :exercise_id,
      :client_id,
      :logged_by_id,
      :sets,
      :reps,
      :weight_kg,
      :duration_seconds,
      :notes,
      :order
    ])
    |> validate_required([:training_session_id, :exercise_id, :client_id, :logged_by_id])
    |> validate_number(:sets, greater_than: 0)
    |> validate_number(:reps, greater_than: 0)
    |> validate_number(:weight_kg, greater_than: 0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:order, greater_than_or_equal_to: 0)
    |> validate_at_least_one_metric()
    |> foreign_key_constraint(:training_session_id)
    |> foreign_key_constraint(:exercise_id)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:logged_by_id)
  end

  defp validate_at_least_one_metric(changeset) do
    sets = get_field(changeset, :sets)
    reps = get_field(changeset, :reps)
    weight_kg = get_field(changeset, :weight_kg)
    duration_seconds = get_field(changeset, :duration_seconds)

    if is_nil(sets) and is_nil(reps) and is_nil(weight_kg) and is_nil(duration_seconds) do
      add_error(
        changeset,
        :sets,
        "at least one metric (sets, reps, weight, or duration) must be provided"
      )
    else
      changeset
    end
  end
end
