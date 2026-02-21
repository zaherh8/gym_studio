defmodule GymStudioWeb.Admin.ClientsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    clients = Accounts.list_clients()
    {:ok, assign(socket, page_title: "Manage Clients", clients: clients)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Clients</h1>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Phone</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for client <- @clients do %>
              <tr>
                <td>{client.user.email}</td>
                <td>{client.user.phone_number}</td>
                <td>
                  <.link navigate={~p"/admin/clients/#{client.id}"} class="btn btn-sm btn-ghost">
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
end
