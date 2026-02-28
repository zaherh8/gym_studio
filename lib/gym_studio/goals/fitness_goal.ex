defmodule GymStudio.Goals.FitnessGoal do
  @moduledoc """
  Schema for fitness goals — tracks client goals with progress toward a target value.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "fitness_goals" do
    field :title, :string
    field :description, :string
    field :target_value, :decimal
    field :target_unit, :string
    field :current_value, :decimal, default: Decimal.new(0)
    field :status, :string, default: "active"
    field :target_date, :date
    field :achieved_at, :utc_datetime

    belongs_to :client, GymStudio.Accounts.User
    belongs_to :created_by, GymStudio.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(active achieved abandoned)

  @doc "Returns valid statuses."
  def statuses, do: @statuses

  @doc "Changeset for creating/updating a fitness goal."
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :client_id,
      :created_by_id,
      :title,
      :description,
      :target_value,
      :target_unit,
      :current_value,
      :status,
      :target_date,
      :achieved_at
    ])
    |> validate_required([:client_id, :created_by_id, :title, :target_value, :target_unit])
    |> validate_length(:title, max: 255)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:target_value, greater_than: 0)
    |> validate_number(:current_value, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
