defmodule GymStudioWeb.Admin.TrainersLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    trainers = Accounts.list_trainers()
    {:ok, assign(socket, page_title: "Manage Trainers", trainers: trainers)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Trainers</h1>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for trainer <- @trainers do %>
              <tr>
                <td>{trainer.user.name || trainer.user.email}</td>
                <td>
                  <span class={"badge #{status_badge_class(trainer.status)}"}>{trainer.status}</span>
                </td>
                <td>
                  <.link navigate={~p"/admin/trainers/#{trainer.id}"} class="btn btn-sm btn-ghost">
                    View
                  </.link>
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
  defp status_badge_class("approved"), do: "badge-success"
  defp status_badge_class("suspended"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
