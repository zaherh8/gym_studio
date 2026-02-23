defmodule GymStudioWeb.Trainer.SessionLogLive do
  use GymStudioWeb, :live_view

  alias GymStudio.{Scheduling, Progress}

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    user = socket.assigns.current_scope.user
    session = Scheduling.get_session!(session_id)

    cond do
      session.trainer_id != user.id ->
        {:ok,
         socket |> put_flash(:error, "Not authorized") |> redirect(to: ~p"/trainer/sessions")}

      session.status not in ["confirmed", "completed"] ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "Exercise logging is only available for confirmed or completed sessions"
         )
         |> redirect(to: ~p"/trainer/sessions")}

      true ->
        logs = Progress.list_exercise_logs(session_id)

        socket =
          socket
          |> assign(
            page_title: "Log Exercises",
            session: session,
            logs: logs,
            search_query: "",
            search_results: [],
            show_search: false
          )

        {:ok, socket}
    end
  end

  # ── handle_event callbacks ─────────────────────────────────────────

  @impl true
  def handle_event("toggle_search", _params, socket) do
    {:noreply,
     assign(socket,
       show_search: !socket.assigns.show_search,
       search_query: "",
       search_results: []
     )}
  end

  def handle_event("search_exercises", %{"query" => query}, socket) do
    results = if String.length(query) >= 2, do: Progress.search_exercises(query), else: []
    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  def handle_event("add_exercise", %{"exercise_id" => exercise_id}, socket) do
    user = socket.assigns.current_scope.user
    session = socket.assigns.session
    exercise = Progress.get_exercise!(exercise_id)
    next_order = length(socket.assigns.logs)

    base_attrs = %{
      "training_session_id" => session.id,
      "exercise_id" => exercise_id,
      "client_id" => session.client_id,
      "logged_by_id" => user.id,
      "order" => next_order
    }

    attrs = default_metrics(base_attrs, exercise.tracking_type)

    case Progress.create_exercise_log(attrs) do
      {:ok, _log} ->
        logs = Progress.list_exercise_logs(session.id)

        {:noreply,
         assign(socket, logs: logs, show_search: false, search_query: "", search_results: [])}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not add exercise")}
    end
  end

  def handle_event("update_log", %{"log_id" => log_id} = params, socket) do
    case authorize_log(log_id, socket) do
      {:ok, log} ->
        attrs =
          params
          |> Map.drop(["log_id"])
          |> Map.new()
          |> then(fn attrs ->
            # Keep notes as-is (can be empty to clear), but drop empty metric fields
            metric_fields = ["sets", "reps", "weight_kg", "duration_seconds"]

            Enum.reduce(metric_fields, attrs, fn field, acc ->
              case Map.get(acc, field) do
                "" -> Map.delete(acc, field)
                _ -> acc
              end
            end)
          end)

        case Progress.update_exercise_log(log, attrs) do
          {:ok, _log} ->
            logs = Progress.list_exercise_logs(socket.assigns.session.id)
            {:noreply, socket |> assign(logs: logs) |> put_flash(:info, "Exercise updated ✓")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not update exercise log")}
        end

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end

  def handle_event("delete_log", %{"log_id" => log_id}, socket) do
    case authorize_log(log_id, socket) do
      {:ok, log} ->
        case Progress.delete_exercise_log(log) do
          {:ok, _} ->
            logs = Progress.list_exercise_logs(socket.assigns.session.id)
            {:noreply, assign(socket, logs: logs)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not delete exercise log")}
        end

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end

  def handle_event("move_up", %{"log_id" => log_id}, socket) do
    reorder_log(socket, log_id, :up)
  end

  def handle_event("move_down", %{"log_id" => log_id}, socket) do
    reorder_log(socket, log_id, :down)
  end

  # ── Render ─────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/trainer/sessions"} class="btn btn-ghost btn-sm">← Back</.link>
        <h1 class="text-3xl font-bold">Log Exercises</h1>
      </div>

      <%!-- Session Info --%>
      <div class="card bg-base-100 shadow-md mb-6">
        <div class="card-body p-4">
          <div class="flex flex-wrap gap-4 text-sm">
            <div>
              <span class="font-semibold">Client:</span> {display_name(@session.client)}
            </div>
            <div>
              <span class="font-semibold">Date:</span>
              {Calendar.strftime(@session.scheduled_at, "%B %d, %Y at %H:%M")}
            </div>
            <div>
              <span class={"badge #{status_badge_class(@session.status)}"}>{@session.status}</span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Add Exercise Button --%>
      <div class="mb-6">
        <button phx-click="toggle_search" class="btn btn-primary">
          {if @show_search, do: "Cancel", else: "Add Exercise"}
        </button>
      </div>

      <%!-- Exercise Search --%>
      <%= if @show_search do %>
        <div class="card bg-base-100 shadow-md mb-6">
          <div class="card-body p-4">
            <form phx-change="search_exercises">
              <input
                type="text"
                name="query"
                placeholder="Search exercises..."
                value={@search_query}
                class="input input-bordered w-full"
                phx-debounce="300"
                autofocus
              />
            </form>
            <%= if @search_results != [] do %>
              <ul class="menu bg-base-200 rounded-box mt-2 max-h-60 overflow-y-auto">
                <%= for exercise <- @search_results do %>
                  <li>
                    <button phx-click="add_exercise" phx-value-exercise_id={exercise.id}>
                      <div>
                        <span class="font-medium">{exercise.name}</span>
                        <span class="text-xs text-base-content/50 ml-2">
                          {exercise.category} · {exercise.tracking_type}
                        </span>
                      </div>
                    </button>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Exercise Logs --%>
      <%= if @logs == [] do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body text-center py-12">
            <p class="text-base-content/50 text-lg">No exercises logged yet.</p>
            <p class="text-base-content/40 text-sm">Click "Add Exercise" to start logging.</p>
          </div>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for {log, idx} <- Enum.with_index(@logs) do %>
            <div class="card bg-base-100 shadow-md">
              <div class="card-body p-4">
                <div class="flex justify-between items-start">
                  <div class="flex items-center gap-2">
                    <span class="text-base-content/40 font-mono text-sm">{idx + 1}.</span>
                    <h3 class="font-semibold">{log.exercise.name}</h3>
                    <span class="badge badge-ghost badge-sm">{log.exercise.tracking_type}</span>
                  </div>
                  <div class="flex gap-1">
                    <button
                      phx-click="move_up"
                      phx-value-log_id={log.id}
                      class="btn btn-ghost btn-xs"
                      disabled={idx == 0}
                    >
                      ↑
                    </button>
                    <button
                      phx-click="move_down"
                      phx-value-log_id={log.id}
                      class="btn btn-ghost btn-xs"
                      disabled={idx == length(@logs) - 1}
                    >
                      ↓
                    </button>
                    <button
                      phx-click="delete_log"
                      phx-value-log_id={log.id}
                      class="btn btn-ghost btn-xs text-error"
                      data-confirm="Remove this exercise?"
                    >
                      ✕
                    </button>
                  </div>
                </div>

                <form phx-submit="update_log" class="mt-3">
                  <input type="hidden" name="log_id" value={log.id} />
                  <div class="flex flex-wrap gap-3 items-end">
                    {render_metric_inputs(assigns, log)}
                    <div class="form-control">
                      <label class="label py-0"><span class="label-text text-xs">&nbsp;</span></label>
                      <button type="submit" class="btn btn-sm btn-primary">Save</button>
                    </div>
                  </div>
                  <div class="mt-2">
                    <input
                      type="text"
                      name="notes"
                      value={log.notes || ""}
                      placeholder="Add notes..."
                      class="input input-bordered input-sm w-full"
                    />
                  </div>
                </form>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Private helpers ────────────────────────────────────────────────

  defp authorize_log(log_id, socket) do
    log = Progress.get_exercise_log!(log_id)

    if log.training_session_id == socket.assigns.session.id do
      {:ok, log}
    else
      {:error, :unauthorized}
    end
  end

  defp reorder_log(socket, log_id, direction) do
    logs = socket.assigns.logs
    idx = Enum.find_index(logs, &(&1.id == log_id))

    swap_idx =
      case direction do
        :up -> max(idx - 1, 0)
        :down -> min(idx + 1, length(logs) - 1)
      end

    if idx != swap_idx do
      log_a = Enum.at(logs, idx)
      log_b = Enum.at(logs, swap_idx)

      # Verify both belong to this session
      if log_a.training_session_id == socket.assigns.session.id and
           log_b.training_session_id == socket.assigns.session.id do
        Progress.update_exercise_log(log_a, %{"order" => swap_idx})
        Progress.update_exercise_log(log_b, %{"order" => idx})
        logs = Progress.list_exercise_logs(socket.assigns.session.id)
        {:noreply, assign(socket, logs: logs)}
      else
        {:noreply, put_flash(socket, :error, "Not authorized")}
      end
    else
      {:noreply, socket}
    end
  end

  defp default_metrics(base, "weight_reps"), do: Map.merge(base, %{"sets" => 3, "reps" => 10})
  defp default_metrics(base, "reps_only"), do: Map.merge(base, %{"sets" => 3, "reps" => 10})
  defp default_metrics(base, "duration"), do: Map.merge(base, %{"duration_seconds" => 60})
  defp default_metrics(base, "distance"), do: Map.merge(base, %{"duration_seconds" => 60})
  defp default_metrics(base, _), do: Map.merge(base, %{"sets" => 3, "reps" => 10})

  defp render_metric_inputs(assigns, log) do
    assigns = assign(assigns, :log, log)

    ~H"""
    <%= case @log.exercise.tracking_type do %>
      <% "weight_reps" -> %>
        <.metric_input log={@log} field="sets" label="Sets" width="w-20" />
        <.metric_input log={@log} field="reps" label="Reps" width="w-20" />
        <.metric_input log={@log} field="weight_kg" label="Weight (kg)" width="w-24" step="0.5" />
      <% "reps_only" -> %>
        <.metric_input log={@log} field="sets" label="Sets" width="w-20" />
        <.metric_input log={@log} field="reps" label="Reps" width="w-20" />
      <% "duration" -> %>
        <.metric_input log={@log} field="duration_seconds" label="Duration (s)" width="w-28" />
      <% "distance" -> %>
        <.metric_input log={@log} field="duration_seconds" label="Duration (s)" width="w-28" />
      <% _ -> %>
        <.metric_input log={@log} field="sets" label="Sets" width="w-20" />
        <.metric_input log={@log} field="reps" label="Reps" width="w-20" />
    <% end %>
    """
  end

  defp metric_input(assigns) do
    assigns = assign_new(assigns, :step, fn -> "1" end)

    ~H"""
    <div class="form-control">
      <label class="label py-0"><span class="label-text text-xs">{@label}</span></label>
      <input
        type="number"
        value={Map.get(@log, String.to_existing_atom(@field))}
        name={@field}
        class={"input input-bordered input-sm #{@width}"}
        min="0"
        step={@step}
      />
    </div>
    """
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Unknown"

  defp status_badge_class("confirmed"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-info"
  defp status_badge_class(_), do: "badge-ghost"
end
