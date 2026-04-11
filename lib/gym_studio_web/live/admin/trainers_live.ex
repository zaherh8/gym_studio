defmodule GymStudioWeb.Admin.TrainersLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Branches}
  alias GymStudioWeb.Admin.BranchSelectorComponent

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches(active: true)
    selected_branch_id = "all"
    branch_id = BranchSelectorComponent.effective_branch_id(selected_branch_id)
    trainers = Accounts.list_trainers(branch_id: branch_id)

    {:ok,
     assign(socket,
       page_title: "Manage Trainers",
       branches: branches,
       selected_branch_id: selected_branch_id,
       trainers: trainers
     )}
  end

  @impl true
  def handle_event("select_branch", %{"branch_id" => branch_id}, socket) do
    effective_id = BranchSelectorComponent.effective_branch_id(branch_id)
    trainers = Accounts.list_trainers(branch_id: effective_id)

    {:noreply, assign(socket, selected_branch_id: branch_id, trainers: trainers)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
        <h1 class="text-3xl font-bold">Manage Trainers</h1>
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
              <th>Status</th>
              <th>Branch</th>
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
                  <span :if={trainer.user.branch_id} class="badge badge-outline badge-sm">
                    {BranchSelectorComponent.branch_label(
                      to_string(trainer.user.branch_id),
                      @branches
                    )}
                  </span>
                  <span :if={is_nil(trainer.user.branch_id)} class="text-base-content/40 text-sm">
                    —
                  </span>
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

      <p :if={@trainers == []} class="text-base-content/60 text-center py-8">No trainers found.</p>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("approved"), do: "badge-success"
  defp status_badge_class("suspended"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
