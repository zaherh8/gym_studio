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
      |> assign(show_cancel_modal: false, cancel_session_id: nil, cancel_reason: "")
      |> assign(show_complete_modal: false, complete_session_id: nil, trainer_notes: "")
      |> assign_dashboard_data(trainer)

    {:ok, socket}
  end

  defp assign_dashboard_data(socket, nil) do
    socket
    |> assign(todays_sessions: [])
    |> assign(pending_sessions: [])
    |> assign(upcoming_sessions: [])
    |> assign(stats: %{total_clients: 0, sessions_this_week: 0, pending_count: 0})
  end

  defp assign_dashboard_data(socket, trainer) do
    today = Date.utc_today()

    todays_sessions =
      Scheduling.list_sessions_for_trainer(trainer.user_id, from_date: today, to_date: today)

    pending_sessions = Scheduling.list_pending_sessions_for_trainer(trainer.user_id)

    # Upcoming 7 days (excluding today)
    tomorrow = Date.add(today, 1)
    week_end = Date.add(today, 7)

    upcoming_sessions =
      Scheduling.list_sessions_for_trainer(trainer.user_id,
        from_date: tomorrow,
        to_date: week_end
      )
      |> Enum.filter(&(&1.status in ["pending", "confirmed"]))
      |> Enum.sort_by(& &1.scheduled_at, DateTime)

    stats = %{
      total_clients: Scheduling.count_unique_clients_for_trainer(trainer.user_id),
      sessions_this_week: Scheduling.count_sessions_this_week(trainer.user_id),
      pending_count: length(pending_sessions)
    }

    socket
    |> assign(todays_sessions: todays_sessions)
    |> assign(pending_sessions: pending_sessions)
    |> assign(upcoming_sessions: upcoming_sessions)
    |> assign(stats: stats)
  end

  @impl true
  def handle_event("confirm_session", %{"session_id" => session_id}, socket) do
    case Scheduling.confirm_session(session_id) do
      {:ok, _session} ->
        socket = assign_dashboard_data(socket, socket.assigns.trainer)
        {:noreply, put_flash(socket, :info, "Session confirmed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not confirm session.")}
    end
  end

  def handle_event("open_cancel_modal", %{"session_id" => session_id}, socket) do
    {:noreply,
     assign(socket, show_cancel_modal: true, cancel_session_id: session_id, cancel_reason: "")}
  end

  def handle_event("close_cancel_modal", _params, socket) do
    {:noreply,
     assign(socket, show_cancel_modal: false, cancel_session_id: nil, cancel_reason: "")}
  end

  def handle_event("update_cancel_reason", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, cancel_reason: reason)}
  end

  def handle_event("cancel_session", _params, socket) do
    user = socket.assigns.current_scope.user
    session_id = socket.assigns.cancel_session_id
    reason = socket.assigns.cancel_reason

    reason = if reason == "", do: "Cancelled by trainer", else: reason

    case Scheduling.cancel_session_by_id(session_id, user.id, reason) do
      {:ok, _session} ->
        socket =
          socket
          |> assign(show_cancel_modal: false, cancel_session_id: nil, cancel_reason: "")
          |> assign_dashboard_data(socket.assigns.trainer)
          |> put_flash(:info, "Session cancelled.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel session.")}
    end
  end

  def handle_event("open_complete_modal", %{"session_id" => session_id}, socket) do
    {:noreply,
     assign(socket, show_complete_modal: true, complete_session_id: session_id, trainer_notes: "")}
  end

  def handle_event("close_complete_modal", _params, socket) do
    {:noreply,
     assign(socket, show_complete_modal: false, complete_session_id: nil, trainer_notes: "")}
  end

  def handle_event("update_trainer_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, trainer_notes: notes)}
  end

  def handle_event("complete_session", _params, socket) do
    session_id = socket.assigns.complete_session_id
    notes = socket.assigns.trainer_notes

    attrs = if notes != "", do: %{trainer_notes: notes}, else: %{}

    case Scheduling.complete_session_by_id(session_id, attrs) do
      {:ok, _session} ->
        socket =
          socket
          |> assign(show_complete_modal: false, complete_session_id: nil, trainer_notes: "")
          |> assign_dashboard_data(socket.assigns.trainer)
          |> put_flash(:info, "Session marked as completed.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not complete session.")}
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
            <span>
              Your trainer account is currently {@trainer.status}. You'll be notified when approved.
            </span>
          </div>
        <% end %>
        
    <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Total Clients</div>
                <div class="stat-value text-primary">{@stats.total_clients}</div>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Sessions This Week</div>
                <div class="stat-value text-primary">{@stats.sessions_this_week}</div>
              </div>
            </div>
          </div>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <div class="stat p-0">
                <div class="stat-title">Pending Requests</div>
                <div class="stat-value text-warning">{@stats.pending_count}</div>
              </div>
            </div>
          </div>
        </div>

        <div class="flex gap-3 mb-8">
          <.link navigate={~p"/trainer/clients"} class="btn btn-primary btn-sm">
            👥 My Clients
          </.link>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <!-- Today's Sessions -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                Today's Sessions <span class="badge badge-neutral">{length(@todays_sessions)}</span>
              </h2>
              <%= if Enum.empty?(@todays_sessions) do %>
                <div class="text-center py-6">
                  <p class="text-base-content/50">No sessions scheduled for today.</p>
                </div>
              <% else %>
                <div class="space-y-3">
                  <%= for session <- @todays_sessions do %>
                    <div class="card bg-base-200">
                      <div class="card-body p-4">
                        <div class="flex justify-between items-start">
                          <div>
                            <p class="font-semibold">{display_name(session.client)}</p>
                            <p class="text-sm text-base-content/70">
                              {Calendar.strftime(session.scheduled_at, "%H:%M")} · {session.duration_minutes} min
                            </p>
                            <%= if session.notes do %>
                              <p class="text-xs text-base-content/50 mt-1 italic">
                                "{session.notes}"
                              </p>
                            <% end %>
                          </div>
                          <div class="flex items-center gap-2">
                            <span class={"badge #{status_badge_class(session.status)}"}>
                              {session.status}
                            </span>
                          </div>
                        </div>
                        <div class="card-actions justify-end mt-2">
                          <%= if session.status == "pending" do %>
                            <button
                              phx-click="confirm_session"
                              phx-value-session_id={session.id}
                              class="btn btn-success btn-xs"
                            >
                              Confirm
                            </button>
                            <button
                              phx-click="open_cancel_modal"
                              phx-value-session_id={session.id}
                              class="btn btn-error btn-xs btn-outline"
                            >
                              Cancel
                            </button>
                          <% end %>
                          <%= if session.status == "confirmed" do %>
                            <button
                              phx-click="open_complete_modal"
                              phx-value-session_id={session.id}
                              class="btn btn-info btn-xs"
                            >
                              Complete
                            </button>
                            <button
                              phx-click="open_cancel_modal"
                              phx-value-session_id={session.id}
                              class="btn btn-error btn-xs btn-outline"
                            >
                              Cancel
                            </button>
                          <% end %>
                        </div>
                      </div>
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
              <h2 class="card-title">
                Pending Session Requests
                <%= if @stats.pending_count > 0 do %>
                  <span class="badge badge-warning">{@stats.pending_count} need action</span>
                <% end %>
              </h2>
              <%= if Enum.empty?(@pending_sessions) do %>
                <div class="text-center py-6">
                  <p class="text-base-content/50">No pending session requests.</p>
                </div>
              <% else %>
                <div class="space-y-3">
                  <%= for session <- @pending_sessions do %>
                    <div class="card bg-base-200">
                      <div class="card-body p-4">
                        <div class="flex justify-between items-start">
                          <div>
                            <p class="font-semibold">{display_name(session.client)}</p>
                            <p class="text-sm text-base-content/70">
                              {Calendar.strftime(session.scheduled_at, "%b %d at %H:%M")}
                            </p>
                            <%= if session.notes do %>
                              <p class="text-xs text-base-content/50 mt-1 italic">
                                "{session.notes}"
                              </p>
                            <% end %>
                          </div>
                        </div>
                        <div class="card-actions justify-end mt-2">
                          <button
                            phx-click="confirm_session"
                            phx-value-session_id={session.id}
                            class="btn btn-success btn-xs"
                          >
                            Confirm
                          </button>
                          <button
                            phx-click="open_cancel_modal"
                            phx-value-session_id={session.id}
                            class="btn btn-error btn-xs btn-outline"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
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
        
    <!-- Upcoming Sessions (Next 7 Days) -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Upcoming Sessions (Next 7 Days)</h2>
            <%= if Enum.empty?(@upcoming_sessions) do %>
              <div class="text-center py-6">
                <p class="text-base-content/50">No upcoming sessions in the next 7 days.</p>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>Date & Time</th>
                      <th>Client</th>
                      <th>Status</th>
                      <th>Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for session <- @upcoming_sessions do %>
                      <tr>
                        <td>
                          <div class="font-medium">
                            {Calendar.strftime(session.scheduled_at, "%a, %b %d")}
                          </div>
                          <div class="text-sm text-base-content/70">
                            {Calendar.strftime(session.scheduled_at, "%H:%M")}
                          </div>
                        </td>
                        <td class="font-medium">{display_name(session.client)}</td>
                        <td>
                          <span class={"badge #{status_badge_class(session.status)}"}>
                            {session.status}
                          </span>
                        </td>
                        <td class="text-sm text-base-content/70 max-w-xs truncate">
                          {session.notes || "—"}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Cancel Modal -->
        <%= if @show_cancel_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="font-bold text-lg">Cancel Session</h3>
              <p class="py-2 text-base-content/70">Please provide a reason for cancellation:</p>
              <textarea
                class="textarea textarea-bordered w-full"
                placeholder="Reason for cancellation..."
                phx-keyup="update_cancel_reason"
                phx-value-reason={@cancel_reason}
              >{@cancel_reason}</textarea>
              <div class="modal-action">
                <button phx-click="close_cancel_modal" class="btn">Nevermind</button>
                <button phx-click="cancel_session" class="btn btn-error">Cancel Session</button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close_cancel_modal"></div>
          </div>
        <% end %>
        
    <!-- Complete Modal -->
        <%= if @show_complete_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="font-bold text-lg">Complete Session</h3>
              <p class="py-2 text-base-content/70">Add optional notes about the session:</p>
              <textarea
                class="textarea textarea-bordered w-full"
                placeholder="Session notes (optional)..."
                phx-keyup="update_trainer_notes"
                phx-value-notes={@trainer_notes}
              >{@trainer_notes}</textarea>
              <div class="modal-action">
                <button phx-click="close_complete_modal" class="btn">Cancel</button>
                <button phx-click="complete_session" class="btn btn-info">
                  Mark as Completed
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close_complete_modal"></div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unknown"

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-info"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
