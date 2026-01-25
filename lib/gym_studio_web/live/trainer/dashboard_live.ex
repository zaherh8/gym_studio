defmodule GymStudioWeb.Trainer.DashboardLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)

    socket =
      socket
      |> assign(page_title: "Trainer Dashboard")
      |> assign(trainer: trainer)
      |> assign_dashboard_data(trainer)

    {:ok, socket}
  end

  defp assign_dashboard_data(socket, nil) do
    socket
    |> assign(todays_sessions: [])
    |> assign(pending_sessions: [])
    |> assign(stats: %{total_clients: 0, sessions_this_week: 0, pending_count: 0})
  end

  defp assign_dashboard_data(socket, trainer) do
    today = Date.utc_today()
    todays_sessions = Scheduling.list_sessions_for_trainer(trainer.user_id, date: today)
    pending_sessions = Scheduling.list_pending_sessions_for_trainer(trainer.user_id)

    stats = %{
      total_clients: Scheduling.count_unique_clients_for_trainer(trainer.user_id),
      sessions_this_week: Scheduling.count_sessions_this_week(trainer.user_id),
      pending_count: length(pending_sessions)
    }

    socket
    |> assign(todays_sessions: todays_sessions)
    |> assign(pending_sessions: pending_sessions)
    |> assign(stats: stats)
  end

  @impl true
  def handle_event("confirm_session", %{"session_id" => session_id}, socket) do
    case Scheduling.confirm_session(session_id) do
      {:ok, _session} ->
        trainer = socket.assigns.trainer
        socket = assign_dashboard_data(socket, trainer)
        {:noreply, put_flash(socket, :info, "Session confirmed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not confirm session.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Trainer Dashboard</h1>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <%= if @trainer.status != "approved" do %>
          <div class="alert alert-info mb-6">
            <span>Your trainer account is currently <%= @trainer.status %>. You'll be notified when approved.</span>
          </div>
        <% end %>

        <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Total Clients</div>
                <div class="stat-value text-primary"><%= @stats.total_clients %></div>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Sessions This Week</div>
                <div class="stat-value text-primary"><%= @stats.sessions_this_week %></div>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Pending Requests</div>
                <div class="stat-value text-warning"><%= @stats.pending_count %></div>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Today's Sessions -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Today's Sessions</h2>
              <%= if Enum.empty?(@todays_sessions) do %>
                <p class="text-base-content/70">No sessions scheduled for today.</p>
              <% else %>
                <div class="space-y-3">
                  <%= for session <- @todays_sessions do %>
                    <div class="flex justify-between items-center p-3 bg-base-200 rounded-lg">
                      <div>
                        <p class="font-medium"><%= session.client.email %></p>
                        <p class="text-sm text-base-content/70">
                          <%= Calendar.strftime(session.scheduled_at, "%H:%M") %>
                        </p>
                      </div>
                      <span class={"badge #{status_badge_class(session.status)}"}><%= session.status %></span>
                    </div>
                  <% end %>
                </div>
              <% end %>
              <.link navigate={~p"/trainer/schedule"} class="btn btn-outline btn-sm w-fit mt-4">
                View Full Schedule
              </.link>
            </div>
          </div>

          <!-- Pending Requests -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Pending Session Requests</h2>
              <%= if Enum.empty?(@pending_sessions) do %>
                <p class="text-base-content/70">No pending session requests.</p>
              <% else %>
                <div class="space-y-3">
                  <%= for session <- @pending_sessions do %>
                    <div class="flex justify-between items-center p-3 bg-base-200 rounded-lg">
                      <div>
                        <p class="font-medium"><%= session.client.email %></p>
                        <p class="text-sm text-base-content/70">
                          <%= Calendar.strftime(session.scheduled_at, "%b %d at %H:%M") %>
                        </p>
                      </div>
                      <button
                        phx-click="confirm_session"
                        phx-value-session_id={session.id}
                        class="btn btn-primary btn-sm"
                      >
                        Confirm
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
              <.link navigate={~p"/trainer/sessions"} class="btn btn-outline btn-sm w-fit mt-4">
                View All Sessions
              </.link>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-info"
  defp status_badge_class("completed"), do: "badge-success"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
