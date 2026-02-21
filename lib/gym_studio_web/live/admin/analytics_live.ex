defmodule GymStudioWeb.Admin.AnalyticsLive do
  use GymStudioWeb, :live_view

  alias GymStudio.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    status_counts = Scheduling.count_sessions_by_status()
    weekly_sessions = Scheduling.sessions_per_week(4)
    popular_slots = Scheduling.popular_time_slots()
    trainer_counts = Scheduling.trainer_session_counts()

    total_sessions = status_counts |> Map.values() |> Enum.sum()

    {:ok,
     assign(socket,
       page_title: "Analytics",
       status_counts: status_counts,
       total_sessions: total_sessions,
       weekly_sessions: weekly_sessions,
       popular_slots: popular_slots,
       trainer_counts: trainer_counts
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Analytics</h1>

      <%!-- Sessions by Status --%>
      <h2 class="text-xl font-semibold mb-4">Sessions by Status</h2>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">Total</div>
          <div class="stat-value text-lg">{@total_sessions}</div>
        </div>
        <div :for={{status, color} <- status_colors()} class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">{String.capitalize(status)}</div>
          <div class={"stat-value text-lg #{color}"}>{Map.get(@status_counts, status, 0)}</div>
        </div>
      </div>

      <%!-- Sessions Per Week --%>
      <h2 class="text-xl font-semibold mb-4">Sessions Per Week (Last 4 Weeks)</h2>
      <div class="overflow-x-auto mb-8">
        <table class="table">
          <thead>
            <tr>
              <th>Week</th>
              <th>Sessions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{week_start, week_end, count} <- @weekly_sessions}>
              <td>
                {Calendar.strftime(week_start, "%b %d")} – {Calendar.strftime(week_end, "%b %d")}
              </td>
              <td>
                <div class="flex items-center gap-2">
                  <progress
                    class="progress progress-primary w-32"
                    value={count}
                    max={max_weekly(@weekly_sessions)}
                  >
                  </progress>
                  <span class="font-semibold">{count}</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- Popular Time Slots --%>
      <h2 class="text-xl font-semibold mb-4">Popular Time Slots</h2>
      <div class="overflow-x-auto mb-8">
        <table class="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Sessions Booked</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{hour, count} <- @popular_slots}>
              <td>{format_hour(hour)}</td>
              <td>
                <div class="flex items-center gap-2">
                  <progress
                    class="progress progress-secondary w-32"
                    value={count}
                    max={max_slot_count(@popular_slots)}
                  >
                  </progress>
                  <span class="font-semibold">{count}</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p :if={@popular_slots == []} class="text-base-content/60 mb-8">
        No session data available yet.
      </p>

      <%!-- Trainer Session Counts --%>
      <h2 class="text-xl font-semibold mb-4">Trainer Session Counts</h2>
      <div class="overflow-x-auto mb-8">
        <table class="table">
          <thead>
            <tr>
              <th>Trainer</th>
              <th>Sessions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{name, count} <- @trainer_counts}>
              <td>{name}</td>
              <td class="font-semibold">{count}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p :if={@trainer_counts == []} class="text-base-content/60 mb-8">
        No trainer session data yet.
      </p>

      <%!-- Revenue Placeholder --%>
      <div class="alert alert-info">
        <span>💰 Revenue tracking coming soon...</span>
      </div>
    </div>
    """
  end

  defp status_colors do
    [
      {"pending", "text-warning"},
      {"confirmed", "text-info"},
      {"completed", "text-success"},
      {"cancelled", "text-error"},
      {"no_show", "text-base-content/50"}
    ]
  end

  defp format_hour(hour) do
    cond do
      hour == 0 -> "12:00 AM"
      hour < 12 -> "#{hour}:00 AM"
      hour == 12 -> "12:00 PM"
      true -> "#{hour - 12}:00 PM"
    end
  end

  defp max_weekly(weeks) do
    weeks |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 1 end)
  end

  defp max_slot_count(slots) do
    slots |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
  end
end
