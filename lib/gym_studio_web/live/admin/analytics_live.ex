defmodule GymStudioWeb.Admin.AnalyticsLive do
  @moduledoc """
  Admin analytics page with branch filtering support.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Branches, Scheduling}
  alias GymStudioWeb.Admin.BranchSelectorComponent

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches(active: true)
    selected_branch_id = "all"

    socket =
      socket
      |> assign(:branches, branches)
      |> assign(:selected_branch_id, selected_branch_id)
      |> load_analytics_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_branch", %{"branch_id" => branch_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_branch_id, branch_id)
     |> load_analytics_data()}
  end

  defp load_analytics_data(socket) do
    branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)

    status_counts = Scheduling.count_sessions_by_status(branch_id: branch_id)
    weekly_sessions = Scheduling.sessions_per_week(4, branch_id: branch_id)
    popular_slots = Scheduling.popular_time_slots(branch_id: branch_id)
    trainer_counts = Scheduling.trainer_session_counts(branch_id: branch_id)

    total_sessions = status_counts |> Map.values() |> Enum.sum()

    # Pre-compute per-branch stats when showing all branches
    per_branch_stats =
      if is_nil(branch_id) do
        socket.assigns.branches
        |> Enum.map(fn b ->
          {b.id,
           %{
             sessions_this_week: Scheduling.count_all_sessions_this_week(branch_id: b.id),
             client_count: Map.get(Accounts.count_users_by_role(branch_id: b.id), :client, 0)
           }}
        end)
        |> Map.new()
      else
        %{}
      end

    assign(socket,
      page_title: "Analytics",
      status_counts: status_counts,
      total_sessions: total_sessions,
      weekly_sessions: weekly_sessions,
      popular_slots: popular_slots,
      trainer_counts: trainer_counts,
      per_branch_stats: per_branch_stats
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
        <h1 class="text-3xl font-bold">Analytics</h1>
        <BranchSelectorComponent.branch_selector
          branches={@branches}
          selected_branch_id={@selected_branch_id}
        />
      </div>

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

      <%!-- Per-branch stats (shown when "All Branches" is selected) --%>
      <div :if={@selected_branch_id == "all" && @branches != []}>
        <h2 class="text-xl font-semibold mb-4">Per-Branch Stats</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
          <div :for={%{id: bid, name: bname} <- @branches} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-base">{bname}</h3>
              <div class="stats stats-vertical shadow">
                <div class="stat">
                  <div class="stat-title">Sessions This Week</div>
                  <div class="stat-value text-primary">
                    {Map.get(@per_branch_stats, bid, %{}) |> Map.get(:sessions_this_week, 0)}
                  </div>
                </div>
                <div class="stat">
                  <div class="stat-title">Active Clients</div>
                  <div class="stat-value text-secondary">
                    {Map.get(@per_branch_stats, bid, %{}) |> Map.get(:client_count, 0)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

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
