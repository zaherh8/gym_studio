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
      |> load_week_sessions()

    {:ok, socket}
  end

  defp load_week_sessions(socket) do
    case socket.assigns do
      %{trainer: nil} ->
        assign(socket, week_sessions: %{})

      %{trainer: trainer, current_week_start: week_start} ->
        week_end = Date.add(week_start, 6)
        sessions = Scheduling.list_sessions_for_trainer(trainer.id, from: week_start, to: week_end)

        # Group sessions by date
        week_sessions =
          Enum.group_by(sessions, fn session ->
            DateTime.to_date(session.scheduled_at)
          end)

        assign(socket, week_sessions: week_sessions)
    end
  end

  @impl true
  def handle_event("previous_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, -7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_sessions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    new_week_start = Date.add(socket.assigns.current_week_start, 7)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_sessions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    new_week_start = Date.beginning_of_week(today, :monday)

    socket =
      socket
      |> assign(current_week_start: new_week_start)
      |> load_week_sessions()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">My Schedule</h1>

      <%= if @trainer == nil do %>
        <div class="alert alert-warning">
          <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <!-- Week Navigation -->
        <div class="flex justify-between items-center mb-6">
          <button phx-click="previous_week" class="btn btn-ghost">
            &larr; Previous Week
          </button>
          <div class="text-center">
            <h2 class="text-xl font-semibold">
              <%= Calendar.strftime(@current_week_start, "%B %d") %> -
              <%= Calendar.strftime(Date.add(@current_week_start, 6), "%B %d, %Y") %>
            </h2>
            <button phx-click="today" class="btn btn-ghost btn-xs">Today</button>
          </div>
          <button phx-click="next_week" class="btn btn-ghost">
            Next Week &rarr;
          </button>
        </div>

        <!-- Week Grid -->
        <div class="grid grid-cols-7 gap-2">
          <!-- Day Headers -->
          <%= for day_offset <- 0..6 do %>
            <% day = Date.add(@current_week_start, day_offset) %>
            <div class={"text-center p-2 rounded-t-lg #{if day == Date.utc_today(), do: "bg-primary text-primary-content", else: "bg-base-200"}"}>
              <div class="text-sm font-medium"><%= Calendar.strftime(day, "%a") %></div>
              <div class="text-lg font-bold"><%= Calendar.strftime(day, "%d") %></div>
            </div>
          <% end %>

          <!-- Day Contents -->
          <%= for day_offset <- 0..6 do %>
            <% day = Date.add(@current_week_start, day_offset) %>
            <% day_sessions = Map.get(@week_sessions, day, []) %>
            <div class={"min-h-32 p-2 border rounded-b-lg #{if day == Date.utc_today(), do: "border-primary"}"}>
              <%= if Enum.empty?(day_sessions) do %>
                <p class="text-xs text-base-content/50 text-center">No sessions</p>
              <% else %>
                <div class="space-y-1">
                  <%= for session <- Enum.sort_by(day_sessions, & &1.scheduled_at) do %>
                    <div class={"p-2 rounded text-xs #{session_bg_class(session.status)}"}>
                      <div class="font-medium">
                        <%= Calendar.strftime(session.scheduled_at, "%H:%M") %>
                      </div>
                      <div class="truncate"><%= session.client.user.email %></div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Legend -->
        <div class="flex gap-4 mt-6 text-sm">
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-warning rounded"></div>
            <span>Pending</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-info rounded"></div>
            <span>Confirmed</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-4 h-4 bg-success rounded"></div>
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

  defp session_bg_class("pending"), do: "bg-warning text-warning-content"
  defp session_bg_class("confirmed"), do: "bg-info text-info-content"
  defp session_bg_class("completed"), do: "bg-success text-success-content"
  defp session_bg_class("cancelled"), do: "bg-error text-error-content"
  defp session_bg_class(_), do: "bg-base-200"
end
