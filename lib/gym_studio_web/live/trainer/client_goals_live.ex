defmodule GymStudioWeb.Trainer.ClientGoalsLive do
  @moduledoc """
  Trainer view of a client's fitness goals with write capabilities.
  Trainers can create goals, update progress, achieve/abandon goals,
  and delete goals they created. Client-created goals are read-only.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Goals, Scheduling}
  alias GymStudio.Goals.FitnessGoal

  @impl true
  def mount(%{"client_id" => client_id}, _session, socket) do
    trainer = socket.assigns.current_scope.user

    if Scheduling.trainer_has_client?(trainer.id, client_id) do
      client = Accounts.get_user!(client_id)

      socket =
        socket
        |> assign(page_title: "#{client.name || "Client"}'s Goals")
        |> assign(client: client, trainer: trainer)
        |> assign(status_filter: "all", editing_progress: nil)
        |> assign_goals()
        |> assign_new_form()

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
  def handle_event("save_goal", %{"fitness_goal" => params}, socket) do
    trainer = socket.assigns.trainer
    client = socket.assigns.client

    attrs =
      params
      |> Map.put("client_id", client.id)
      |> Map.put("created_by_id", trainer.id)

    case Goals.create_goal(attrs) do
      {:ok, _goal} ->
        {:noreply,
         socket
         |> assign_goals()
         |> assign_new_form()
         |> put_flash(:info, "Goal created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(status_filter: status)
     |> assign_goals(status)}
  end

  def handle_event("achieve", %{"id" => id}, socket) do
    client = socket.assigns.client
    goal = Goals.get_goal!(id)

    if goal.client_id != client.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      {:ok, _} = Goals.achieve_goal(goal)

      {:noreply,
       socket
       |> assign_goals()
       |> put_flash(:info, "Goal achieved! 🏆")}
    end
  end

  def handle_event("abandon", %{"id" => id}, socket) do
    client = socket.assigns.client
    goal = Goals.get_goal!(id)

    if goal.client_id != client.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      {:ok, _} = Goals.abandon_goal(goal)

      {:noreply,
       socket
       |> assign_goals()
       |> put_flash(:info, "Goal abandoned.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    trainer = socket.assigns.trainer
    goal = Goals.get_goal!(id)

    if goal.created_by_id != trainer.id do
      {:noreply, put_flash(socket, :error, "You can only delete goals you created.")}
    else
      case Goals.delete_goal(goal) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign_goals()
           |> put_flash(:info, "Goal deleted.")}

        {:error, :not_active} ->
          {:noreply, put_flash(socket, :error, "Only active goals can be deleted.")}
      end
    end
  end

  def handle_event("edit_progress", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_progress: id)}
  end

  def handle_event("cancel_progress", _params, socket) do
    {:noreply, assign(socket, editing_progress: nil)}
  end

  def handle_event("save_progress", %{"goal_id" => id, "current_value" => value}, socket) do
    client = socket.assigns.client
    goal = Goals.get_goal!(id)

    if goal.client_id != client.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      case Goals.update_progress(goal, value) do
        {:ok, updated} ->
          msg =
            if updated.status == "achieved",
              do: "Progress updated — goal achieved! 🏆",
              else: "Progress updated."

          {:noreply,
           socket
           |> assign(editing_progress: nil)
           |> assign_goals()
           |> put_flash(:info, msg)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Invalid value.")}
      end
    end
  end

  # ── Private ──────────────────────────────────────────────────────

  defp assign_goals(socket, status_filter \\ nil) do
    client_id = socket.assigns.client.id
    filter = status_filter || socket.assigns.status_filter
    opts = if filter in [nil, "", "all"], do: [], else: [status: filter]
    assign(socket, goals: Goals.list_goals(client_id, opts))
  end

  defp assign_new_form(socket) do
    changeset = Goals.change_goal(%FitnessGoal{})
    assign(socket, form: to_form(changeset))
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

  defp trainer_created?(goal, trainer) do
    goal.created_by_id == trainer.id
  end

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

        <%!-- Create Goal Form --%>
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <h2 class="text-lg font-semibold mb-4">New Goal</h2>
          <.form for={@form} phx-submit="save_goal" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label"><span class="label-text">Title</span></label>
                <input
                  type="text"
                  name="fitness_goal[title]"
                  value={@form[:title].value}
                  class="input input-bordered w-full"
                  required
                  placeholder="e.g. Bench Press 100kg"
                />
                <%= for {msg, _} <- @form[:title].errors do %>
                  <p class="mt-1 text-sm text-error">Title: {msg}</p>
                <% end %>
              </div>
              <div>
                <label class="label"><span class="label-text">Target Value</span></label>
                <input
                  type="number"
                  name="fitness_goal[target_value]"
                  value={@form[:target_value].value}
                  class="input input-bordered w-full"
                  required
                  step="any"
                  min="0.01"
                  placeholder="e.g. 100"
                />
                <%= for {msg, _} <- @form[:target_value].errors do %>
                  <p class="mt-1 text-sm text-error">Target value: {msg}</p>
                <% end %>
              </div>
              <div>
                <label class="label"><span class="label-text">Unit</span></label>
                <select
                  name="fitness_goal[target_unit]"
                  class="select select-bordered w-full"
                  required
                >
                  <option value="">Select unit</option>
                  <option value="kg" selected={@form[:target_unit].value == "kg"}>kg</option>
                  <option value="kg_loss" selected={@form[:target_unit].value == "kg_loss"}>
                    kg (loss)
                  </option>
                  <option value="minutes" selected={@form[:target_unit].value == "minutes"}>
                    minutes
                  </option>
                  <option value="reps" selected={@form[:target_unit].value == "reps"}>reps</option>
                  <option value="sessions" selected={@form[:target_unit].value == "sessions"}>
                    sessions
                  </option>
                </select>
              </div>
              <div>
                <label class="label"><span class="label-text">Target Date (optional)</span></label>
                <input
                  type="date"
                  name="fitness_goal[target_date]"
                  value={@form[:target_date].value}
                  class="input input-bordered w-full"
                />
              </div>
            </div>
            <div>
              <label class="label"><span class="label-text">Description (optional)</span></label>
              <textarea
                name="fitness_goal[description]"
                class="textarea textarea-bordered w-full"
                rows="2"
                placeholder="Any notes about this goal..."
              >{@form[:description].value}</textarea>
            </div>
            <button type="submit" class="btn btn-primary">Create Goal</button>
          </.form>
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

                <%!-- Progress Bar --%>
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
                  <p class="text-xs text-gray-400 mb-3">Target: {goal.target_date}</p>
                <% end %>

                <%!-- Update Progress (trainer can update any active goal) --%>
                <%= if goal.status == "active" do %>
                  <%= if @editing_progress == goal.id do %>
                    <form phx-submit="save_progress" class="flex gap-2 mb-3">
                      <input type="hidden" name="goal_id" value={goal.id} />
                      <input
                        type="number"
                        name="current_value"
                        value={goal.current_value}
                        class="input input-bordered input-sm flex-1"
                        step="any"
                        min="0"
                      />
                      <button type="submit" class="btn btn-primary btn-sm">Save</button>
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        phx-click="cancel_progress"
                      >
                        Cancel
                      </button>
                    </form>
                  <% else %>
                    <button
                      class="btn btn-outline btn-sm mb-3"
                      phx-click="edit_progress"
                      phx-value-id={goal.id}
                    >
                      Update Progress
                    </button>
                  <% end %>
                <% end %>

                <%!-- Actions --%>
                <%= if goal.status == "active" do %>
                  <div class="flex gap-2 flex-wrap">
                    <button
                      class="btn btn-success btn-xs"
                      phx-click="achieve"
                      phx-value-id={goal.id}
                    >
                      ✓ Achieve
                    </button>
                    <button
                      class="btn btn-warning btn-xs"
                      phx-click="abandon"
                      phx-value-id={goal.id}
                    >
                      Abandon
                    </button>
                    <%= if trainer_created?(goal, @trainer) do %>
                      <button
                        class="btn btn-error btn-xs"
                        phx-click="delete"
                        phx-value-id={goal.id}
                        data-confirm="Are you sure you want to delete this goal?"
                      >
                        Delete
                      </button>
                    <% end %>
                  </div>
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
