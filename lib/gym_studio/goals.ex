defmodule GymStudio.Goals do
  @moduledoc """
  The Goals context — manages fitness goals with progress tracking.
  """

  import Ecto.Query
  alias GymStudio.Repo
  alias GymStudio.Goals.FitnessGoal

  @doc "Lists goals for a client, optionally filtered by status. Ordered by inserted_at desc."
  def list_goals(client_id, opts \\ []) do
    query =
      FitnessGoal
      |> where([g], g.client_id == ^client_id)
      |> order_by([g], desc: g.inserted_at)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        "" -> query
        "all" -> query
        status -> where(query, [g], g.status == ^status)
      end

    Repo.all(query)
  end

  @doc "Gets a single goal by ID. Raises if not found."
  def get_goal!(id), do: Repo.get!(FitnessGoal, id)

  @doc "Creates a fitness goal."
  def create_goal(attrs) do
    %FitnessGoal{}
    |> FitnessGoal.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a fitness goal."
  def update_goal(%FitnessGoal{} = goal, attrs) do
    goal
    |> FitnessGoal.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a goal. Only active goals can be deleted."
  def delete_goal(%FitnessGoal{status: "active"} = goal), do: Repo.delete(goal)
  def delete_goal(%FitnessGoal{}), do: {:error, :not_active}

  @doc "Marks a goal as achieved with current timestamp."
  def achieve_goal(%FitnessGoal{} = goal) do
    goal
    |> FitnessGoal.changeset(%{status: "achieved", achieved_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  @doc "Marks a goal as abandoned."
  def abandon_goal(%FitnessGoal{} = goal) do
    goal
    |> FitnessGoal.changeset(%{status: "abandoned"})
    |> Repo.update()
  end

  @doc """
  Updates the current value of a goal. Auto-achieves if current_value >= target_value.
  """
  def update_progress(%FitnessGoal{} = goal, new_value) do
    new_value = to_decimal(new_value)

    attrs =
      if Decimal.compare(new_value, goal.target_value) in [:gt, :eq] do
        %{current_value: new_value, status: "achieved", achieved_at: DateTime.utc_now(:second)}
      else
        %{current_value: new_value}
      end

    goal
    |> FitnessGoal.changeset(attrs)
    |> Repo.update()
  end

  @doc "Returns an `%Ecto.Changeset{}` for tracking goal changes."
  def change_goal(%FitnessGoal{} = goal, attrs \\ %{}) do
    FitnessGoal.changeset(goal, attrs)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(v) when is_binary(v), do: Decimal.new(v)
  defp to_decimal(v) when is_integer(v), do: Decimal.new(v)
  defp to_decimal(v) when is_float(v), do: Decimal.from_float(v)
end
