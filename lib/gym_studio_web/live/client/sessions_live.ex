defmodule GymStudioWeb.Client.SessionsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = Accounts.get_client_by_user_id(user.id)

    sessions = Scheduling.list_sessions_for_client(user.id)

    socket =
      socket
      |> assign(page_title: "My Sessions")
      |> assign(client: client)
      |> assign(user: user)
      |> assign(sessions: sessions)
      |> assign(filter: "all")

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    user = socket.assigns.user

    sessions =
      case status do
        "all" -> Scheduling.list_sessions_for_client(user.id)
        _ -> Scheduling.list_sessions_for_client(user.id, status: status)
      end

    {:noreply, assign(socket, sessions: sessions, filter: status)}
  end

  @impl true
  def handle_event("cancel_session", %{"session_id" => session_id}, socket) do
    case Scheduling.cancel_session(session_id) do
      {:ok, _session} ->
        user = socket.assigns.user
        sessions = Scheduling.list_sessions_for_client(user.id)

        socket =
          socket
          |> put_flash(:info, "Session cancelled successfully.")
          |> assign(sessions: sessions)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel session.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">My Sessions</h1>
        <.link navigate={~p"/client/book"} class="btn btn-primary">Book New Session</.link>
      </div>
      
    <!-- Filters -->
      <div class="tabs tabs-boxed mb-6 w-fit">
        <button
          phx-click="filter"
          phx-value-status="all"
          class={"tab #{if @filter == "all", do: "tab-active"}"}
        >
          All
        </button>
        <button
          phx-click="filter"
          phx-value-status="pending"
          class={"tab #{if @filter == "pending", do: "tab-active"}"}
        >
          Pending
        </button>
        <button
          phx-click="filter"
          phx-value-status="confirmed"
          class={"tab #{if @filter == "confirmed", do: "tab-active"}"}
        >
          Confirmed
        </button>
        <button
          phx-click="filter"
          phx-value-status="completed"
          class={"tab #{if @filter == "completed", do: "tab-active"}"}
        >
          Completed
        </button>
        <button
          phx-click="filter"
          phx-value-status="cancelled"
          class={"tab #{if @filter == "cancelled", do: "tab-active"}"}
        >
          Cancelled
        </button>
      </div>

      <%= if Enum.empty?(@sessions) do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body text-center">
            <p class="text-base-content/70">No sessions found.</p>
            <.link navigate={~p"/client/book"} class="btn btn-primary btn-sm w-fit mx-auto">
              Book your first session
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table bg-base-100">
            <thead>
              <tr>
                <th>Date & Time</th>
                <th>Trainer</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for session <- @sessions do %>
                <tr>
                  <td>
                    <div class="font-medium">
                      {Calendar.strftime(session.scheduled_at, "%B %d, %Y")}
                    </div>
                    <div class="text-sm text-base-content/70">
                      {Calendar.strftime(session.scheduled_at, "%H:%M")}
                    </div>
                  </td>
                  <td>{if session.trainer, do: session.trainer.email, else: "TBD"}</td>
                  <td>
                    <span class={"badge #{status_badge_class(session.status)}"}>
                      {session.status}
                    </span>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/client/sessions/#{session.id}"}
                        class="btn btn-ghost btn-xs"
                      >
                        View
                      </.link>
                      <%= if session.status in ["pending", "confirmed"] do %>
                        <button
                          phx-click="cancel_session"
                          phx-value-session_id={session.id}
                          data-confirm="Are you sure you want to cancel this session?"
                          class="btn btn-error btn-xs"
                        >
                          Cancel
                        </button>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-info"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
