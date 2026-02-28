defmodule GymStudioWeb.ChartHelpers do
  @moduledoc """
  Helper functions for building chart data from exercise logs.
  """

  @doc """
  Builds JSON-encoded chart data from exercise history and exercise metadata.
  Returns a JSON string with labels, values, and y_label keys.
  """
  def build_chart_data(history, exercise) do
    sorted = Enum.reverse(history)

    labels =
      Enum.map(sorted, fn log ->
        Calendar.strftime(log.inserted_at, "%Y-%m-%d")
      end)

    values =
      case exercise.tracking_type do
        "weight_reps" ->
          Enum.map(sorted, fn log ->
            if log.weight_kg, do: Decimal.to_float(log.weight_kg), else: 0
          end)

        "reps_only" ->
          Enum.map(sorted, fn log -> log.reps || 0 end)

        "duration" ->
          Enum.map(sorted, fn log -> log.duration_seconds || 0 end)

        _ ->
          Enum.map(sorted, fn log ->
            if log.weight_kg, do: Decimal.to_float(log.weight_kg), else: log.reps || 0
          end)
      end

    y_label =
      case exercise.tracking_type do
        "weight_reps" -> "Weight (kg)"
        "reps_only" -> "Reps"
        "duration" -> "Duration (s)"
        _ -> "Value"
      end

    Jason.encode!(%{labels: labels, values: values, y_label: y_label})
  end
end
