defmodule GymStudioWeb.Client.DashboardLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Packages, Scheduling, Notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = GymStudio.Accounts.get_client_by_user_id(user.id)

    if connected?(socket) do
      Notifications.subscribe(user.id)
    end

    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(client: client)
      |> assign_dashboard_data(client)

    {:ok, socket}
  end

  defp assign_dashboard_data(socket, nil) do
    socket
    |> assign(active_package: nil)
    |> assign(upcoming_sessions: [])
  end

  defp assign_dashboard_data(socket, client) do
    active_package =
      case Packages.get_active_package_for_client(client.user_id) do
        {:ok, package} -> package
        {:error, :no_active_package} -> nil
      end

    upcoming_sessions = Scheduling.list_upcoming_sessions_for_client(client.user_id, limit: 5)

    socket
    |> assign(active_package: active_package)
    |> assign(upcoming_sessions: upcoming_sessions)
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <!-- Welcome Header with Package Info -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <h1 class="text-2xl md:text-3xl font-bold text-gray-800">
                Welcome back, {@current_scope.user.name || "there"}!
              </h1>
              <p class="text-gray-600 mt-1">Ready to crush your fitness goals?</p>
            </div>
            <!-- Package Info Badge -->
            <%= if @active_package do %>
              <div class="flex items-center gap-3 bg-primary/10 rounded-xl px-4 py-3">
                <div class="bg-primary rounded-full p-2">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
                    />
                  </svg>
                </div>
                <div>
                  <p class="text-sm text-gray-600">Active Package</p>
                  <p class="font-bold text-primary">
                    <span class="text-xl"><%= @active_package.remaining_sessions %></span>/{@active_package.total_sessions} sessions
                  </p>
                  <%= if @active_package.expires_at do %>
                    <p class="text-xs text-gray-500">
                      Expires: {Calendar.strftime(@active_package.expires_at, "%b %d, %Y")}
                    </p>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="flex items-center gap-3 bg-amber-50 rounded-xl px-4 py-3">
                <div class="bg-amber-400 rounded-full p-2">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <div>
                  <p class="text-sm text-amber-700">No active package</p>
                  <p class="text-xs text-amber-600">Contact your trainer to get started</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Quick Actions -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <.link
            navigate={~p"/client/book"}
            class="bg-white rounded-2xl shadow-lg p-5 hover:shadow-xl transition-shadow group"
          >
            <div class="bg-primary/10 rounded-xl p-3 w-fit mb-3 group-hover:bg-primary/20 transition-colors">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-primary"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                />
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800">Book Session</h3>
            <p class="text-sm text-gray-500">Schedule your next workout</p>
          </.link>

          <.link
            navigate={~p"/client/sessions"}
            class="bg-white rounded-2xl shadow-lg p-5 hover:shadow-xl transition-shadow group"
          >
            <div class="bg-blue-100 rounded-xl p-3 w-fit mb-3 group-hover:bg-blue-200 transition-colors">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-blue-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800">My Sessions</h3>
            <p class="text-sm text-gray-500">View all sessions</p>
          </.link>

          <.link
            navigate={~p"/client/packages"}
            class="bg-white rounded-2xl shadow-lg p-5 hover:shadow-xl transition-shadow group"
          >
            <div class="bg-green-100 rounded-xl p-3 w-fit mb-3 group-hover:bg-green-200 transition-colors">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
                />
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800">Packages</h3>
            <p class="text-sm text-gray-500">View available plans</p>
          </.link>

          <.link
            navigate={~p"/client/profile"}
            class="bg-white rounded-2xl shadow-lg p-5 hover:shadow-xl transition-shadow group"
          >
            <div class="bg-purple-100 rounded-xl p-3 w-fit mb-3 group-hover:bg-purple-200 transition-colors">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-purple-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                />
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800">Profile</h3>
            <p class="text-sm text-gray-500">Manage your account</p>
          </.link>
        </div>
        
    <!-- Upcoming Sessions -->
        <div class="bg-white rounded-2xl shadow-lg overflow-hidden">
          <div class="p-6 border-b border-gray-100">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-bold text-gray-800 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6 text-primary"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                Upcoming Sessions
              </h2>
              <.link
                navigate={~p"/client/sessions"}
                class="text-primary hover:underline text-sm font-medium"
              >
                View all
              </.link>
            </div>
          </div>

          <%= if Enum.empty?(@upcoming_sessions) do %>
            <div class="p-8 text-center">
              <div class="bg-gray-100 rounded-full p-4 w-fit mx-auto mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-8 w-8 text-gray-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-gray-800 mb-2">No upcoming sessions</h3>
              <p class="text-gray-500 mb-4">Ready to start your fitness journey?</p>
              <.link navigate={~p"/client/book"} class="btn btn-primary">
                Book Your First Session
              </.link>
            </div>
          <% else %>
            <div class="divide-y divide-gray-100">
              <%= for session <- @upcoming_sessions do %>
                <div class="p-4 md:p-6 hover:bg-gray-50 transition-colors">
                  <div class="flex flex-col md:flex-row md:items-center gap-4">
                    <!-- Date/Time -->
                    <div class="flex items-center gap-4 flex-1">
                      <div class="bg-primary/10 rounded-xl p-3 text-center min-w-[70px]">
                        <p class="text-xs font-medium text-primary uppercase">
                          {Calendar.strftime(session.scheduled_at, "%b")}
                        </p>
                        <p class="text-2xl font-bold text-primary">
                          {Calendar.strftime(session.scheduled_at, "%d")}
                        </p>
                      </div>
                      <div>
                        <p class="font-semibold text-gray-800">
                          {Calendar.strftime(session.scheduled_at, "%A")}
                        </p>
                        <p class="text-gray-600">
                          {Calendar.strftime(session.scheduled_at, "%H:%M")}
                        </p>
                        <%= if session.trainer do %>
                          <p class="text-sm text-gray-500 mt-1">
                            with {session.trainer.name || session.trainer.email}
                          </p>
                        <% end %>
                      </div>
                    </div>
                    
    <!-- Status & Actions -->
                    <div class="flex items-center gap-3">
                      <span class={"px-3 py-1 rounded-full text-sm font-medium #{status_badge_class(session.status)}"}>
                        {String.capitalize(session.status)}
                      </span>
                      <.link
                        navigate={~p"/client/sessions/#{session.id}"}
                        class="btn btn-ghost btn-sm"
                      >
                        View
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-4 w-4"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 5l7 7-7 7"
                          />
                        </svg>
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "bg-amber-100 text-amber-700"
  defp status_badge_class("confirmed"), do: "bg-green-100 text-green-700"
  defp status_badge_class("completed"), do: "bg-blue-100 text-blue-700"
  defp status_badge_class("cancelled"), do: "bg-red-100 text-red-700"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-700"
end
