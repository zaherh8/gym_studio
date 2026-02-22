defmodule GymStudio.Progress.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(strength cardio flexibility functional)
  @muscle_groups ~w(chest back legs shoulders arms core full_body cardio
                    abdominals abductors adductors biceps calves forearms
                    glutes hamstrings lats lower_back middle_back neck
                    quadriceps traps triceps)
  @equipment ~w(barbell dumbbell kettlebell machine cable bodyweight
               cardio_machine resistance_band none exercise_ball
               foam_roll medicine_ball other)
  @tracking_types ~w(weight_reps duration reps_only distance)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "exercises" do
    field :name, :string
    field :category, :string
    field :muscle_group, :string
    field :equipment, :string
    field :tracking_type, :string
    field :description, :string
    field :is_custom, :boolean, default: false

    belongs_to :created_by, GymStudio.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def categories, do: @categories
  def muscle_groups, do: @muscle_groups
  def equipment, do: @equipment
  def tracking_types, do: @tracking_types

  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [
      :name,
      :category,
      :muscle_group,
      :equipment,
      :tracking_type,
      :description,
      :is_custom,
      :created_by_id
    ])
    |> validate_required([:name, :category, :tracking_type])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:tracking_type, @tracking_types)
    |> maybe_validate_inclusion(:muscle_group, @muscle_groups)
    |> maybe_validate_inclusion(:equipment, @equipment)
    |> unique_constraint(:name)
  end

  defp maybe_validate_inclusion(changeset, field, values) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _ -> validate_inclusion(changeset, field, values)
    end
  end
end
