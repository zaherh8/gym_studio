defmodule GymStudioWeb.Admin.SessionsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    sessions = Scheduling.list_pending_sessions()
    {:ok, assign(socket, page_title: "Manage Sessions", sessions: sessions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Sessions</h1>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Client</th>
              <th>Date/Time</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for session <- @sessions do %>
              <tr>
                <td><%= session.client.email %></td>
                <td><%= Calendar.strftime(session.scheduled_at, "%Y-%m-%d %H:%M") %></td>
                <td>
                  <span class={"badge #{status_badge_class(session.status)}"}><%= session.status %></span>
                </td>
                <td>
                  <.link navigate={~p"/admin/sessions/#{session.id}"} class="btn btn-sm btn-ghost">View</.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-info"
  defp status_badge_class("completed"), do: "badge-success"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
