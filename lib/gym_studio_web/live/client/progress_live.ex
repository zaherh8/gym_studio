defmodule GymStudioWeb.Client.ProgressLive do
  @moduledoc """
  Client progress dashboard showing all exercises with stats, PR badges,
  and category filtering.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Progress

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    categories = Progress.list_categories()
    exercises = Progress.list_client_exercises(user.id)

    socket =
      socket
      |> assign(page_title: "My Progress")
      |> assign(exercises: exercises)
      |> assign(categories: categories)
      |> assign(selected_category: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    user = socket.assigns.current_scope.user
    category = if category == "", do: nil, else: category

    exercises =
      if category do
        Progress.list_client_exercises(user.id, category: category)
      else
        Progress.list_client_exercises(user.id)
      end

    {:noreply, assign(socket, exercises: exercises, selected_category: category)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <div class="mb-6">
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800">My Progress</h1>
          <p class="text-gray-600 mt-1">Track your exercise history and personal records</p>
        </div>
        
    <!-- Category Filter -->
        <div class="mb-6">
          <form phx-change="filter_category">
            <select
              name="category"
              class="select select-bordered w-full max-w-xs"
            >
              <option value="">All Categories</option>
              <%= for cat <- @categories do %>
                <option value={cat} selected={@selected_category == cat}>
                  {String.capitalize(cat)}
                </option>
              <% end %>
            </select>
          </form>
        </div>
        
    <!-- Exercise Cards -->
        <%= if @exercises == [] do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <p class="text-gray-500 text-lg">No exercises logged yet.</p>
            <p class="text-gray-400 mt-2">Complete a training session to see your progress here.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for exercise <- @exercises do %>
              <.link
                navigate={~p"/client/progress/exercises/#{exercise.exercise_id}"}
                class="bg-white rounded-2xl shadow-lg p-5 hover:shadow-xl transition-shadow group"
              >
                <div class="flex items-start justify-between mb-3">
                  <div>
                    <h3 class="font-semibold text-gray-800 group-hover:text-primary transition-colors">
                      {exercise.exercise_name}
                    </h3>
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
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
