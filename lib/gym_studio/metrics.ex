defmodule GymStudio.Metrics do
  @moduledoc """
  The Metrics context — manages body metrics (weight, measurements, body fat).
  """

  import Ecto.Query
  alias GymStudio.Repo
  alias GymStudio.Metrics.BodyMetric

  @doc """
  Lists body metrics for a user, ordered by date descending.

  ## Options
    * `:limit` - maximum number of results to return
  """
  def list_metrics(user_id, opts \\ []) do
    query =
      BodyMetric
      |> where([m], m.user_id == ^user_id)
      |> order_by([m], desc: m.date)

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end

    Repo.all(query)
  end

  @doc "Gets a single body metric by ID. Raises if not found."
  def get_metric!(id), do: Repo.get!(BodyMetric, id)

  @doc """
  Creates a body metric entry. Upserts on (user_id, date) — if an entry
  already exists for that user and date, it is replaced.
  """
  def create_metric(attrs) do
    %BodyMetric{}
    |> BodyMetric.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :user_id, :inserted_at]},
      conflict_target: [:user_id, :date],
      returning: true
    )
  end

  @doc "Updates an existing body metric entry."
  def update_metric(%BodyMetric{} = metric, attrs) do
    metric
    |> BodyMetric.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a body metric entry."
  def delete_metric(%BodyMetric{} = metric) do
    Repo.delete(metric)
  end

  @doc "Returns the most recent body metric for a user, or nil."
  def get_latest_metric(user_id) do
    BodyMetric
    |> where([m], m.user_id == ^user_id)
    |> order_by([m], desc: m.date)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns a list of `{date, value}` tuples for a specific field, ordered by date ascending.
  Useful for charting. Only returns entries where the field is not nil.

  Valid fields: `:weight_kg`, `:body_fat_pct`, `:chest_cm`, `:waist_cm`,
  `:hips_cm`, `:bicep_cm`, `:thigh_cm`.
  """
  @valid_fields ~w(weight_kg body_fat_pct chest_cm waist_cm hips_cm bicep_cm thigh_cm)a

  def get_metric_history(user_id, field) when field in @valid_fields do
    BodyMetric
    |> where([m], m.user_id == ^user_id and not is_nil(field(m, ^field)))
    |> order_by([m], asc: m.date)
    |> select([m], {m.date, field(m, ^field)})
    |> Repo.all()
  end

  @doc "Returns a changeset for tracking form changes."
  def change_metric(%BodyMetric{} = metric, attrs \\ %{}) do
    BodyMetric.changeset(metric, attrs)
  end
end
