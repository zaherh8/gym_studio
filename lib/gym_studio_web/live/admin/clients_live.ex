defmodule GymStudioWeb.Admin.ClientsLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Branches}
  alias GymStudioWeb.Admin.BranchSelectorComponent

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches(active: true)
    selected_branch_id = "all"
    branch_id = BranchSelectorComponent.effective_branch_id(selected_branch_id)
    clients = Accounts.list_clients(branch_id: branch_id)

    {:ok,
     assign(socket,
       page_title: "Manage Clients",
       branches: branches,
       selected_branch_id: selected_branch_id,
       clients: clients
     )}
  end

  @impl true
  def handle_event("select_branch", %{"branch_id" => branch_id}, socket) do
    effective_id = BranchSelectorComponent.effective_branch_id(branch_id)
    clients = Accounts.list_clients(branch_id: effective_id)

    {:noreply, assign(socket, selected_branch_id: branch_id, clients: clients)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
        <h1 class="text-3xl font-bold">Manage Clients</h1>
        <BranchSelectorComponent.branch_selector
          branches={@branches}
          selected_branch_id={@selected_branch_id}
        />
      </div>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Branch</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for client <- @clients do %>
              <tr>
                <td>{client.user.name || "—"}</td>
                <td>{client.user.email || "—"}</td>
                <td>{client.user.phone_number}</td>
                <td>
                  <span :if={client.user.branch_id} class="badge badge-outline badge-sm">
                    {BranchSelectorComponent.branch_label(to_string(client.user.branch_id), @branches)}
                  </span>
                  <span :if={is_nil(client.user.branch_id)} class="text-base-content/40 text-sm">
                    —
                  </span>
                </td>
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

      <p :if={@clients == []} class="text-base-content/60 text-center py-8">No clients found.</p>
    </div>
    """
  end
end
