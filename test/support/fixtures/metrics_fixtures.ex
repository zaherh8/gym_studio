defmodule GymStudio.MetricsFixtures do
  @moduledoc """
  Test helpers for creating body metric entries.
  """

  alias GymStudio.Metrics

  def body_metric_fixture(attrs \\ %{}) do
    {:ok, metric} =
      attrs
      |> Enum.into(%{
        "date" => Date.utc_today() |> Date.to_string(),
        "weight_kg" => "75.0"
      })
      |> Metrics.create_metric()

    metric
  end
end
