defmodule GymStudioWeb.Admin.CalendarLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @hours_range 6..21

  # Distinct colors for different trainers
  @trainer_colors [
    {"bg-blue-200 text-blue-900", "bg-blue-500"},
    {"bg-green-200 text-green-900", "bg-green-500"},
    {"bg-purple-200 text-purple-900", "bg-purple-500"},
    {"bg-orange-200 text-orange-900", "bg-orange-500"},
    {"bg-pink-200 text-pink-900", "bg-pink-500"},
    {"bg-teal-200 text-teal-900", "bg-teal-500"},
    {"bg-yellow-200 text-yellow-900", "bg-yellow-500"},
    {"bg-red-200 text-red-900", "bg-red-500"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    trainers = Accounts.list_trainers(status: "approved")

    # Build trainer_id -> color mapping
    color_map =
      trainers
      |> Enum.with_index()
      |> Enum.into(%{}, fn {trainer, idx} ->
        {trainer.user_id, Enum.at(@trainer_colors, rem(idx, length(@trainer_colors)))}
      end)

    socket =
      socket
      |> assign(page_title: "Calendar")
      |> assign(trainers: trainers)
      |> assign(color_map: color_map)
      |> assign(filter_trainer_id: nil)
      |> assign(current_week_start: Date.beginning_of_week(today, :monday))
      |> assign(selected_session: nil)
      |> assign(available_trainers: [])
      |> load_week_data()

    {:ok, socket}
  end

  defp load_week_data(socket) do
    week_start = socket.assigns.current_week_start
    week_end = Date.add(week_start, 6)
    filter = socket.assigns.filter_trainer_id

    opts = [from_date: week_start, to_date: week_end]
    opts = if filter, do: Keyword.put(opts, :trainer_id, filter), else: opts

    sessions = Scheduling.list_all_sessions(opts)

    # Group by date -> hour -> list of sessions
    week_sessions =
      Enum.reduce(sessions, %{}, fn session, acc ->
        date = DateTime.to_date(session.scheduled_at)
        hour = DateTime.to_time(session.scheduled_at).hour

        update_in(acc, [Access.key(date, %{}), Access.key(hour, [])], &[session | &1])
      end)

    # Calculate utilization: booked hours / total available hours
    total_sessions = length(sessions)
    active_sessions = Enum.count(sessions, &(&1.status in ["pending", "confirmed", "completed"]))

    assign(socket,
      week_sessions: week_sessions,
      total_sessions: total_sessions,
      active_sessions: active_sessions
    )
  end

  @impl true
  def handle_event("previous_week", _params, socket) do
    socket =
      socket
      |> assign(current_week_start: Date.add(socket.assigns.current_week_start, -7))
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("next_week", _params, socket) do
    socket =
      socket
      |> assign(current_week_start: Date.add(socket.assigns.current_week_start, 7))
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("today", _params, socket) do
    today = Date.utc_today()

    socket =
      socket
      |> assign(current_week_start: Date.beginning_of_week(today, :monday))
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("filter_trainer", %{"trainer_id" => ""}, socket) do
    socket =
      socket
      |> assign(filter_trainer_id: nil)
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("filter_trainer", %{"trainer_id" => trainer_id}, socket) do
    socket =
      socket
      |> assign(filter_trainer_id: trainer_id)
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("show_session", %{"session-id" => session_id}, socket) do
    session = find_session(socket.assigns.week_sessions, session_id)

    available_trainers =
      if is_nil(session.trainer_id) do
        date = DateTime.to_date(session.scheduled_at)
        hour = DateTime.to_time(session.scheduled_at).hour

        Scheduling.get_all_available_slots(date)
        |> Enum.filter(fn slot -> slot.hour == hour end)
        |> Enum.uniq_by(& &1.trainer_id)
      else
        []
      end

    {:noreply, assign(socket, selected_session: session, available_trainers: available_trainers)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_session: nil, available_trainers: [])}
  end

  def handle_event(
        "assign_trainer",
        %{"session-id" => session_id, "trainer-id" => trainer_id},
        socket
      ) do
    session = Scheduling.get_session!(session_id)
    {:ok, _} = Scheduling.admin_update_session(session, %{trainer_id: trainer_id})

    socket =
      socket
      |> assign(selected_session: nil, available_trainers: [])
      |> load_week_data()

    {:noreply, put_flash(socket, :info, "Trainer assigned successfully")}
  end

  defp find_session(week_sessions, session_id) do
    Enum.find_value(week_sessions, fn {_date, hour_map} ->
      Enum.find_value(hour_map, fn {_hour, sessions} ->
        Enum.find(sessions, &(&1.id == session_id))
      end)
    end)
  end

  defp trainer_color(color_map, trainer_id) do
    case Map.get(color_map, trainer_id) do
      {cell_class, _dot} -> cell_class
      nil -> "bg-base-300 text-base-content"
    end
  end

  defp trainer_dot(color_map, trainer_id) do
    case Map.get(color_map, trainer_id) do
      {_, dot} -> dot
      nil -> "bg-base-300"
    end
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unassigned"

  defp format_hour(0), do: "12 AM"
  defp format_hour(h) when h < 12, do: "#{h} AM"
  defp format_hour(12), do: "12 PM"
  defp format_hour(h), do: "#{h - 12} PM"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :hours_range, @hours_range)

    ~H"""
    <div class="container mx-auto px-2 sm:px-4 py-4 sm:py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
        <h1 class="text-2xl sm:text-3xl font-bold">Gym Calendar</h1>
        <div class="flex items-center gap-3">
          <div class="stats stats-horizontal shadow text-sm">
            <div class="stat py-2 px-4">
              <div class="stat-title text-xs">Sessions</div>
              <div class="stat-value text-lg">{@total_sessions}</div>
            </div>
            <div class="stat py-2 px-4">
              <div class="stat-title text-xs">Active</div>
              <div class="stat-value text-lg">{@active_sessions}</div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Filter + Navigation -->
      <div class="flex flex-col sm:flex-row justify-between items-center gap-4 mb-4">
        <form phx-change="filter_trainer" class="w-full sm:w-auto">
          <select name="trainer_id" class="select select-bordered select-sm w-full sm:w-64">
            <option value="">All Trainers</option>
            <%= for trainer <- @trainers do %>
              <option
                value={trainer.user_id}
                selected={@filter_trainer_id == to_string(trainer.user_id)}
              >
                {trainer.user.name || trainer.user.email}
              </option>
            <% end %>
          </select>
        </form>

        <div class="flex items-center gap-2">
          <button phx-click="previous_week" class="btn btn-ghost btn-sm">← Prev</button>
          <div class="text-center min-w-[200px]">
            <h2 class="text-base font-semibold">
              {Calendar.strftime(@current_week_start, "%b %d")} – {Calendar.strftime(
                Date.add(@current_week_start, 6),
                "%b %d, %Y"
              )}
            </h2>
          </div>
          <button phx-click="next_week" class="btn btn-ghost btn-sm">Next →</button>
          <button phx-click="today" class="btn btn-ghost btn-xs">Today</button>
        </div>
      </div>
      
    <!-- Trainer Color Legend -->
      <div class="flex flex-wrap gap-2 mb-4">
        <%= for trainer <- @trainers do %>
          <div class="flex items-center gap-1.5 text-xs">
            <div class={"w-3 h-3 rounded-full #{trainer_dot(@color_map, trainer.user_id)}"}></div>
            <span>{trainer.user.name || trainer.user.email}</span>
          </div>
        <% end %>
      </div>
      
    <!-- Calendar Grid -->
      <div class="overflow-x-auto">
        <div class="min-w-[700px]">
          <!-- Header -->
          <div class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-base-300">
            <div class="p-2"></div>
            <%= for day_offset <- 0..6 do %>
              <% day = Date.add(@current_week_start, day_offset) %>
              <div class={"text-center p-2 #{if day == Date.utc_today(), do: "bg-primary/10 rounded-t-lg"}"}>
                <div class="text-xs font-medium text-base-content/60">
                  {Calendar.strftime(day, "%a")}
                </div>
                <div class={"text-lg font-bold #{if day == Date.utc_today(), do: "text-primary"}"}>
                  {Calendar.strftime(day, "%d")}
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Hours -->
          <%= for hour <- @hours_range do %>
            <div class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-base-200 min-h-[48px]">
              <div class="text-xs text-base-content/40 p-1 text-right pr-2 pt-1">
                {format_hour(hour)}
              </div>
              <%= for day_offset <- 0..6 do %>
                <% day = Date.add(@current_week_start, day_offset) %>
                <% sessions = get_in(@week_sessions, [day, hour]) || [] %>
                <div class="border-l border-base-200 p-0.5">
                  <%= for session <- sessions do %>
                    <button
                      type="button"
                      phx-click="show_session"
                      phx-value-session-id={session.id}
                      class={"w-full text-left p-1 rounded text-xs cursor-pointer hover:opacity-80 mb-0.5 #{trainer_color(@color_map, session.trainer_id)}"}
                    >
                      <div class="font-semibold truncate">{display_name(session.client)}</div>
                      <div class="truncate opacity-60">
                        {display_name(session.trainer)} · {session.status}
                      </div>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Session Detail Modal -->
      <%= if @selected_session do %>
        <div class="modal modal-open">
          <div class="modal-box" phx-click-away="close_modal">
            <button
              phx-click="close_modal"
              class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            >
              ✕
            </button>
            <h3 class="font-bold text-lg mb-4">Session Details</h3>

            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-base-content/60">Client</span>
                <span class="font-semibold">{display_name(@selected_session.client)}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-base-content/60">Trainer</span>
                <%= if @selected_session.trainer_id do %>
                  <span class="font-semibold">{display_name(@selected_session.trainer)}</span>
                <% else %>
                  <span class="badge badge-warning badge-sm">Unassigned</span>
                <% end %>
              </div>
              <%= if is_nil(@selected_session.trainer_id) and @available_trainers != [] do %>
                <div class="bg-base-200 rounded-lg p-3">
                  <p class="text-sm font-medium mb-2">Assign Trainer</p>
                  <div class="flex flex-col gap-1">
                    <%= for trainer <- @available_trainers do %>
                      <button
                        phx-click="assign_trainer"
                        phx-value-session-id={@selected_session.id}
                        phx-value-trainer-id={trainer.trainer_id}
                        class="btn btn-sm btn-outline btn-primary justify-start"
                      >
                        {trainer.trainer_name}
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if is_nil(@selected_session.trainer_id) and @available_trainers == [] do %>
                <div class="bg-warning/10 rounded-lg p-3">
                  <p class="text-sm text-warning">No trainers available for this time slot.</p>
                </div>
              <% end %>
              <div class="flex justify-between">
                <span class="text-base-content/60">Date</span>
                <span>
                  {Calendar.strftime(DateTime.to_date(@selected_session.scheduled_at), "%A, %b %d %Y")}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-base-content/60">Time</span>
                <span>{format_hour(DateTime.to_time(@selected_session.scheduled_at).hour)}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-base-content/60">Status</span>
                <span class="badge badge-outline">{@selected_session.status}</span>
              </div>
              <%= if @selected_session.notes do %>
                <div>
                  <span class="text-base-content/60 block mb-1">Notes</span>
                  <p class="text-sm bg-base-200 p-2 rounded">{@selected_session.notes}</p>
                </div>
              <% end %>
            </div>

            <div class="modal-action">
              <.link
                navigate={~p"/admin/sessions/#{@selected_session.id}"}
                class="btn btn-primary btn-sm"
              >
                View Full Details
              </.link>
              <button phx-click="close_modal" class="btn btn-sm">Close</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
