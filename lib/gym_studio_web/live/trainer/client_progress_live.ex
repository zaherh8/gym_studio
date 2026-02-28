defmodule GymStudioWeb.Trainer.ClientProgressLive do
  @moduledoc """
  Trainer view of a client's exercise progress — read-only.
  Shows exercise history cards with PR badges and category filter.
  Reuses logic from `GymStudio.Progress`.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Progress, Scheduling}

  @impl true
  def mount(%{"client_id" => client_id}, _session, socket) do
    trainer = socket.assigns.current_scope.user

    if Scheduling.trainer_has_client?(trainer.id, client_id) do
      client = Accounts.get_user!(client_id)
      categories = Progress.list_categories()
      exercises = Progress.list_client_exercises(client_id)

      socket =
        socket
        |> assign(page_title: "#{client.name || "Client"}'s Progress")
        |> assign(client: client)
        |> assign(exercises: exercises)
        |> assign(categories: categories)
        |> assign(selected_category: nil)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Not authorized to view this client's progress.")
        |> redirect(to: ~p"/trainer/clients")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    client_id = socket.assigns.client.id
    category = if category == "", do: nil, else: category

    exercises =
      if category do
        Progress.list_client_exercises(client_id, category: category)
      else
        Progress.list_client_exercises(client_id)
      end

    {:noreply, assign(socket, exercises: exercises, selected_category: category)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <div class="mb-6">
          <.link navigate={~p"/trainer/clients"} class="btn btn-ghost btn-sm mb-2">
            ← Back to My Clients
          </.link>
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800">
            {@client.name || "Client"}'s Progress
          </h1>
          <p class="text-gray-600 mt-1">Exercise history and personal records</p>
          <div class="mt-2 flex gap-2">
            <.link
              navigate={~p"/trainer/clients/#{@client.id}/progress/metrics"}
              class="btn btn-primary btn-sm"
            >
              📏 Body Metrics
            </.link>
            <.link
              navigate={~p"/trainer/clients/#{@client.id}/progress/goals"}
              class="btn btn-primary btn-sm"
            >
              🎯 Goals
            </.link>
          </div>
        </div>

        <%!-- Category Filter --%>
        <div class="mb-6">
          <form phx-change="filter_category">
            <select name="category" class="select select-bordered w-full max-w-xs">
              <option value="">All Categories</option>
              <%= for cat <- @categories do %>
                <option value={cat} selected={@selected_category == cat}>
                  {String.capitalize(cat)}
                </option>
              <% end %>
            </select>
          </form>
        </div>

        <%!-- Exercise Cards --%>
        <%= if @exercises == [] do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <p class="text-gray-500 text-lg">No exercises logged yet.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for exercise <- @exercises do %>
              <div class="bg-white rounded-2xl shadow-lg p-5">
                <div class="flex items-start justify-between mb-3">
                  <div>
                    <h3 class="font-semibold text-gray-800">{exercise.exercise_name}</h3>
                    <span class="text-xs text-gray-500 bg-gray-100 rounded-full px-2 py-1">
                      {String.capitalize(exercise.category)}
                    </span>
                  </div>
                  <%= if exercise.has_pr do %>
                    <span class="text-2xl" title="Personal Record">🏆</span>
                  <% end %>
                </div>

                <div class="space-y-1 text-sm text-gray-600">
                  <%= if exercise.latest_weight_kg do %>
                    <p>Weight: <span class="font-medium">{exercise.latest_weight_kg} kg</span></p>
                  <% end %>
                  <%= if exercise.latest_sets do %>
                    <p>Sets: <span class="font-medium">{exercise.latest_sets}</span></p>
                  <% end %>
                  <%= if exercise.latest_reps do %>
                    <p>Reps: <span class="font-medium">{exercise.latest_reps}</span></p>
                  <% end %>
                  <p class="text-gray-400">{exercise.total_sessions} session(s) logged</p>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
