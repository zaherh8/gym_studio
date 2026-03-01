defmodule GymStudioWeb.Trainer.SessionsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)

    socket =
      socket
      |> assign(page_title: "My Sessions")
      |> assign(trainer: trainer)
      |> assign(filter: "all")
      |> assign(show_cancel_modal: false, cancel_session_id: nil, cancel_reason: "")
      |> assign(show_complete_modal: false, complete_session_id: nil, trainer_notes: "")
      |> load_sessions()

    {:ok, socket}
  end

  defp load_sessions(%{assigns: %{trainer: nil}} = socket), do: assign(socket, sessions: [])

  defp load_sessions(%{assigns: %{trainer: trainer, filter: filter}} = socket) do
    sessions =
      case filter do
        "all" -> Scheduling.list_sessions_for_trainer(trainer.user_id)
        status -> Scheduling.list_sessions_for_trainer(trainer.user_id, status: status)
      end

    assign(socket, sessions: sessions)
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(filter: status)
      |> load_sessions()

    {:noreply, socket}
  end

  def handle_event("confirm_session", %{"session_id" => session_id}, socket) do
    case Scheduling.confirm_session(session_id) do
      {:ok, _session} ->
        {:noreply, socket |> load_sessions() |> put_flash(:info, "Session confirmed.")}

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

  def handle_event("cancel_session", params, socket) do
    user = socket.assigns.current_scope.user
    session_id = socket.assigns.cancel_session_id

    reason =
      case Map.get(params, "cancellation_reason", "") do
        "" -> "Cancelled by trainer"
        r -> r
      end

    case Scheduling.cancel_session_by_id(session_id, user.id, reason) do
      {:ok, _session} ->
        socket =
          socket
          |> assign(show_cancel_modal: false, cancel_session_id: nil, cancel_reason: "")
          |> load_sessions()
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

  def handle_event("complete_session", params, socket) do
    session_id = socket.assigns.complete_session_id
    notes = Map.get(params, "trainer_notes", "")
    attrs = if notes != "", do: %{trainer_notes: notes}, else: %{}

    case Scheduling.complete_session_by_id(session_id, attrs) do
      {:ok, _session} ->
        socket =
          socket
          |> assign(show_complete_modal: false, complete_session_id: nil, trainer_notes: "")
          |> load_sessions()
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
            <div class="card-body text-center py-12">
              <p class="text-base-content/50 text-lg">No sessions found.</p>
              <p class="text-base-content/40 text-sm">
                <%= if @filter != "all" do %>
                  Try changing the filter above.
                <% else %>
                  Sessions will appear here once clients book with you.
                <% end %>
              </p>
            </div>
          </div>
        <% else %>
          <!-- Mobile: Cards view -->
          <div class="space-y-4 lg:hidden">
            <%= for session <- @sessions do %>
              <div class="card bg-base-100 shadow-md">
                <div class="card-body p-4">
                  <div class="flex justify-between items-start">
                    <div>
                      <p class="font-semibold text-lg">{display_name(session.client)}</p>
                      <p class="text-sm text-base-content/70">
                        {session.client.email}
                      </p>
                    </div>
                    <span class={"badge #{status_badge_class(session.status)}"}>
                      {session.status}
                    </span>
                  </div>
                  <div class="mt-2 text-sm text-base-content/70">
                    <p>
                      📅 {Calendar.strftime(session.scheduled_at, "%B %d, %Y")} at {Calendar.strftime(
                        session.scheduled_at,
                        "%H:%M"
                      )}
                    </p>
                    <p>⏱ {session.duration_minutes} minutes</p>
                    <%= if session.notes do %>
                      <p class="mt-1 italic">📝 {session.notes}</p>
                    <% end %>
                    <%= if session.trainer_notes do %>
                      <p class="mt-1">🗒 {session.trainer_notes}</p>
                    <% end %>
                  </div>
                  <div class="card-actions justify-end mt-3">
                    {render_session_actions(assigns, session)}
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Desktop: Table view -->
          <div class="hidden lg:block overflow-x-auto">
            <table class="table bg-base-100">
              <thead>
                <tr>
                  <th>Date & Time</th>
                  <th>Client</th>
                  <th>Duration</th>
                  <th>Status</th>
                  <th>Notes</th>
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
                    <td>
                      <div class="font-medium">{display_name(session.client)}</div>
                      <div class="text-sm text-base-content/70">
                        {session.client.email}
                      </div>
                    </td>
                    <td>{session.duration_minutes} min</td>
                    <td>
                      <span class={"badge #{status_badge_class(session.status)}"}>
                        {session.status}
                      </span>
                    </td>
                    <td class="max-w-xs">
                      <%= if session.notes do %>
                        <p class="text-sm truncate" title={session.notes}>{session.notes}</p>
                      <% end %>
                      <%= if session.trainer_notes do %>
                        <p class="text-xs text-base-content/50 truncate" title={session.trainer_notes}>
                          Notes: {session.trainer_notes}
                        </p>
                      <% end %>
                    </td>
                    <td>
                      <div class="flex gap-2">
                        {render_session_actions(assigns, session)}
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
        
    <!-- Cancel Modal -->
        <%= if @show_cancel_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="font-bold text-lg">Cancel Session</h3>
              <p class="py-2 text-base-content/70">Please provide a reason for cancellation:</p>
              <form phx-submit="cancel_session">
                <textarea
                  class="textarea textarea-bordered w-full"
                  placeholder="Reason for cancellation..."
                  name="cancellation_reason"
                >{@cancel_reason}</textarea>
                <div class="modal-action">
                  <button type="button" phx-click="close_cancel_modal" class="btn">Nevermind</button>
                  <button type="submit" class="btn btn-error">Cancel Session</button>
                </div>
              </form>
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
              <form phx-submit="complete_session">
                <textarea
                  class="textarea textarea-bordered w-full"
                  placeholder="Session notes (optional)..."
                  name="trainer_notes"
                >{@trainer_notes}</textarea>
                <div class="modal-action">
                  <button type="button" phx-click="close_complete_modal" class="btn">Cancel</button>
                  <button type="submit" class="btn btn-info">
                    Mark as Completed
                  </button>
                </div>
              </form>
            </div>
            <div class="modal-backdrop" phx-click="close_complete_modal"></div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_session_actions(assigns, session) do
    assigns = assign(assigns, :session, session)

    ~H"""
    <%= if @session.status == "pending" do %>
      <button
        phx-click="confirm_session"
        phx-value-session_id={@session.id}
        class="btn btn-success btn-xs"
      >
        Confirm
      </button>
      <button
        phx-click="open_cancel_modal"
        phx-value-session_id={@session.id}
        class="btn btn-error btn-xs btn-outline"
      >
        Cancel
      </button>
    <% end %>
    <%= if @session.status == "confirmed" do %>
      <.link navigate={~p"/trainer/sessions/#{@session.id}/log"} class="btn btn-accent btn-xs">
        Log Exercises
      </.link>
      <button
        phx-click="open_complete_modal"
        phx-value-session_id={@session.id}
        class="btn btn-info btn-xs"
      >
        Complete
      </button>
      <button
        phx-click="open_cancel_modal"
        phx-value-session_id={@session.id}
        class="btn btn-error btn-xs btn-outline"
      >
        Cancel
      </button>
    <% end %>
    <%= if @session.status == "completed" do %>
      <.link navigate={~p"/trainer/sessions/#{@session.id}/log"} class="btn btn-accent btn-xs">
        Log Exercises
      </.link>
    <% end %>
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
