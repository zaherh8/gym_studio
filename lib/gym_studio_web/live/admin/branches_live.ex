defmodule GymStudioWeb.Admin.BranchesLive do
  @moduledoc """
  Admin live view for managing gym branches.

  Supports listing, creating, editing, and toggling branch active status.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Branches

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches()

    {:ok,
     assign(socket,
       page_title: "Manage Branches",
       branches: branches
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Branch")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    branch = Branches.get_branch!(id)
    assign(socket, page_title: "Edit Branch", branch: branch)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    branch = Branches.get_branch!(id)
    stats = Branches.get_branch_stats(branch.id)
    assign(socket, page_title: branch.name, branch: branch, branch_stats: stats)
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Manage Branches")
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    branch = Branches.get_branch!(id)

    case Branches.toggle_branch_active(branch) do
      {:ok, _branch} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Branch #{if !branch.active, do: "activated", else: "deactivated"} successfully"
         )
         |> assign(branches: Branches.list_branches())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update branch status")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <%= case @live_action do %>
        <% :new -> %>
          <.live_component
            module={GymStudioWeb.Admin.BranchFormComponent}
            id="new-branch"
            branch={%GymStudio.Branches.Branch{}}
            action={:new}
          />
        <% :edit -> %>
          <.live_component
            module={GymStudioWeb.Admin.BranchFormComponent}
            id={"edit-branch-#{@branch.id}"}
            branch={@branch}
            action={:edit}
          />
        <% :show -> %>
          <.branch_show branch={@branch} stats={@branch_stats} />
        <% :index -> %>
          <.branch_index branches={@branches} />
      <% end %>
    </div>
    """
  end

  attr :branches, :list, required: true

  defp branch_index(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
      <h1 class="text-3xl font-bold">Branches</h1>
      <.link navigate={~p"/admin/branches/new"} class="btn btn-primary btn-sm">
        <.icon name="hero-plus" class="size-4" /> New Branch
      </.link>
    </div>

    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th>Name</th>
            <th class="hidden sm:table-cell">Address</th>
            <th>Capacity</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={branch <- @branches} class="hover">
            <td>
              <.link navigate={~p"/admin/branches/#{branch.id}"} class="font-medium hover:underline">
                {branch.name}
              </.link>
              <div class="text-sm text-base-content/60 sm:hidden">{branch.address || "—"}</div>
            </td>
            <td class="hidden sm:table-cell">{branch.address || "—"}</td>
            <td>{branch.capacity}</td>
            <td>
              <span class={"badge #{if branch.active, do: "badge-success", else: "badge-error"}"}>
                {if branch.active, do: "Active", else: "Inactive"}
              </span>
            </td>
            <td>
              <div class="flex gap-2 flex-wrap">
                <.link navigate={~p"/admin/branches/#{branch.id}"} class="btn btn-xs btn-ghost">
                  View
                </.link>
                <.link navigate={~p"/admin/branches/#{branch.id}/edit"} class="btn btn-xs btn-ghost">
                  Edit
                </.link>
                <button
                  phx-click="toggle_active"
                  phx-value-id={branch.id}
                  class={"btn btn-xs #{if branch.active, do: "btn-warning", else: "btn-success"}"}
                >
                  {if branch.active, do: "Deactivate", else: "Activate"}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p :if={@branches == []} class="text-base-content/60 text-center py-8">No branches found.</p>
    """
  end

  attr :branch, :map, required: true
  attr :stats, :map, required: true

  defp branch_show(assigns) do
    ~H"""
    <div class="flex items-center gap-4 mb-8">
      <.link navigate={~p"/admin/branches"} class="btn btn-ghost btn-sm">
        <.icon name="hero-arrow-left" class="size-4" /> Back
      </.link>
      <h1 class="text-3xl font-bold">{@branch.name}</h1>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Branch Details</h2>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-base-content/60">Slug</span>
              <span class="font-mono text-sm">{@branch.slug}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Address</span>
              <span>{@branch.address || "—"}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Capacity</span>
              <span>{@branch.capacity}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Phone</span>
              <span>{@branch.phone || "—"}</span>
            </div>
            <div :if={@branch.latitude && @branch.longitude} class="flex justify-between">
              <span class="text-base-content/60">Coordinates</span>
              <span class="font-mono text-sm">
                {@branch.latitude}, {@branch.longitude}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Status</span>
              <span class={"badge #{if @branch.active, do: "badge-success", else: "badge-error"}"}>
                {if @branch.active, do: "Active", else: "Inactive"}
              </span>
            </div>
          </div>

          <div :if={@branch.operating_hours} class="mt-4">
            <h3 class="font-semibold mb-2">Operating Hours</h3>
            <div class="space-y-1">
              <div
                :for={{day, hours} <- sort_hours(@branch.operating_hours)}
                class="flex justify-between text-sm"
              >
                <span class="text-base-content/60 capitalize">{day_label(day)}</span>
                <span>{hours}</span>
              </div>
            </div>
          </div>

          <div class="card-actions justify-end mt-4">
            <.link navigate={~p"/admin/branches/#{@branch.id}/edit"} class="btn btn-primary btn-sm">
              Edit Branch
            </.link>
          </div>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg">Quick Stats</h2>
          <div class="grid grid-cols-1 gap-4">
            <div class="stat bg-base-300 rounded-box">
              <div class="stat-title">Clients</div>
              <div class="stat-value text-primary">{@stats.client_count}</div>
            </div>
            <div class="stat bg-base-300 rounded-box">
              <div class="stat-title">Trainers</div>
              <div class="stat-value text-secondary">{@stats.trainer_count}</div>
            </div>
            <div class="stat bg-base-300 rounded-box">
              <div class="stat-title">Sessions This Week</div>
              <div class="stat-value text-accent">{@stats.sessions_this_week}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp sort_hours(hours) when is_map(hours) do
    day_order = ~w(mon tue wed thu fri sat sun)
    hours |> Enum.sort_by(fn {day, _hours} -> Enum.find_index(day_order, &(&1 == day)) end)
  end

  defp day_label("mon"), do: "Monday"
  defp day_label("tue"), do: "Tuesday"
  defp day_label("wed"), do: "Wednesday"
  defp day_label("thu"), do: "Thursday"
  defp day_label("fri"), do: "Friday"
  defp day_label("sat"), do: "Saturday"
  defp day_label("sun"), do: "Sunday"
  defp day_label(other), do: other
end
