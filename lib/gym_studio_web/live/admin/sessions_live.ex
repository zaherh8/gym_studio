defmodule GymStudioWeb.Admin.SessionsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Scheduling, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    trainers = Accounts.list_approved_trainers()

    {:ok,
     assign(socket,
       page_title: "Manage Sessions",
       sessions: Scheduling.list_all_sessions(),
       trainers: trainers,
       status_filter: "",
       trainer_filter: "",
       editing_session_id: nil,
       assigning_session_id: nil,
       available_trainers_for_assign: []
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    status = params["status"] || ""
    trainer = params["trainer"] || ""

    opts =
      []
      |> then(fn o -> if status != "", do: [{:status, status} | o], else: o end)
      |> then(fn o -> if trainer != "", do: [{:trainer_id, trainer} | o], else: o end)

    sessions = Scheduling.list_all_sessions(opts)

    {:noreply, assign(socket, sessions: sessions, status_filter: status, trainer_filter: trainer)}
  end

  def handle_event("set_status", %{"id" => id, "status" => new_status}, socket) do
    session = Scheduling.get_session!(id)
    {:ok, _} = Scheduling.admin_update_session(session, %{status: new_status})
    {:noreply, reload_sessions(socket)}
  end

  def handle_event("show_assign", %{"id" => session_id}, socket) do
    session = Scheduling.get_session!(session_id)
    date = DateTime.to_date(session.scheduled_at)
    hour = DateTime.to_time(session.scheduled_at).hour

    available =
      Scheduling.get_all_available_slots(date)
      |> Enum.filter(fn slot -> slot.hour == hour end)
      |> Enum.uniq_by(& &1.trainer_id)

    {:noreply,
     assign(socket,
       assigning_session_id: session_id,
       available_trainers_for_assign: available
     )}
  end

  def handle_event("cancel_assign", _params, socket) do
    {:noreply, assign(socket, assigning_session_id: nil, available_trainers_for_assign: [])}
  end

  def handle_event("assign_trainer", %{"id" => id, "trainer_id" => trainer_id}, socket) do
    session = Scheduling.get_session!(id)
    attrs = %{trainer_id: trainer_id}

    attrs =
      if session.status == "pending",
        do: Map.put(attrs, :status, "confirmed"),
        else: attrs

    {:ok, _} = Scheduling.admin_update_session(session, attrs)

    {:noreply,
     socket
     |> assign(assigning_session_id: nil, available_trainers_for_assign: [])
     |> reload_sessions()
     |> put_flash(:info, "Trainer assigned successfully")}
  end

  defp reload_sessions(socket) do
    opts =
      []
      |> then(fn o ->
        if socket.assigns.status_filter != "",
          do: [{:status, socket.assigns.status_filter} | o],
          else: o
      end)
      |> then(fn o ->
        if socket.assigns.trainer_filter != "",
          do: [{:trainer_id, socket.assigns.trainer_filter} | o],
          else: o
      end)

    assign(socket, sessions: Scheduling.list_all_sessions(opts))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Sessions</h1>

      <%!-- Filters --%>
      <form phx-change="filter" class="flex flex-col sm:flex-row gap-4 mb-6">
        <select name="status" class="select select-bordered">
          <option value="">All Statuses</option>
          <option value="pending" selected={@status_filter == "pending"}>Pending</option>
          <option value="confirmed" selected={@status_filter == "confirmed"}>Confirmed</option>
          <option value="completed" selected={@status_filter == "completed"}>Completed</option>
          <option value="cancelled" selected={@status_filter == "cancelled"}>Cancelled</option>
          <option value="no_show" selected={@status_filter == "no_show"}>No Show</option>
        </select>
        <select name="trainer" class="select select-bordered">
          <option value="">All Trainers</option>
          <%= for trainer <- @trainers do %>
            <option value={trainer.user.id} selected={@trainer_filter == trainer.user.id}>
              {trainer.user.name || trainer.user.email}
            </option>
          <% end %>
        </select>
      </form>

      <%!-- Sessions Table --%>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Client</th>
              <th>Trainer</th>
              <th>Date/Time</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={session <- @sessions} class="hover">
              <td>{session.client.name || session.client.email || session.client.phone_number}</td>
              <td>
                <%= if session.trainer do %>
                  {session.trainer.name || session.trainer.email}
                <% else %>
                  <span class="text-base-content/40">Unassigned</span>
                <% end %>
              </td>
              <td>{Calendar.strftime(session.scheduled_at, "%Y-%m-%d %H:%M")}</td>
              <td>
                <span class={"badge #{status_badge_class(session.status)}"}>{session.status}</span>
              </td>
              <td>
                <div class="flex gap-2 flex-wrap">
                  <%!-- Status Override --%>
                  <div class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-xs btn-ghost">Status ▾</div>
                    <ul
                      tabindex="0"
                      class="dropdown-content z-[1] menu p-2 shadow bg-base-200 rounded-box w-36"
                    >
                      <li :for={status <- ~w(pending confirmed completed cancelled no_show)}>
                        <button
                          :if={status != session.status}
                          phx-click="set_status"
                          phx-value-id={session.id}
                          phx-value-status={status}
                        >
                          {status}
                        </button>
                      </li>
                    </ul>
                  </div>
                  <%!-- Trainer Assignment --%>
                  <%= if is_nil(session.trainer_id) do %>
                    <button
                      phx-click="show_assign"
                      phx-value-id={session.id}
                      class="btn btn-xs btn-primary"
                    >
                      Assign Trainer
                    </button>
                  <% else %>
                    <div class="dropdown dropdown-end">
                      <div tabindex="0" role="button" class="btn btn-xs btn-ghost">
                        Reassign ▾
                      </div>
                      <ul
                        tabindex="0"
                        class="dropdown-content z-[1] menu p-2 shadow bg-base-200 rounded-box w-48"
                      >
                        <li :for={trainer <- @trainers}>
                          <button
                            phx-click="assign_trainer"
                            phx-value-id={session.id}
                            phx-value-trainer_id={trainer.user.id}
                          >
                            {trainer.user.name || trainer.user.email}
                          </button>
                        </li>
                      </ul>
                    </div>
                  <% end %>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p :if={@sessions == []} class="text-base-content/60 text-center py-8">No sessions found.</p>

      <%!-- Assign Trainer Modal --%>
      <%= if @assigning_session_id do %>
        <div class="modal modal-open">
          <div class="modal-box" phx-click-away="cancel_assign">
            <button
              phx-click="cancel_assign"
              class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            >
              ✕
            </button>
            <h3 class="font-bold text-lg mb-4">Assign Trainer</h3>
            <%= if @available_trainers_for_assign == [] do %>
              <p class="text-warning">No trainers available for this time slot.</p>
            <% else %>
              <div class="flex flex-col gap-2">
                <%= for trainer <- @available_trainers_for_assign do %>
                  <button
                    phx-click="assign_trainer"
                    phx-value-id={@assigning_session_id}
                    phx-value-trainer_id={trainer.trainer_id}
                    class="btn btn-outline btn-primary justify-start"
                  >
                    {trainer.trainer_name}
                  </button>
                <% end %>
              </div>
            <% end %>
            <div class="modal-action">
              <button phx-click="cancel_assign" class="btn btn-sm">Cancel</button>
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
  defp status_badge_class("no_show"), do: "badge-ghost"
  defp status_badge_class(_), do: "badge-ghost"
end
