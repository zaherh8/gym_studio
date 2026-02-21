defmodule GymStudioWeb.Trainer.ScheduleLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)
    today = Date.utc_today()

    socket =
      socket
      |> assign(page_title: "My Schedule")
      |> assign(trainer: trainer)
      |> assign(current_week_start: Date.beginning_of_week(today, :monday))
      |> load_week_data()

    {:ok, socket}
  end

  defp load_week_data(%{assigns: %{trainer: nil}} = socket) do
    assign(socket, week_sessions: %{}, time_slots: %{})
  end

  defp load_week_data(%{assigns: %{trainer: trainer, current_week_start: week_start}} = socket) do
    week_end = Date.add(week_start, 6)

    sessions =
      Scheduling.list_sessions_for_trainer(trainer.user_id,
        from_date: week_start,
        to_date: week_end
      )

    week_sessions =
      Enum.group_by(sessions, fn session ->
        DateTime.to_date(session.scheduled_at)
      end)

    # Load time slots grouped by day of week
    all_slots = Scheduling.list_time_slots(active_only: true)
    time_slots = Enum.group_by(all_slots, & &1.day_of_week)

    assign(socket, week_sessions: week_sessions, time_slots: time_slots)
  end

  @impl true
  def handle_event("previous_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, -7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("next_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, 7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    new_week_start = Date.beginning_of_week(today, :monday)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_data()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
        <h1 class="text-3xl font-bold">My Schedule</h1>
        <div class="badge badge-outline badge-lg">
          📋 Read-only — Contact admin to manage time slots
        </div>
      </div>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <!-- Week Navigation -->
        <div class="flex justify-between items-center mb-6">
          <button phx-click="previous_week" class="btn btn-ghost btn-sm">
            ← Prev
          </button>
          <div class="text-center">
            <h2 class="text-lg sm:text-xl font-semibold">
              {Calendar.strftime(@current_week_start, "%b %d")} – {Calendar.strftime(
                Date.add(@current_week_start, 6),
                "%b %d, %Y"
              )}
            </h2>
            <button phx-click="today" class="btn btn-ghost btn-xs mt-1">Today</button>
          </div>
          <button phx-click="next_week" class="btn btn-ghost btn-sm">
            Next →
          </button>
        </div>
        
    <!-- Desktop: Week Grid -->
        <div class="hidden lg:grid grid-cols-7 gap-2">
          <!-- Day Headers -->
          <%= for day_offset <- 0..6 do %>
            <% day = Date.add(@current_week_start, day_offset) %>
            <div class={"text-center p-2 rounded-t-lg #{if day == Date.utc_today(), do: "bg-primary text-primary-content", else: "bg-base-200"}"}>
              <div class="text-sm font-medium">{Calendar.strftime(day, "%a")}</div>
              <div class="text-lg font-bold">{Calendar.strftime(day, "%d")}</div>
            </div>
          <% end %>
          
    <!-- Day Contents -->
          <%= for day_offset <- 0..6 do %>
            <% day = Date.add(@current_week_start, day_offset) %>
            <% day_sessions = Map.get(@week_sessions, day, []) %>
            <% day_of_week = Date.day_of_week(day) %>
            <% day_slots = Map.get(@time_slots, day_of_week, []) %>
            <div class={"min-h-40 p-2 border rounded-b-lg #{if day == Date.utc_today(), do: "border-primary"}"}>
              <%= if Enum.empty?(day_slots) and Enum.empty?(day_sessions) do %>
                <p class="text-xs text-base-content/30 text-center mt-4">No slots</p>
              <% else %>
                <div class="space-y-1">
                  <%= for slot <- Enum.sort_by(day_slots, & &1.start_time) do %>
                    <% session = find_session_for_slot(day_sessions, slot) %>
                    <%= if session do %>
                      <div class={"p-2 rounded text-xs #{session_bg_class(session.status)}"}>
                        <div class="font-medium">
                          {Calendar.strftime(slot.start_time, "%H:%M")}
                        </div>
                        <div class="truncate font-semibold">{display_name(session.client)}</div>
                        <div class="truncate opacity-75">{session.status}</div>
                      </div>
                    <% else %>
                      <div class="p-2 rounded text-xs bg-base-200 text-base-content/40 border border-dashed border-base-300">
                        <div class="font-medium">
                          {Calendar.strftime(slot.start_time, "%H:%M")}
                        </div>
                        <div class="italic">Available</div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Mobile: Stacked Days -->
        <div class="lg:hidden space-y-4">
          <%= for day_offset <- 0..6 do %>
            <% day = Date.add(@current_week_start, day_offset) %>
            <% day_sessions = Map.get(@week_sessions, day, []) %>
            <% day_of_week = Date.day_of_week(day) %>
            <% day_slots = Map.get(@time_slots, day_of_week, []) %>
            <div class={"card bg-base-100 shadow-md #{if day == Date.utc_today(), do: "ring-2 ring-primary"}"}>
              <div class="card-body p-4">
                <h3 class={"card-title text-base #{if day == Date.utc_today(), do: "text-primary"}"}>
                  {Calendar.strftime(day, "%A")}
                  <span class="text-sm font-normal text-base-content/70">
                    {Calendar.strftime(day, "%b %d")}
                  </span>
                  <%= if day == Date.utc_today() do %>
                    <span class="badge badge-primary badge-sm">Today</span>
                  <% end %>
                </h3>
                <%= if Enum.empty?(day_slots) and Enum.empty?(day_sessions) do %>
                  <p class="text-sm text-base-content/40">No time slots</p>
                <% else %>
                  <div class="space-y-2">
                    <%= for slot <- Enum.sort_by(day_slots, & &1.start_time) do %>
                      <% session = find_session_for_slot(day_sessions, slot) %>
                      <%= if session do %>
                        <div class={"flex justify-between items-center p-3 rounded-lg #{session_bg_class(session.status)}"}>
                          <div>
                            <span class="font-medium">
                              {Calendar.strftime(slot.start_time, "%H:%M")} – {Calendar.strftime(
                                slot.end_time,
                                "%H:%M"
                              )}
                            </span>
                            <p class="text-sm font-semibold">{display_name(session.client)}</p>
                          </div>
                          <span class={"badge badge-sm #{status_badge_class(session.status)}"}>
                            {session.status}
                          </span>
                        </div>
                      <% else %>
                        <div class="flex justify-between items-center p-3 rounded-lg bg-base-200 border border-dashed border-base-300">
                          <div>
                            <span class="font-medium text-base-content/60">
                              {Calendar.strftime(slot.start_time, "%H:%M")} – {Calendar.strftime(
                                slot.end_time,
                                "%H:%M"
                              )}
                            </span>
                            <p class="text-sm text-base-content/40 italic">Available</p>
                          </div>
                          <span class="badge badge-ghost badge-sm">Open</span>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Legend -->
        <div class="flex flex-wrap gap-4 mt-6 text-sm">
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-base-200 border border-dashed border-base-300 rounded"></div>
            <span>Available</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-warning rounded"></div>
            <span>Pending</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-success rounded"></div>
            <span>Confirmed</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-info rounded"></div>
            <span>Completed</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-error rounded"></div>
            <span>Cancelled</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp find_session_for_slot(day_sessions, slot) do
    Enum.find(day_sessions, fn session ->
      session_time = DateTime.to_time(session.scheduled_at)

      # Match if session starts within the slot's time range
      Time.compare(session_time, slot.start_time) in [:eq, :gt] and
        Time.compare(session_time, slot.end_time) == :lt
    end)
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unknown"

  defp session_bg_class("pending"), do: "bg-warning/20 text-warning-content"
  defp session_bg_class("confirmed"), do: "bg-success/20 text-success-content"
  defp session_bg_class("completed"), do: "bg-info/20 text-info-content"
  defp session_bg_class("cancelled"), do: "bg-error/20 text-error-content"
  defp session_bg_class(_), do: "bg-base-200"

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-info"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
