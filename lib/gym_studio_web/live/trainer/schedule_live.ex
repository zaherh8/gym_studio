defmodule GymStudioWeb.Trainer.ScheduleLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}

  @hours_range 6..21

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
      |> assign(selected_session: nil)
      |> assign(
        mobile_day_offset: day_offset_for_today(today, Date.beginning_of_week(today, :monday))
      )
      |> load_week_data()

    {:ok, socket}
  end

  defp day_offset_for_today(today, week_start) do
    diff = Date.diff(today, week_start)
    if diff >= 0 and diff <= 6, do: diff, else: 0
  end

  defp load_week_data(%{assigns: %{trainer: nil}} = socket) do
    assign(socket, week_sessions: %{}, availability_map: %{})
  end

  defp load_week_data(%{assigns: %{trainer: trainer, current_week_start: week_start}} = socket) do
    week_end = Date.add(week_start, 6)

    sessions =
      Scheduling.list_sessions_for_trainer(trainer.user_id,
        from_date: week_start,
        to_date: week_end
      )

    week_sessions =
      sessions
      |> Enum.group_by(fn session -> DateTime.to_date(session.scheduled_at) end)
      |> Map.new(fn {date, day_sessions} ->
        by_hour =
          Enum.group_by(day_sessions, fn s ->
            DateTime.to_time(s.scheduled_at).hour
          end)

        {date, by_hour}
      end)

    # Load trainer availability for each day of week
    availabilities = Scheduling.list_trainer_availabilities(trainer.user_id)

    availability_map =
      Enum.into(availabilities, %{}, fn a ->
        {a.day_of_week, {a.start_time.hour, a.end_time.hour}}
      end)

    assign(socket, week_sessions: week_sessions, availability_map: availability_map)
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
      |> assign(mobile_day_offset: day_offset_for_today(today, new_week_start))
      |> load_week_data()

    {:noreply, socket}
  end

  def handle_event("show_session", %{"session-id" => session_id}, socket) do
    session = find_session_by_id(socket.assigns.week_sessions, session_id)
    {:noreply, assign(socket, selected_session: session)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_session: nil)}
  end

  def handle_event("mobile_prev_day", _params, socket) do
    offset = max(socket.assigns.mobile_day_offset - 1, 0)
    {:noreply, assign(socket, mobile_day_offset: offset)}
  end

  def handle_event("mobile_next_day", _params, socket) do
    offset = min(socket.assigns.mobile_day_offset + 1, 6)
    {:noreply, assign(socket, mobile_day_offset: offset)}
  end

  defp find_session_by_id(week_sessions, session_id) do
    Enum.find_value(week_sessions, fn {_date, hour_map} ->
      Enum.find_value(hour_map, fn {_hour, session} ->
        if session.id == session_id, do: session
      end)
    end)
  end

  defp is_available?(availability_map, day_of_week, hour) do
    case Map.get(availability_map, day_of_week) do
      nil -> false
      {start_h, end_h} -> hour >= start_h and hour < end_h
    end
  end

  defp session_color("pending"), do: "bg-warning text-warning-content"
  defp session_color("confirmed"), do: "bg-success text-success-content"
  defp session_color("completed"), do: "bg-base-300 text-base-content"
  defp session_color("cancelled"), do: "bg-error text-error-content"
  defp session_color("no_show"), do: "bg-error/50 text-error-content"
  defp session_color(_), do: "bg-base-200"

  defp status_badge("pending"), do: "badge-warning"
  defp status_badge("confirmed"), do: "badge-success"
  defp status_badge("completed"), do: "badge-ghost"
  defp status_badge("cancelled"), do: "badge-error"
  defp status_badge("no_show"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unknown"

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
        <h1 class="text-2xl sm:text-3xl font-bold">My Schedule</h1>
      </div>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <!-- Week Navigation -->
        <div class="flex justify-between items-center mb-4">
          <button phx-click="previous_week" class="btn btn-ghost btn-sm">← Prev</button>
          <div class="text-center">
            <h2 class="text-base sm:text-xl font-semibold">
              {Calendar.strftime(@current_week_start, "%b %d")} – {Calendar.strftime(
                Date.add(@current_week_start, 6),
                "%b %d, %Y"
              )}
            </h2>
            <button phx-click="today" class="btn btn-ghost btn-xs mt-1">Today</button>
          </div>
          <button phx-click="next_week" class="btn btn-ghost btn-sm">Next →</button>
        </div>
        
    <!-- Desktop: Weekly Calendar Grid -->
        <div class="hidden lg:block overflow-x-auto">
          <div class="min-w-[700px]">
            <!-- Header Row -->
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
            
    <!-- Hour Rows -->
            <%= for hour <- @hours_range do %>
              <div class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-base-200 min-h-[48px]">
                <div class="text-xs text-base-content/40 p-1 text-right pr-2 pt-2">
                  {format_hour(hour)}
                </div>
                <%= for day_offset <- 0..6 do %>
                  <% day = Date.add(@current_week_start, day_offset) %>
                  <% dow = Date.day_of_week(day) %>
                  <% available = is_available?(@availability_map, dow, hour) %>
                  <% sessions = get_in(@week_sessions, [day, hour]) || [] %>
                  <div class={"border-l border-base-200 p-0.5 #{if available, do: "bg-base-100", else: "bg-base-200/50"}"}>
                    <%= if sessions != [] do %>
                      <%= for session <- sessions do %>
                        <button
                          type="button"
                          phx-click="show_session"
                          phx-value-session-id={session.id}
                          class={"w-full text-left p-1.5 rounded text-xs cursor-pointer hover:opacity-80 #{session_color(session.status)}"}
                        >
                          <div class="font-semibold truncate">{display_name(session.client)}</div>
                          <div class="truncate opacity-75">{session.status}</div>
                        </button>
                      <% end %>
                    <% else %>
                      <%= if available do %>
                        <div class="w-full h-full min-h-[40px]"></div>
                      <% end %>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Mobile: Single Day View with swipe -->
        <div class="lg:hidden">
          <% mobile_day = Date.add(@current_week_start, @mobile_day_offset) %>
          <% mobile_dow = Date.day_of_week(mobile_day) %>
          
    <!-- Day Selector -->
          <div class="flex items-center justify-between mb-4">
            <button
              phx-click="mobile_prev_day"
              class={"btn btn-ghost btn-sm #{if @mobile_day_offset == 0, do: "btn-disabled"}"}
            >
              ←
            </button>
            <div class="text-center">
              <div class={"text-lg font-bold #{if mobile_day == Date.utc_today(), do: "text-primary"}"}>
                {Calendar.strftime(mobile_day, "%A")}
              </div>
              <div class="text-sm text-base-content/60">{Calendar.strftime(mobile_day, "%b %d")}</div>
            </div>
            <button
              phx-click="mobile_next_day"
              class={"btn btn-ghost btn-sm #{if @mobile_day_offset == 6, do: "btn-disabled"}"}
            >
              →
            </button>
          </div>
          
    <!-- Day dots -->
          <div class="flex justify-center gap-1.5 mb-4">
            <%= for i <- 0..6 do %>
              <div class={"w-2 h-2 rounded-full #{if i == @mobile_day_offset, do: "bg-primary", else: "bg-base-300"}"}>
              </div>
            <% end %>
          </div>
          
    <!-- Hour Slots -->
          <div class="space-y-1">
            <%= for hour <- @hours_range do %>
              <% available = is_available?(@availability_map, mobile_dow, hour) %>
              <% sessions = get_in(@week_sessions, [mobile_day, hour]) || [] %>
              <div class={"flex items-stretch rounded-lg overflow-hidden #{if available, do: "bg-base-100", else: "bg-base-200/30"}"}>
                <div class="w-16 shrink-0 text-xs text-base-content/40 p-2 flex items-center justify-end pr-3">
                  {format_hour(hour)}
                </div>
                <div class="flex-1 min-h-[44px] border-l border-base-200">
                  <%= if sessions != [] do %>
                    <%= for session <- sessions do %>
                      <button
                        type="button"
                        phx-click="show_session"
                        phx-value-session-id={session.id}
                        class={"w-full text-left p-2 #{session_color(session.status)}"}
                      >
                        <div class="font-semibold text-sm">{display_name(session.client)}</div>
                        <div class="text-xs opacity-75">{session.status}</div>
                      </button>
                    <% end %>
                  <% else %>
                    <%= if available do %>
                      <div class="p-2 text-xs text-base-content/20 italic">Available</div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Legend -->
        <div class="flex flex-wrap gap-3 mt-6 text-xs sm:text-sm">
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-base-100 border border-base-300 rounded"></div>
            <span>Available</span>
          </div>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-base-200/50 rounded"></div>
            <span>Unavailable</span>
          </div>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-warning rounded"></div>
            <span>Pending</span>
          </div>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-success rounded"></div>
            <span>Confirmed</span>
          </div>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-base-300 rounded"></div>
            <span>Completed</span>
          </div>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 bg-error rounded"></div>
            <span>Cancelled</span>
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
                <div class="flex justify-between">
                  <span class="text-base-content/60">Date</span>
                  <span class="font-semibold">
                    {Calendar.strftime(
                      DateTime.to_date(@selected_session.scheduled_at),
                      "%A, %b %d %Y"
                    )}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/60">Time</span>
                  <span class="font-semibold">
                    {format_hour(DateTime.to_time(@selected_session.scheduled_at).hour)}
                  </span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-base-content/60">Status</span>
                  <span class={"badge #{status_badge(@selected_session.status)}"}>
                    {@selected_session.status}
                  </span>
                </div>
                <%= if @selected_session.notes do %>
                  <div>
                    <span class="text-base-content/60 block mb-1">Notes</span>
                    <p class="text-sm bg-base-200 p-2 rounded">{@selected_session.notes}</p>
                  </div>
                <% end %>
                <%= if @selected_session.duration_minutes do %>
                  <div class="flex justify-between">
                    <span class="text-base-content/60">Duration</span>
                    <span>{@selected_session.duration_minutes} min</span>
                  </div>
                <% end %>
              </div>

              <div class="modal-action">
                <button phx-click="close_modal" class="btn">Close</button>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
