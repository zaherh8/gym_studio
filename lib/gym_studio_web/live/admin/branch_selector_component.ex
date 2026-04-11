defmodule GymStudioWeb.Admin.BranchSelectorComponent do
  @moduledoc """
  Branch selector component for admin pages.

  Renders a dropdown/tabs to filter admin views by branch.
  Persists the selected branch in the LiveView session.
  """
  use Phoenix.Component

  attr :branches, :list, required: true
  attr :selected_branch_id, :any, required: true, doc: "Branch ID or \"all\""
  attr :phx_target, :any, default: nil

  def branch_selector(assigns) do
    ~H"""
    <div class="flex items-center gap-2 flex-wrap">
      <div class="btn-group flex flex-wrap">
        <button
          phx-click="select_branch"
          phx-value-branch_id="all"
          phx-target={@phx_target}
          class={"btn btn-sm #{if @selected_branch_id == "all", do: "btn-primary", else: "btn-ghost"}"}
        >
          All Branches
        </button>
        <button
          :for={branch <- @branches}
          phx-click="select_branch"
          phx-value-branch_id={to_string(branch.id)}
          phx-target={@phx_target}
          class={"btn btn-sm #{if to_string(@selected_branch_id) == to_string(branch.id), do: "btn-primary", else: "btn-ghost"}"}
        >
          {branch.name}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Gets the effective branch_id for queries.
  Returns `nil` for "all branches" (unfiltered), or the integer branch_id.
  """
  def effective_branch_id("all"), do: nil
  def effective_branch_id(branch_id) when is_binary(branch_id), do: String.to_integer(branch_id)
  def effective_branch_id(branch_id) when is_integer(branch_id), do: branch_id
  def effective_branch_id(nil), do: nil

  @doc """
  Gets the branch label for display.
  """
  def branch_label("all", _branches), do: "All Branches"

  def branch_label(branch_id, branches) when is_binary(branch_id) do
    case Enum.find(branches, fn b -> to_string(b.id) == branch_id end) do
      nil -> "Unknown Branch"
      branch -> branch.name
    end
  end

  def branch_label(_branch_id, _branches), do: "All Branches"
end
