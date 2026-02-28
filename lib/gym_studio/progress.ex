defmodule GymStudio.Progress do
  @moduledoc """
  The Progress context - manages exercises and workout tracking.
  """

  import Ecto.Query
  alias GymStudio.Repo
  alias GymStudio.Progress.Exercise
  alias GymStudio.Progress.ExerciseLog

  # ── Exercises ──────────────────────────────────────────────────────

  def list_exercises(opts \\ []) do
    Exercise
    |> apply_filters(opts)
    |> order_by([e], asc: e.name)
    |> Repo.all()
  end

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

  def delete_exercise(%Exercise{is_custom: true} = exercise), do: Repo.delete(exercise)
  def delete_exercise(%Exercise{is_custom: false}), do: {:error, :cannot_delete_predefined}

  def search_exercises(query) when is_binary(query) do
    escaped = escape_ilike(query)
    pattern = "%#{escaped}%"

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

  # ── Exercise Logs ──────────────────────────────────────────────────

  def list_exercise_logs(session_id) do
    ExerciseLog
    |> where([l], l.training_session_id == ^session_id)
    |> order_by([l], asc: l.order)
    |> preload(:exercise)
    |> Repo.all()
  end

  @doc "Alias kept for backward compat"
  def list_exercise_logs_for_session(session_id), do: list_exercise_logs(session_id)

  def get_exercise_log!(id), do: Repo.get!(ExerciseLog, id)

  def create_exercise_log(attrs) do
    %ExerciseLog{}
    |> ExerciseLog.changeset(attrs)
    |> Repo.insert()
  end

  def update_exercise_log(%ExerciseLog{} = log, attrs) do
    log
    |> ExerciseLog.changeset(attrs)
    |> Repo.update()
  end

  def delete_exercise_log(%ExerciseLog{} = log) do
    Repo.delete(log)
  end

  def list_exercise_logs_for_client(client_id, opts \\ []) do
    query =
      ExerciseLog
      |> where([l], l.client_id == ^client_id)
      |> order_by([l], desc: l.inserted_at)
      |> preload(:exercise)

    query =
      case Keyword.get(opts, :exercise_id) do
        nil -> query
        exercise_id -> where(query, [l], l.exercise_id == ^exercise_id)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end

    Repo.all(query)
  end

  @doc """
  Returns best weight per exercise for a client.
  Returns a list of `%{exercise_id, exercise_name, max_weight_kg}`.
  """
  def get_personal_records(client_id) do
    ExerciseLog
    |> where([l], l.client_id == ^client_id and not is_nil(l.weight_kg))
    |> join(:inner, [l], e in Exercise, on: l.exercise_id == e.id)
    |> group_by([l, e], [l.exercise_id, e.name])
    |> select([l, e], %{
      exercise_id: l.exercise_id,
      exercise_name: e.name,
      max_weight_kg: max(l.weight_kg)
    })
    |> Repo.all()
  end

  @doc """
  Returns personal records for a specific exercise (compat with old API).
  """
  def get_personal_records(client_id, exercise_id) do
    result =
      ExerciseLog
      |> where([l], l.client_id == ^client_id and l.exercise_id == ^exercise_id)
      |> select([l], %{
        max_weight_kg: max(l.weight_kg),
        max_reps: max(l.reps),
        max_duration_seconds: max(l.duration_seconds)
      })
      |> Repo.one()

    result || %{max_weight_kg: nil, max_reps: nil, max_duration_seconds: nil}
  end

  @doc """
  Reorder exercise logs for a session. `log_ids` is an ordered list of log IDs.
  """
  def reorder_exercise_logs(session_id, log_ids) when is_list(log_ids) do
    Repo.transaction(fn ->
      log_ids
      |> Enum.with_index()
      |> Enum.each(fn {log_id, idx} ->
        ExerciseLog
        |> where([l], l.id == ^log_id and l.training_session_id == ^session_id)
        |> Repo.update_all(set: [order: idx])
      end)
    end)
  end

  # ── Client Progress ────────────────────────────────────────────────

  @doc """
  Returns distinct exercises the client has logged, with latest stats and PR info.
  Each result includes: exercise, latest log stats, total session count, and PR flag.
  """
  def list_client_exercises(client_id, opts \\ []) do
    base_query =
      ExerciseLog
      |> where([l], l.client_id == ^client_id)
      |> join(:inner, [l], e in Exercise, on: l.exercise_id == e.id)

    # Get PRs for this client
    prs = get_personal_records(client_id)
    pr_map = Map.new(prs, &{&1.exercise_id, &1.max_weight_kg})

    # Get distinct exercises with aggregate stats
    exercises_with_stats =
      base_query
      |> group_by([l, e], [e.id, e.name, e.category, e.muscle_group, e.equipment, e.tracking_type])
      |> select([l, e], %{
        exercise_id: e.id,
        exercise_name: e.name,
        category: e.category,
        muscle_group: e.muscle_group,
        equipment: e.equipment,
        tracking_type: e.tracking_type,
        total_sessions: count(l.id),
        latest_date: max(l.inserted_at)
      })
      |> order_by([l, e], asc: e.name)
      |> Repo.all()

    # Apply category filter
    exercises_with_stats =
      case Keyword.get(opts, :category) do
        nil -> exercises_with_stats
        "" -> exercises_with_stats
        cat -> Enum.filter(exercises_with_stats, &(&1.category == cat))
      end

    # Enrich with latest log stats and PR info
    Enum.map(exercises_with_stats, fn ex ->
      latest_log =
        ExerciseLog
        |> where([l], l.client_id == ^client_id and l.exercise_id == ^ex.exercise_id)
        |> order_by([l], desc: l.inserted_at)
        |> limit(1)
        |> Repo.one()

      Map.merge(ex, %{
        latest_sets: latest_log && latest_log.sets,
        latest_reps: latest_log && latest_log.reps,
        latest_weight_kg: latest_log && latest_log.weight_kg,
        has_pr: Map.has_key?(pr_map, ex.exercise_id)
      })
    end)
  end

  @doc """
  Returns all exercise logs for a specific exercise and client, ordered by date desc.
  Preloads exercise and training_session associations.
  """
  def get_exercise_history(client_id, exercise_id) do
    ExerciseLog
    |> where([l], l.client_id == ^client_id and l.exercise_id == ^exercise_id)
    |> order_by([l], desc: l.inserted_at)
    |> preload([:exercise, :training_session])
    |> Repo.all()
  end

  @doc """
  Returns aggregate stats for a specific exercise and client:
  max weight, max reps, total volume, total sessions.
  """
  def get_exercise_stats(client_id, exercise_id) do
    result =
      ExerciseLog
      |> where([l], l.client_id == ^client_id and l.exercise_id == ^exercise_id)
      |> select([l], %{
        max_weight_kg: max(l.weight_kg),
        max_reps: max(l.reps),
        total_sessions: count(l.id)
      })
      |> Repo.one()

    # Calculate total volume separately (sets × reps × weight) since we need per-row calculation
    total_volume =
      ExerciseLog
      |> where(
        [l],
        l.client_id == ^client_id and l.exercise_id == ^exercise_id and
          not is_nil(l.sets) and not is_nil(l.reps) and not is_nil(l.weight_kg)
      )
      |> select(
        [l],
        fragment(
          "COALESCE(SUM(? * ? * ?), 0)",
          l.sets,
          l.reps,
          l.weight_kg
        )
      )
      |> Repo.one()

    Map.put(
      result || %{max_weight_kg: nil, max_reps: nil, total_sessions: 0},
      :total_volume,
      total_volume || Decimal.new(0)
    )
  end

  # ── Private helpers ────────────────────────────────────────────────

  defp apply_filters(query, []), do: query

  defp apply_filters(query, [{:category, category} | rest])
       when is_binary(category) and category != "" do
    query |> where([e], e.category == ^category) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:search, search} | rest]) when is_binary(search) and search != "" do
    escaped = escape_ilike(search)
    pattern = "%#{escaped}%"
    query |> where([e], ilike(e.name, ^pattern)) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:custom_only, true} | rest]) do
    query |> where([e], e.is_custom == true) |> apply_filters(rest)
  end

  defp apply_filters(query, [{:created_by_id, id} | rest]) when not is_nil(id) do
    query |> where([e], e.created_by_id == ^id) |> apply_filters(rest)
  end

  defp apply_filters(query, [_ | rest]), do: apply_filters(query, rest)

  defp escape_ilike(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
