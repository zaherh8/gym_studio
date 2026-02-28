defmodule GymStudioWeb.Trainer.ClientGoalsLive do
  @moduledoc """
  Trainer read-only view of a client's fitness goals and progress bars.
  Reuses logic from `GymStudio.Goals`.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Goals, Scheduling}

  @impl true
  def mount(%{"client_id" => client_id}, _session, socket) do
    trainer = socket.assigns.current_scope.user

    if Scheduling.trainer_has_client?(trainer.id, client_id) do
      client = Accounts.get_user!(client_id)
      goals = Goals.list_goals(client_id)

      socket =
        socket
        |> assign(page_title: "#{client.name || "Client"}'s Goals")
        |> assign(client: client)
        |> assign(goals: goals)
        |> assign(status_filter: "all")

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Not authorized to view this client's goals.")
        |> redirect(to: ~p"/trainer/clients")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    client_id = socket.assigns.client.id
    opts = if status in [nil, "", "all"], do: [], else: [status: status]
    goals = Goals.list_goals(client_id, opts)
    {:noreply, assign(socket, goals: goals, status_filter: status)}
  end

  defp progress_percent(current, target) do
    if Decimal.compare(target, Decimal.new(0)) == :gt do
      current
      |> Decimal.mult(100)
      |> Decimal.div(target)
      |> Decimal.round(0)
      |> Decimal.to_integer()
      |> min(100)
    else
      0
    end
  end

  defp status_badge_class("active"), do: "badge badge-info"
  defp status_badge_class("achieved"), do: "badge badge-success"
  defp status_badge_class("abandoned"), do: "badge badge-ghost"
  defp status_badge_class(_), do: "badge"

  defp status_label("active"), do: "Active"
  defp status_label("achieved"), do: "🏆 Achieved"
  defp status_label("abandoned"), do: "Abandoned"
  defp status_label(s), do: s

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/clients/#{@client.id}/progress"}
            class="btn btn-ghost btn-sm mb-2"
          >
            ← Back to Progress
          </.link>
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800">
            {@client.name || "Client"}'s Goals
          </h1>
          <p class="text-gray-600 mt-1">Fitness goals and progress</p>
        </div>

        <%!-- Status Filter --%>
        <div class="mb-6">
          <form phx-change="filter_status">
            <select name="status" class="select select-bordered w-full max-w-xs">
              <option value="all" selected={@status_filter == "all"}>All Goals</option>
              <option value="active" selected={@status_filter == "active"}>Active</option>
              <option value="achieved" selected={@status_filter == "achieved"}>Achieved</option>
              <option value="abandoned" selected={@status_filter == "abandoned"}>Abandoned</option>
            </select>
          </form>
        </div>

        <%!-- Goal Cards --%>
        <%= if @goals == [] do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <p class="text-gray-500 text-lg">No goals yet.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for goal <- @goals do %>
              <div class="bg-white rounded-2xl shadow-lg p-6">
                <div class="flex justify-between items-start mb-3">
                  <h3 class="text-lg font-semibold text-gray-800">{goal.title}</h3>
                  <span class={status_badge_class(goal.status)}>{status_label(goal.status)}</span>
                </div>

                <%= if goal.description do %>
                  <p class="text-gray-500 text-sm mb-3">{goal.description}</p>
                <% end %>

                <div class="mb-3">
                  <div class="flex justify-between text-sm text-gray-600 mb-1">
                    <span>{goal.current_value} / {goal.target_value} {goal.target_unit}</span>
                    <span>{progress_percent(goal.current_value, goal.target_value)}%</span>
                  </div>
                  <progress
                    class="progress progress-primary w-full"
                    value={progress_percent(goal.current_value, goal.target_value)}
                    max="100"
                  >
                  </progress>
                </div>

                <%= if goal.target_date do %>
                  <p class="text-xs text-gray-400">Target: {goal.target_date}</p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
