defmodule GymStudioWeb.Trainer.SessionsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)

    sessions =
      if trainer do
        Scheduling.list_sessions_for_trainer(trainer.id)
      else
        []
      end

    socket =
      socket
      |> assign(page_title: "My Sessions")
      |> assign(trainer: trainer)
      |> assign(sessions: sessions)
      |> assign(filter: "all")

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    trainer = socket.assigns.trainer

    sessions =
      if trainer do
        case status do
          "all" -> Scheduling.list_sessions_for_trainer(trainer.id)
          _ -> Scheduling.list_sessions_for_trainer(trainer.id, status: status)
        end
      else
        []
      end

    {:noreply, assign(socket, sessions: sessions, filter: status)}
  end

  @impl true
  def handle_event("confirm_session", %{"session_id" => session_id}, socket) do
    case Scheduling.confirm_session(session_id) do
      {:ok, _session} ->
        trainer = socket.assigns.trainer
        sessions = Scheduling.list_sessions_for_trainer(trainer.id)

        socket =
          socket
          |> put_flash(:info, "Session confirmed.")
          |> assign(sessions: sessions)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not confirm session.")}
    end
  end

  @impl true
  def handle_event("complete_session", %{"session_id" => session_id}, socket) do
    case Scheduling.complete_session(session_id) do
      {:ok, _session} ->
        trainer = socket.assigns.trainer
        sessions = Scheduling.list_sessions_for_trainer(trainer.id)

        socket =
          socket
          |> put_flash(:info, "Session marked as completed.")
          |> assign(sessions: sessions)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not complete session.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">My Sessions</h1>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
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
            </div>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table bg-base-100">
              <thead>
                <tr>
                  <th>Date & Time</th>
                  <th>Client</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for session <- @sessions do %>
                  <tr>
                    <td>
                      <div class="font-medium">
                        <%= Calendar.strftime(session.scheduled_at, "%B %d, %Y") %>
                      </div>
                      <div class="text-sm text-base-content/70">
                        <%= Calendar.strftime(session.scheduled_at, "%H:%M") %>
                      </div>
                    </td>
                    <td>
                      <div><%= session.client.user.email %></div>
                      <div class="text-sm text-base-content/70"><%= session.client.user.phone_number %></div>
                    </td>
                    <td>
                      <span class={"badge #{status_badge_class(session.status)}"}><%= session.status %></span>
                    </td>
                    <td>
                      <div class="flex gap-2">
                        <%= if session.status == "pending" do %>
                          <button
                            phx-click="confirm_session"
                            phx-value-session_id={session.id}
                            class="btn btn-primary btn-xs"
                          >
                            Confirm
                          </button>
                        <% end %>
                        <%= if session.status == "confirmed" do %>
                          <button
                            phx-click="complete_session"
                            phx-value-session_id={session.id}
                            class="btn btn-success btn-xs"
                          >
                            Complete
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
