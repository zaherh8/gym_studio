defmodule GymStudioWeb.Trainer.ExercisesLive do
  use GymStudioWeb, :live_view

  alias GymStudio.Progress
  alias GymStudio.Progress.Exercise

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     assign(socket,
       page_title: "Exercise Library",
       current_user: user,
       exercises: Progress.list_exercises(),
       categories: Progress.list_categories(),
       muscle_groups: Progress.list_muscle_groups(),
       equipment: Progress.list_equipment(),
       tracking_types: Progress.list_tracking_types(),
       search: "",
       category_filter: "",
       show_form: false,
       editing: nil,
       form: to_form(Exercise.changeset(%Exercise{}, %{}))
     )}
  end

  @impl true
  def handle_event("filter", %{"search" => search, "category" => category}, socket) do
    exercises = Progress.list_exercises(search: search, category: category)
    {:noreply, assign(socket, exercises: exercises, search: search, category_filter: category)}
  end

  def handle_event("new", _, socket) do
    form = to_form(Exercise.changeset(%Exercise{}, %{}))
    {:noreply, assign(socket, show_form: true, editing: nil, form: form)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    exercise = Progress.get_exercise!(id)
    user = socket.assigns.current_user

    if exercise.is_custom and exercise.created_by_id == user.id do
      form = to_form(Exercise.changeset(exercise, %{}))
      {:noreply, assign(socket, show_form: true, editing: exercise, form: form)}
    else
      {:noreply, put_flash(socket, :error, "You can only edit your own custom exercises.")}
    end
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, show_form: false, editing: nil)}
  end

  def handle_event("save", %{"exercise" => params}, socket) do
    user = socket.assigns.current_user

    result =
      case socket.assigns.editing do
        nil -> Progress.create_exercise(params, user)
        exercise -> Progress.update_exercise(exercise, params)
      end

    case result do
      {:ok, _exercise} ->
        exercises =
          Progress.list_exercises(
            search: socket.assigns.search,
            category: socket.assigns.category_filter
          )

        {:noreply,
         socket
         |> assign(exercises: exercises, show_form: false, editing: nil)
         |> put_flash(:info, "Exercise saved successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    exercise = Progress.get_exercise!(id)
    user = socket.assigns.current_user

    if exercise.is_custom and exercise.created_by_id == user.id do
      case Progress.delete_exercise(exercise) do
        {:ok, _} ->
          exercises =
            Progress.list_exercises(
              search: socket.assigns.search,
              category: socket.assigns.category_filter
            )

          {:noreply,
           socket
           |> assign(exercises: exercises)
           |> put_flash(:info, "Exercise deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete exercise.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own custom exercises.")}
    end
  end

  def handle_event("validate", %{"exercise" => params}, socket) do
    changeset =
      case socket.assigns.editing do
        nil -> Exercise.changeset(%Exercise{}, params)
        exercise -> Exercise.changeset(exercise, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Exercise Library</h1>
        <button phx-click="new" class="btn btn-primary">Add Custom Exercise</button>
      </div>

      <form phx-change="filter" class="flex gap-4 mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search exercises..."
          class="input input-bordered flex-1"
          phx-debounce="300"
        />
        <select name="category" class="select select-bordered">
          <option value="">All Categories</option>
          <%= for cat <- @categories do %>
            <option value={cat} selected={@category_filter == cat}>
              {String.capitalize(cat)}
            </option>
          <% end %>
        </select>
      </form>

      <%= if @show_form do %>
        <div class="card bg-base-200 mb-6">
          <div class="card-body">
            <h2 class="card-title">
              {if @editing, do: "Edit Exercise", else: "New Custom Exercise"}
            </h2>
            <.form for={@form} phx-submit="save" phx-change="validate">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="form-control">
                  <label class="label"><span class="label-text">Name</span></label>
                  <input
                    type="text"
                    name="exercise[name]"
                    value={@form[:name].value}
                    class="input input-bordered"
                    required
                  />
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Category</span></label>
                  <select name="exercise[category]" class="select select-bordered" required>
                    <option value="">Select...</option>
                    <%= for cat <- @categories do %>
                      <option value={cat} selected={@form[:category].value == cat}>
                        {String.capitalize(cat)}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Muscle Group</span></label>
                  <select name="exercise[muscle_group]" class="select select-bordered">
                    <option value="">None</option>
                    <%= for mg <- @muscle_groups do %>
                      <option value={mg} selected={@form[:muscle_group].value == mg}>
                        {mg |> String.replace("_", " ") |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Equipment</span></label>
                  <select name="exercise[equipment]" class="select select-bordered">
                    <option value="">None</option>
                    <%= for eq <- @equipment do %>
                      <option value={eq} selected={@form[:equipment].value == eq}>
                        {eq |> String.replace("_", " ") |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Tracking Type</span></label>
                  <select name="exercise[tracking_type]" class="select select-bordered" required>
                    <option value="">Select...</option>
                    <%= for tt <- @tracking_types do %>
                      <option value={tt} selected={@form[:tracking_type].value == tt}>
                        {tt |> String.replace("_", " ") |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-control md:col-span-2">
                  <label class="label"><span class="label-text">Description</span></label>
                  <textarea name="exercise[description]" class="textarea textarea-bordered"><%= @form[:description].value %></textarea>
                </div>
              </div>
              <div class="flex gap-2 mt-4">
                <button type="submit" class="btn btn-primary">Save</button>
                <button type="button" phx-click="cancel" class="btn btn-ghost">Cancel</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              <th>Muscle Group</th>
              <th>Equipment</th>
              <th>Tracking</th>
              <th>Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for exercise <- @exercises do %>
              <tr>
                <td class="font-medium">{exercise.name}</td>
                <td>
                  <span class="badge badge-outline">{String.capitalize(exercise.category)}</span>
                </td>
                <td>
                  {if exercise.muscle_group,
                    do: exercise.muscle_group |> String.replace("_", " ") |> String.capitalize()}
                </td>
                <td>
                  {if exercise.equipment,
                    do: exercise.equipment |> String.replace("_", " ") |> String.capitalize()}
                </td>
                <td>{exercise.tracking_type |> String.replace("_", " ") |> String.capitalize()}</td>
                <td>{if exercise.is_custom, do: "Custom", else: "Predefined"}</td>
                <td class="flex gap-1">
                  <%= if exercise.is_custom and exercise.created_by_id == @current_user.id do %>
                    <button phx-click="edit" phx-value-id={exercise.id} class="btn btn-xs btn-ghost">
                      Edit
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={exercise.id}
                      data-confirm="Delete this exercise?"
                      class="btn btn-xs btn-error btn-ghost"
                    >
                      Delete
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @exercises == [] do %>
        <div class="text-center py-8 text-base-content/60">
          <p>No exercises found.</p>
        </div>
      <% end %>
    </div>
    """
  end
end
