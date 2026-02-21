defmodule GymStudioWeb.Client.NotificationsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Notifications

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if connected?(socket) do
      Notifications.subscribe(user.id)
    end

    notifications = Notifications.list_notifications_for_user(user.id)

    socket =
      socket
      |> assign(page_title: "Notifications")
      |> assign(notifications: notifications)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    notifications = [notification | socket.assigns.notifications]
    {:noreply, assign(socket, notifications: notifications)}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    notification = Notifications.get_notification!(id)

    case Notifications.mark_as_read(notification) do
      {:ok, _notification} ->
        notifications =
          Notifications.list_notifications_for_user(socket.assigns.current_scope.user.id)

        {:noreply, assign(socket, notifications: notifications)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user_id = socket.assigns.current_scope.user.id
    Notifications.mark_all_as_read(user_id)
    notifications = Notifications.list_notifications_for_user(user_id)
    {:noreply, assign(socket, notifications: notifications)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Notifications</h1>
        <%= if has_unread?(@notifications) do %>
          <button phx-click="mark_all_read" class="btn btn-ghost btn-sm">
            Mark all as read
          </button>
        <% end %>
      </div>

      <%= if Enum.empty?(@notifications) do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body text-center">
            <p class="text-base-content/70">No notifications yet.</p>
          </div>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for notification <- @notifications do %>
            <div class={"card bg-base-100 shadow-xl #{if !notification.read, do: "border-l-4 border-primary"}"}>
              <div class="card-body py-4">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="font-semibold">{notification.title}</h3>
                    <p class="text-base-content/70">{notification.message}</p>
                    <p class="text-xs text-base-content/50 mt-2">
                      {format_time_ago(notification.inserted_at)}
                    </p>
                  </div>
                  <%= if !notification.read do %>
                    <button
                      phx-click="mark_read"
                      phx-value-id={notification.id}
                      class="btn btn-ghost btn-xs"
                    >
                      Mark read
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp has_unread?(notifications) do
    Enum.any?(notifications, &(!&1.read))
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%B %d, %Y")
    end
  end
end
