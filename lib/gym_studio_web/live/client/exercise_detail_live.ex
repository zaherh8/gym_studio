defmodule GymStudioWeb.Client.ExerciseDetailLive do
  @moduledoc """
  Exercise detail view showing chart (weight/reps over time),
  session history table, personal records, and stats summary.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Progress

  @impl true
  def mount(%{"exercise_id" => exercise_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    exercise = Progress.get_exercise!(exercise_id)
    history = Progress.get_exercise_history(user.id, exercise_id)
    stats = Progress.get_exercise_stats(user.id, exercise_id)
    prs = Progress.get_personal_records(user.id, exercise_id)

    chart_data = build_chart_data(history, exercise)

    socket =
      socket
      |> assign(page_title: exercise.name)
      |> assign(exercise: exercise)
      |> assign(history: history)
      |> assign(stats: stats)
      |> assign(prs: prs)
      |> assign(chart_data: chart_data)

    {:ok, socket}
  end

  defp build_chart_data(history, exercise) do
    # Reverse so oldest first for chart
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

  defp is_pr?(log, prs) do
    (log.weight_kg && prs.max_weight_kg && Decimal.equal?(log.weight_kg, prs.max_weight_kg)) ||
      (log.reps && prs.max_reps && log.reps == prs.max_reps)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <!-- Back link -->
        <div class="mb-4">
          <.link
            navigate={~p"/client/progress"}
            class="text-primary hover:underline flex items-center gap-1"
          >
            ← Back to Progress
          </.link>
        </div>
        
    <!-- Header -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800">{@exercise.name}</h1>
          <div class="flex gap-2 mt-2">
            <span class="badge badge-outline">{String.capitalize(@exercise.category)}</span>
            <%= if @exercise.muscle_group do %>
              <span class="badge badge-outline">{String.capitalize(@exercise.muscle_group)}</span>
            <% end %>
            <%= if @exercise.equipment do %>
              <span class="badge badge-outline">{String.capitalize(@exercise.equipment)}</span>
            <% end %>
          </div>
        </div>
        
    <!-- Stats Summary -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white rounded-2xl shadow-lg p-5 text-center">
            <p class="text-sm text-gray-500">Max Weight</p>
            <p class="text-2xl font-bold text-gray-800">
              {if @stats.max_weight_kg, do: "#{@stats.max_weight_kg} kg", else: "—"}
            </p>
          </div>
          <div class="bg-white rounded-2xl shadow-lg p-5 text-center">
            <p class="text-sm text-gray-500">Max Reps</p>
            <p class="text-2xl font-bold text-gray-800">
              {if @stats.max_reps, do: @stats.max_reps, else: "—"}
            </p>
          </div>
          <div class="bg-white rounded-2xl shadow-lg p-5 text-center">
            <p class="text-sm text-gray-500">Total Volume</p>
            <p class="text-2xl font-bold text-gray-800">
              {if Decimal.equal?(@stats.total_volume, 0), do: "—", else: "#{@stats.total_volume} kg"}
            </p>
          </div>
          <div class="bg-white rounded-2xl shadow-lg p-5 text-center">
            <p class="text-sm text-gray-500">Total Sessions</p>
            <p class="text-2xl font-bold text-gray-800">{@stats.total_sessions}</p>
          </div>
        </div>
        
    <!-- Chart -->
        <%= if length(@history) > 1 do %>
          <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
            <h2 class="text-lg font-bold text-gray-800 mb-4">Progress Chart</h2>
            <div id="progress-chart" phx-hook="ProgressChart" data-chart={@chart_data}>
              <canvas id="progress-canvas"></canvas>
            </div>
          </div>
        <% end %>
        
    <!-- History Table -->
        <div class="bg-white rounded-2xl shadow-lg overflow-hidden">
          <div class="p-6 border-b border-gray-100">
            <h2 class="text-lg font-bold text-gray-800">Exercise History</h2>
          </div>

          <%= if @history == [] do %>
            <div class="p-8 text-center text-gray-500">No history found for this exercise.</div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Sets</th>
                    <th>Reps</th>
                    <th>Weight (kg)</th>
                    <th>Duration</th>
                    <th>Notes</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for log <- @history do %>
                    <tr class={if is_pr?(log, @prs), do: "bg-yellow-50"}>
                      <td>{Calendar.strftime(log.inserted_at, "%b %d, %Y")}</td>
                      <td>{log.sets || "—"}</td>
                      <td>{log.reps || "—"}</td>
                      <td>{if log.weight_kg, do: "#{log.weight_kg}", else: "—"}</td>
                      <td>
                        {if log.duration_seconds, do: format_duration(log.duration_seconds), else: "—"}
                      </td>
                      <td class="max-w-xs truncate">{log.notes || "—"}</td>
                      <td>
                        <%= if is_pr?(log, @prs) do %>
                          <span title="Personal Record">🏆</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}m #{secs}s"
  end

  defp format_duration(_), do: "—"
end
