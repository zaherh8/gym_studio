defmodule GymStudioWeb.Trainer.ScheduleLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Scheduling}
  import GymStudioWeb.Helpers.BranchHelpers, only: [safe_string_to_integer: 1]

  @hours_range 6..21
  @heat_colors %{
    0 => "",
    1 => "#F9E0DC",
    2 => "#F4B8B0",
    3 => "#E88980",
    4 => "#DC6B60",
    5 => "#D94040"
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)
    today = local_today()
    current_month = Date.beginning_of_month(today)

    socket =
      socket
      |> assign(page_title: "My Schedule")
      |> assign(trainer: trainer)
      |> assign(current_month: current_month)
      |> assign(selected_date: today)
      |> assign(selected_session: nil)
      |> assign(local_today: today)
      |> assign(current_week_start: Date.beginning_of_week(today, :monday))
      |> load_schedule_data()

    {:ok, socket}
  end

  defp load_schedule_data(%{assigns: %{trainer: nil}} = socket) do
    socket
    |> assign(week_sessions: %{})
    |> assign(month_session_counts: %{})
    |> assign(availability_map: %{})
    |> assign(day_sessions: %{})
    |> assign(day_stats: %{booked: 0, pending: 0, open: 0})
  end

  defp load_schedule_data(
         %{
           assigns: %{
             trainer: trainer,
             current_month: month,
             selected_date: selected_date,
             current_scope: scope
           }
         } =
           socket
       ) do
    branch_id = scope.user.branch_id
    trainer_id = trainer.user_id

    # Month session counts for heat map
    month_start = Date.beginning_of_month(month)
    month_end = Date.end_of_month(month)

    # Extend range to cover calendar grid padding days
    cal_start = Date.beginning_of_week(month_start, :monday)
    cal_end = Date.end_of_week(month_end, :sunday)

    month_session_counts =
      Scheduling.count_sessions_per_day_for_trainer(trainer_id, cal_start, cal_end,
        branch_id: branch_id
      )

    # Load day sessions for the selected date
    day_sessions = load_day_sessions(trainer_id, selected_date, branch_id)

    # Load trainer availability
    availabilities = Scheduling.list_trainer_availabilities(trainer_id)

    availability_map =
      Enum.into(availabilities, %{}, fn a ->
        {a.day_of_week, {a.start_time.hour, a.end_time.hour}}
      end)

    # Compute day stats
    day_stats = compute_day_stats(day_sessions, availability_map, selected_date)

    # Load week data for desktop grid
    week_start =
      socket.assigns[:current_week_start] || Date.beginning_of_week(selected_date, :monday)

    week_end = Date.add(week_start, 6)

    week_sessions =
      Scheduling.list_sessions_for_trainer(trainer_id,
        from_date: week_start,
        to_date: week_end,
        branch_id: branch_id
      )
      |> Enum.group_by(fn session -> DateTime.to_date(session.scheduled_at) end)
      |> Map.new(fn {date, day_sessions_list} ->
        by_hour =
          Enum.group_by(day_sessions_list, fn s ->
            DateTime.to_time(s.scheduled_at).hour
          end)

        {date, by_hour}
      end)

    socket
    |> assign(month_session_counts: month_session_counts)
    |> assign(day_sessions: day_sessions)
    |> assign(availability_map: availability_map)
    |> assign(day_stats: day_stats)
    |> assign(week_sessions: week_sessions)
  end

  defp load_day_sessions(trainer_id, date, branch_id) do
    Scheduling.list_sessions_for_trainer(trainer_id,
      from_date: date,
      to_date: date,
      branch_id: branch_id
    )
    |> Enum.group_by(fn s ->
      DateTime.to_time(s.scheduled_at).hour
    end)
  end

  defp compute_day_stats(day_sessions, availability_map, selected_date) do
    dow = Date.day_of_week(selected_date)

    booked =
      day_sessions
      |> Map.values()
      |> List.flatten()
      |> Enum.count(fn s -> s.status in ["confirmed", "completed"] end)

    pending =
      day_sessions
      |> Map.values()
      |> List.flatten()
      |> Enum.count(fn s -> s.status == "pending" end)

    # Count available hours within the display range (6..21) that have no sessions
    display_range = MapSet.new(6..21)

    available_hours =
      case Map.get(availability_map, dow) do
        nil ->
          MapSet.new()

        {start_h, end_h} ->
          start_h..(end_h - 1) |> MapSet.new() |> MapSet.intersection(display_range)
      end

    hours_with_sessions =
      day_sessions
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.intersection(display_range)

    open =
      MapSet.size(available_hours) -
        MapSet.size(MapSet.intersection(hours_with_sessions, available_hours))

    %{booked: booked, pending: pending, open: max(open, 0)}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("previous_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, -7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_schedule_data()

    {:noreply, socket}
  end

  def handle_event("next_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, 7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_schedule_data()

    {:noreply, socket}
  end

  def handle_event("today", _params, socket) do
    today = local_today()
    new_week_start = Date.beginning_of_week(today, :monday)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> assign(selected_date: today)
      |> assign(current_month: Date.beginning_of_month(today))
      |> load_schedule_data()

    {:noreply, socket}
  end

  def handle_event("select_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        # Sync current_month when the selected date is in a different month
        current_month =
          if date.month != socket.assigns.current_month.month or
               date.year != socket.assigns.current_month.year do
            Date.beginning_of_month(date)
          else
            socket.assigns.current_month
          end

        socket =
          socket
          |> assign(selected_date: date)
          |> assign(current_month: current_month)
          |> load_schedule_data()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("previous_month", _params, socket) do
    prev_month = Date.add(socket.assigns.current_month, -32)
    new_month_start = Date.beginning_of_month(prev_month)

    socket =
      socket
      |> assign(current_month: new_month_start)
      |> load_schedule_data()

    {:noreply, socket}
  end

  def handle_event("next_month", _params, socket) do
    next_month = Date.add(socket.assigns.current_month, 32)
    new_month_start = Date.beginning_of_month(next_month)

    socket =
      socket
      |> assign(current_month: new_month_start)
      |> load_schedule_data()

    {:noreply, socket}
  end

  def handle_event("show_session", %{"session-id" => session_id}, socket) do
    session =
      find_session_by_id(socket.assigns.day_sessions, session_id) ||
        find_session_by_id(socket.assigns.week_sessions, session_id)

    {:noreply, assign(socket, selected_session: session)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_session: nil)}
  end

  def handle_event("open_slot_click", %{"hour" => hour_str}, socket) do
    case safe_string_to_integer(hour_str) do
      nil ->
        {:noreply, socket}

      hour ->
        date = socket.assigns.selected_date

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Session creation for #{format_hour(hour)} on #{Calendar.strftime(date, "%b %d")} — coming soon!"
         )}
    end
  end

  # --- Helpers ---

  defp find_session_by_id(day_sessions, session_id) do
    Enum.find_value(day_sessions, fn
      {_hour, sessions} when is_list(sessions) ->
        Enum.find(sessions, fn s -> s.id == session_id end)

      {_date, hour_map} when is_map(hour_map) ->
        find_session_by_id(hour_map, session_id)
    end)
  end

  defp is_available?(availability_map, day_of_week, hour) do
    case Map.get(availability_map, day_of_week) do
      nil -> false
      {start_h, end_h} -> hour >= start_h and hour < end_h
    end
  end

  defp heat_level(count) when count >= 5, do: 5
  defp heat_level(count) when count >= 4, do: 4
  defp heat_level(count) when count >= 3, do: 3
  defp heat_level(count) when count >= 2, do: 2
  defp heat_level(count) when count >= 1, do: 1
  defp heat_level(_), do: 0

  defp heat_color(count) do
    Map.get(@heat_colors, heat_level(count), "")
  end

  defp heat_color_for_level(level) do
    Map.get(@heat_colors, level, "")
  end

  defp calendar_weeks(month) do
    month_start = Date.beginning_of_month(month)
    month_end = Date.end_of_month(month)
    cal_start = Date.beginning_of_week(month_start, :monday)
    cal_end = Date.end_of_week(month_end, :sunday)

    cal_start
    |> Stream.iterate(&Date.add(&1, 1))
    |> Stream.take_while(&(Date.compare(&1, cal_end) != :gt))
    |> Enum.chunk_every(7)
  end

  defp session_accent_bar_class("confirmed"), do: "schedule-accent-bar-confirmed"
  defp session_accent_bar_class("completed"), do: "schedule-accent-bar-confirmed"
  defp session_accent_bar_class("pending"), do: "schedule-accent-bar-pending"
  defp session_accent_bar_class("cancelled"), do: "schedule-accent-bar-cancelled"
  defp session_accent_bar_class(_), do: "schedule-accent-bar-cancelled"

  defp status_badge_class("confirmed"), do: "schedule-status-badge-confirmed"
  defp status_badge_class("completed"), do: "schedule-status-badge-confirmed"
  defp status_badge_class("pending"), do: "schedule-status-badge-pending"
  defp status_badge_class("cancelled"), do: "schedule-status-badge-cancelled"
  defp status_badge_class(_), do: "schedule-status-badge-cancelled"

  defp status_label("confirmed"), do: "CONFIRMED"
  defp status_label("completed"), do: "CONFIRMED"
  defp status_label("pending"), do: "PENDING"
  defp status_label("cancelled"), do: "CANCELLED"
  defp status_label(other), do: String.upcase(other)

  defp day_cell_style(is_selected, level, count) do
    base = "width: 34px; height: 34px;"

    cond do
      is_selected ->
        "#{base} background-color: #E63946; color: white; box-shadow: 0 0 0 2px #A32832;"

      level > 0 ->
        "#{base} background-color: #{heat_color(count)};"

      true ->
        base
    end
  end

  defp day_text_class(in_month, is_selected, is_today) do
    cond do
      !in_month -> "text-sm schedule-day-text-outside"
      is_selected -> "text-sm font-bold text-white"
      is_today -> "text-sm font-bold schedule-day-text-today"
      true -> "text-sm font-medium"
    end
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unassigned"

  defp local_today do
    case DateTime.now("Asia/Beirut") do
      {:ok, datetime} -> DateTime.to_date(datetime)
      {:error, _} -> Date.utc_today()
    end
  end

  defp format_hour(0), do: "12 AM"
  defp format_hour(h) when h < 12, do: "#{h} AM"
  defp format_hour(12), do: "12 PM"
  defp format_hour(h), do: "#{h - 12} PM"

  defp now_minutes_offset(selected_date) do
    if selected_date == local_today() do
      now =
        case DateTime.now("Asia/Beirut") do
          {:ok, datetime} -> DateTime.to_time(datetime)
          {:error, :utc_only_time_zone_database} -> Time.utc_now()
        end

      if now.hour >= 6 and now.hour < 22 do
        (now.hour - 6) * 60 + now.minute
      else
        nil
      end
    else
      nil
    end
  end

  defp now_line_percent(nil), do: nil

  defp now_line_percent(minutes_offset) do
    # Total display range: 6 AM to 10 PM = 16 hours = 960 minutes
    Float.round(minutes_offset / 960.0 * 100, 2)
  end

  defp is_past_hour?(selected_date, hour) do
    if selected_date == local_today() do
      now =
        case DateTime.now("Asia/Beirut") do
          {:ok, datetime} -> DateTime.to_time(datetime)
          {:error, :utc_only_time_zone_database} -> Time.utc_now()
        end

      hour < now.hour
    else
      # For past dates (before today), all hours are past
      Date.compare(selected_date, local_today()) == :lt
    end
  end

  # Desktop helpers (unchanged)
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

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :hours_range, @hours_range)

    ~H"""
    <div class="container mx-auto px-2 sm:px-4 py-4 sm:py-8">
      <!-- Flash Messages -->
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div
          id="flash-info"
          class="alert alert-info mb-4 shadow-sm flash-auto-dismiss"
          phx-hook="FlashAutoDismiss"
        >
          <span>{flash}</span>
        </div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div
          id="flash-error"
          class="alert alert-error mb-4 shadow-sm flash-auto-dismiss"
          phx-hook="FlashAutoDismiss"
        >
          <span>{flash}</span>
        </div>
      <% end %>

      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
        <h1 class="text-2xl sm:text-3xl font-bold">My Schedule</h1>
      </div>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <!-- ==================== DESKTOP VIEW (unchanged 7-day grid) ==================== -->
        <div class="hidden lg:block">
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

          <div class="overflow-x-auto">
            <div class="min-w-[700px]">
              <!-- Header Row -->
              <div class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-base-300">
                <div class="p-2"></div>
                <%= for day_offset <- 0..6 do %>
                  <% day = Date.add(@current_week_start, day_offset) %>
                  <div class={"text-center p-2 #{if day == @local_today, do: "bg-primary/10 rounded-t-lg"}"}>
                    <div class="text-xs font-medium text-base-content/60">
                      {Calendar.strftime(day, "%a")}
                    </div>
                    <div class={"text-lg font-bold #{if day == @local_today, do: "text-primary"}"}>
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
        </div>
        
    <!-- ==================== MOBILE VIEW (new month grid + hourly rail) ==================== -->
        <div class="lg:hidden">
          <!-- Month Navigation -->
          <div class="flex justify-between items-center mb-3">
            <button phx-click="previous_month" class="btn btn-ghost btn-sm p-1">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
            <h2 class="text-lg font-semibold">
              {Calendar.strftime(@current_month, "%B %Y")}
            </h2>
            <button phx-click="next_month" class="btn btn-ghost btn-sm p-1">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>
          
    <!-- Month Grid (always expanded) -->
          <div id="month-grid">
            <!-- Day Headers -->
            <div class="grid grid-cols-7 mb-1">
              <%= for day_name <- ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] do %>
                <div class="text-center text-xs font-medium schedule-day-header-dot">
                  {day_name}
                </div>
              <% end %>
            </div>
            
    <!-- Calendar Weeks -->
            <%= for week <- calendar_weeks(@current_month) do %>
              <div class="grid grid-cols-7">
                <%= for day <- week do %>
                  <% in_month = day.month == @current_month.month %>
                  <% count = Map.get(@month_session_counts, day, 0) %>
                  <% level = heat_level(count) %>
                  <% is_selected = day == @selected_date %>
                  <% is_today = day == @local_today %>
                  <div class="flex items-center justify-center py-0.5" style="height: 40px;">
                    <button
                      type="button"
                      phx-click="select_date"
                      phx-value-date={Date.to_iso8601(day)}
                      class="relative flex items-center justify-center rounded-full transition-all duration-150 ease-in-out"
                      style={day_cell_style(is_selected, level, count)}
                    >
                      <span class={day_text_class(in_month, is_selected, is_today)}>
                        {day.day}
                      </span>
                      <%= if level == 1 and !is_selected do %>
                        <span
                          class="absolute bottom-0.5 left-1/2 -translate-x-1/2 rounded-full schedule-heat-dot"
                          style="width: 4px; height: 4px;"
                        >
                        </span>
                      <% end %>
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Heat-map Legend -->
            <div class="flex items-center justify-center gap-2 mt-2 mb-1">
              <span class="text-xs schedule-heat-legend-label">Less</span>
              <%= for level <- 1..5 do %>
                <div
                  class="rounded-sm"
                  style={"width: 14px; height: 14px; background-color: #{heat_color_for_level(level)}"}
                >
                </div>
              <% end %>
              <span class="text-xs schedule-heat-legend-label">Busier</span>
              <span class="mx-1 text-xs schedule-heat-legend-label">·</span>
              <span class="flex items-center gap-1">
                <span
                  class="rounded-full schedule-selected-indicator"
                  style="width: 14px; height: 14px;"
                >
                </span>
                <span class="text-xs schedule-heat-legend-label">Selected</span>
              </span>
            </div>
          </div>
          
    <!-- Day Schedule Header -->
          <div class="mt-4 mb-3">
            <div class="uppercase tracking-widest text-xs mb-1 schedule-day-header-label">
              <%= if @selected_date == @local_today do %>
                Today's Schedule
              <% else %>
                {Calendar.strftime(@selected_date, "%A")}'s Schedule
              <% end %>
            </div>
            <div class="flex items-baseline gap-2">
              <h3 class="text-2xl font-bold">
                {Calendar.strftime(@selected_date, "%A")}
              </h3>
              <span class="text-xl schedule-day-header-dot">
                · {Calendar.strftime(@selected_date, "%b %d")}
              </span>
            </div>
          </div>
          
    <!-- Stats Row -->
          <div class="flex items-center gap-3 mb-4 text-sm">
            <span class="flex items-center gap-1">
              <span class="inline-block w-2.5 h-2.5 rounded-full schedule-stat-dot-booked"></span>
              <span>{@day_stats.booked} booked</span>
            </span>
            <span class="flex items-center gap-1">
              <span class="inline-block w-2.5 h-2.5 rounded-full schedule-stat-dot-pending"></span>
              <span>{@day_stats.pending} pending</span>
            </span>
            <span class="flex items-center gap-1">
              <span class="inline-block w-2.5 h-2.5 rounded-full border border-gray-300 schedule-stat-dot-open">
              </span>
              <span>{@day_stats.open} open</span>
            </span>
          </div>
          
    <!-- Hourly Day Rail -->
          <div class="relative" id="hourly-rail">
            <%= for hour <- @hours_range do %>
              <% dow = Date.day_of_week(@selected_date) %>
              <% available = is_available?(@availability_map, dow, hour) %>
              <% sessions = Map.get(@day_sessions, hour, []) %>
              <div class="flex items-stretch schedule-rail-row">
                <!-- Time Label -->
                <div class="w-16 shrink-0 text-xs flex items-start justify-end pr-3 pt-3 schedule-rail-time-label">
                  {format_hour(hour)}
                </div>
                <!-- Slot Content -->
                <div class="flex-1 border-t py-1.5 schedule-rail-slot-border">
                  <%= if sessions != [] do %>
                    <%= for session <- sessions do %>
                      <!-- Booked Session Card -->
                      <button
                        type="button"
                        phx-click="show_session"
                        phx-value-session-id={session.id}
                        class="w-full text-left flex rounded-xl overflow-hidden bg-white border mb-1 cursor-pointer hover:shadow-sm transition-shadow schedule-session-card"
                      >
                        <!-- Left Accent Bar -->
                        <div class={"w-1 shrink-0 #{session_accent_bar_class(session.status)}"}></div>
                        <!-- Card Content -->
                        <div class="flex-1 p-3">
                          <div class="flex items-center justify-between">
                            <span class="font-semibold text-base">
                              {display_name(session.client)}
                            </span>
                            <span class={"text-xs font-semibold px-2 py-0.5 rounded-full #{status_badge_class(session.status)}"}>
                              {status_label(session.status)}
                            </span>
                          </div>
                          <div class="text-sm mt-0.5 schedule-day-header-dot">
                            <%= if session.package do %>
                              {session.package.package_type}
                            <% else %>
                              Session
                            <% end %>
                          </div>
                        </div>
                      </button>
                    <% end %>
                  <% else %>
                    <%= if available and !is_past_hour?(@selected_date, hour) do %>
                      <!-- Open Slot Card (future only) -->
                      <div class="flex items-center justify-between rounded-xl px-3 py-3 border border-dashed schedule-rail-slot-border schedule-session-card">
                        <span class="text-sm schedule-day-header-dot">Open for booking</span>
                        <button
                          type="button"
                          phx-click="open_slot_click"
                          phx-value-hour={hour}
                          class="flex items-center justify-center w-7 h-7 rounded-full border-2 transition-colors schedule-open-slot-btn"
                        >
                          <span class="text-lg leading-none font-light">+</span>
                        </button>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Now-line (today only) -->
            <% now_pct = now_minutes_offset(@selected_date) |> now_line_percent() %>
            <%= if now_pct do %>
              <div
                class="absolute left-16 right-0 pointer-events-none"
                style={"top: #{now_pct}%;"}
              >
                <div class="relative">
                  <div class="absolute left-0 top-0 w-2 h-2 rounded-full schedule-now-line-dot"></div>
                  <div class="ml-1.5 h-0.5 schedule-now-line-bar"></div>
                </div>
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
