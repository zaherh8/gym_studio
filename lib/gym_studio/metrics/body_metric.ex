defmodule GymStudio.Metrics.BodyMetric do
  @moduledoc """
  Schema for body metrics (weight, body fat %, measurements).
  One entry per user per day.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @measurement_fields [
    :weight_kg,
    :body_fat_pct,
    :chest_cm,
    :waist_cm,
    :hips_cm,
    :bicep_cm,
    :thigh_cm
  ]

  schema "body_metrics" do
    belongs_to :user, GymStudio.Accounts.User
    belongs_to :logged_by, GymStudio.Accounts.User

    field :date, :date
    field :weight_kg, :decimal
    field :body_fat_pct, :decimal
    field :chest_cm, :decimal
    field :waist_cm, :decimal
    field :hips_cm, :decimal
    field :bicep_cm, :decimal
    field :thigh_cm, :decimal
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(body_metric, attrs) do
    body_metric
    |> cast(attrs, [
      :user_id,
      :logged_by_id,
      :date,
      :weight_kg,
      :body_fat_pct,
      :chest_cm,
      :waist_cm,
      :hips_cm,
      :bicep_cm,
      :thigh_cm,
      :notes
    ])
    |> validate_required([:user_id, :logged_by_id, :date])
    |> validate_number(:weight_kg, greater_than: 0)
    |> validate_number(:body_fat_pct, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:chest_cm, greater_than: 0)
    |> validate_number(:waist_cm, greater_than: 0)
    |> validate_number(:hips_cm, greater_than: 0)
    |> validate_number(:bicep_cm, greater_than: 0)
    |> validate_number(:thigh_cm, greater_than: 0)
    |> validate_at_least_one_measurement()
    |> unique_constraint([:user_id, :date])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:logged_by_id)
  end

  defp validate_at_least_one_measurement(changeset) do
    has_value =
      Enum.any?(@measurement_fields, fn field ->
        value = get_field(changeset, field)
        not is_nil(value)
      end)

    if has_value do
      changeset
    else
      add_error(
        changeset,
        :weight_kg,
        "at least one measurement (weight or body measurement) must be provided"
      )
    end
  end
end
