defmodule GymStudio.Progress do
  @moduledoc """
  The Progress context - manages exercises and workout tracking.
  """

  import Ecto.Query
  alias GymStudio.Repo
  alias GymStudio.Progress.Exercise

  def list_exercises(opts \\ []) do
    Exercise
    |> apply_filters(opts)
    |> order_by([e], asc: e.name)
    |> Repo.all()
  end

  defp apply_filters(query, []), do: query

  defp apply_filters(query, [{:category, category} | rest])
       when is_binary(category) and category != "" do
    query |> where([e], e.category == ^category) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:search, search} | rest]) when is_binary(search) and search != "" do
    pattern = "%#{search}%"
    query |> where([e], ilike(e.name, ^pattern)) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:custom_only, true} | rest]) do
    query |> where([e], e.is_custom == true) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:created_by_id, id} | rest]) when not is_nil(id) do
    query |> where([e], e.created_by_id == ^id) |> apply_filters(rest)
  end

  defp apply_filters(query, [_ | rest]), do: apply_filters(query, rest)

  def get_exercise!(id), do: Repo.get!(Exercise, id)

  def create_exercise(attrs, user \\ nil) do
    attrs =
      if user do
        Map.merge(attrs, %{"is_custom" => true, "created_by_id" => user.id})
      else
        attrs
      end

    %Exercise{}
    |> Exercise.changeset(attrs)
    |> Repo.insert()
  end

  def update_exercise(%Exercise{} = exercise, attrs) do
    exercise
    |> Exercise.changeset(attrs)
    |> Repo.update()
  end

  def delete_exercise(%Exercise{is_custom: true} = exercise) do
    Repo.delete(exercise)
  end

  def delete_exercise(%Exercise{is_custom: false}) do
    {:error, :cannot_delete_predefined}
  end

  def search_exercises(query) when is_binary(query) do
    pattern = "%#{query}%"

    Exercise
    |> where([e], ilike(e.name, ^pattern))
    |> order_by([e], asc: e.name)
    |> limit(10)
    |> Repo.all()
  end

  def list_categories, do: Exercise.categories()
  def list_muscle_groups, do: Exercise.muscle_groups()
  def list_equipment, do: Exercise.equipment()
  def list_tracking_types, do: Exercise.tracking_types()
end
