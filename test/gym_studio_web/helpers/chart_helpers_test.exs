defmodule GymStudioWeb.ChartHelpersTest do
  use ExUnit.Case, async: true

  alias GymStudioWeb.ChartHelpers

  defp make_log(attrs) do
    %{
      inserted_at: Map.get(attrs, :inserted_at, ~U[2025-01-15 10:00:00Z]),
      weight_kg: Map.get(attrs, :weight_kg),
      reps: Map.get(attrs, :reps),
      duration_seconds: Map.get(attrs, :duration_seconds)
    }
  end

  describe "build_chart_data/2" do
    test "returns valid JSON with expected keys" do
      exercise = %{tracking_type: "weight_reps"}
      log = make_log(%{weight_kg: Decimal.new("50.0")})

      json = ChartHelpers.build_chart_data([log], exercise)
      data = Jason.decode!(json)

      assert Map.has_key?(data, "labels")
      assert Map.has_key?(data, "values")
      assert Map.has_key?(data, "y_label")
    end

    test "weight_reps tracking uses weight values" do
      exercise = %{tracking_type: "weight_reps"}

      logs = [
        make_log(%{inserted_at: ~U[2025-01-02 10:00:00Z], weight_kg: Decimal.new("60.0")}),
        make_log(%{inserted_at: ~U[2025-01-01 10:00:00Z], weight_kg: Decimal.new("50.0")})
      ]

      data = Jason.decode!(ChartHelpers.build_chart_data(logs, exercise))
      # Reversed for chart (oldest first)
      assert data["values"] == [50.0, 60.0]
      assert data["y_label"] == "Weight (kg)"
    end

    test "reps_only tracking uses reps values" do
      exercise = %{tracking_type: "reps_only"}
      logs = [make_log(%{reps: 15})]

      data = Jason.decode!(ChartHelpers.build_chart_data(logs, exercise))
      assert data["values"] == [15]
      assert data["y_label"] == "Reps"
    end

    test "duration tracking uses duration values" do
      exercise = %{tracking_type: "duration"}
      logs = [make_log(%{duration_seconds: 300})]

      data = Jason.decode!(ChartHelpers.build_chart_data(logs, exercise))
      assert data["values"] == [300]
      assert data["y_label"] == "Duration (s)"
    end

    test "handles empty history" do
      exercise = %{tracking_type: "weight_reps"}
      data = Jason.decode!(ChartHelpers.build_chart_data([], exercise))
      assert data["labels"] == []
      assert data["values"] == []
    end

    test "nil weight defaults to 0" do
      exercise = %{tracking_type: "weight_reps"}
      logs = [make_log(%{weight_kg: nil})]

      data = Jason.decode!(ChartHelpers.build_chart_data(logs, exercise))
      assert data["values"] == [0]
    end
  end
end
