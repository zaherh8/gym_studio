defmodule GymStudioWeb.Admin.PackagesLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Packages

  @impl true
  def mount(_params, _session, socket) do
    packages = Packages.list_all_packages()
    {:ok, assign(socket, page_title: "Manage Packages", packages: packages)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Manage Packages</h1>
        <.link navigate={~p"/admin/packages/new"} class="btn btn-primary">Assign Package</.link>
      </div>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Client</th>
              <th>Type</th>
              <th>Remaining</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <%= for package <- @packages do %>
              <tr>
                <td>{package.client.email}</td>
                <td>{package.package_type}</td>
                <td>{package.remaining_sessions}/{package.total_sessions}</td>
                <td>
                  <span class={"badge #{if package.active, do: "badge-success", else: "badge-ghost"}"}>
                    {if package.active, do: "Active", else: "Inactive"}
                  </span>
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
