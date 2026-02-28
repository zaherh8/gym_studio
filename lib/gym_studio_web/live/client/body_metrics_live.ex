defmodule GymStudioWeb.Client.BodyMetricsLive do
  @moduledoc """
  Client body metrics page — log weight, body fat %, and measurements.
  Displays a weight chart and history table with edit/delete.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Metrics
  alias GymStudio.Metrics.BodyMetric

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    metrics = Metrics.list_metrics(user.id)
    chart_data = build_weight_chart_data(user.id)

    socket =
      socket
      |> assign(page_title: "Body Metrics")
      |> assign(metrics: metrics)
      |> assign(chart_data: chart_data)
      |> assign(editing: nil)
      |> assign_new_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("save", %{"body_metric" => params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      params
      |> Map.put("user_id", user.id)
      |> Map.put("logged_by_id", user.id)

    result =
      case socket.assigns.editing do
        nil -> Metrics.create_metric(attrs)
        metric -> Metrics.update_metric(metric, attrs)
      end

    case result do
      {:ok, _metric} ->
        metrics = Metrics.list_metrics(user.id)
        chart_data = build_weight_chart_data(user.id)

        socket =
          socket
          |> assign(metrics: metrics, chart_data: chart_data, editing: nil)
          |> assign_new_form()
          |> put_flash(:info, "Body metric saved successfully.")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    metric = Metrics.get_metric!(id)

    if metric.user_id != user.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      changeset = Metrics.change_metric(metric)

      {:noreply,
       socket
       |> assign(editing: metric)
       |> assign(form: to_form(changeset))}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(editing: nil)
     |> assign_new_form()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    metric = Metrics.get_metric!(id)

    if metric.user_id != user.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      {:ok, _} = Metrics.delete_metric(metric)
      metrics = Metrics.list_metrics(user.id)
      chart_data = build_weight_chart_data(user.id)

      {:noreply,
       socket
       |> assign(metrics: metrics, chart_data: chart_data, editing: nil)
       |> assign_new_form()
       |> put_flash(:info, "Body metric deleted.")}
    end
  end

  defp assign_new_form(socket) do
    changeset = Metrics.change_metric(%BodyMetric{date: Date.utc_today()})
    assign(socket, form: to_form(changeset))
  end

  defp build_weight_chart_data(user_id) do
    history = Metrics.get_metric_history(user_id, :weight_kg)

    labels = Enum.map(history, fn {date, _} -> Date.to_string(date) end)

    values =
      Enum.map(history, fn {_, value} -> Decimal.to_float(value) end)

    Jason.encode!(%{labels: labels, values: values, y_label: "Weight (kg)"})
  end

  defp format_decimal(nil), do: "—"
  defp format_decimal(val), do: Decimal.to_string(val)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <div class="mb-6 flex items-center gap-4">
          <.link navigate={~p"/client/progress"} class="btn btn-ghost btn-sm">
            ← Back to Progress
          </.link>
          <div>
            <h1 class="text-2xl md:text-3xl font-bold text-gray-800">Body Metrics</h1>
            <p class="text-gray-600 mt-1">Track your weight, body fat, and measurements</p>
          </div>
        </div>

        <%!-- Log / Edit Form --%>
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <h2 class="text-lg font-semibold mb-4">
            {if @editing, do: "Edit Entry", else: "Log New Entry"}
          </h2>
          <form phx-submit="save" class="space-y-4">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Date</span></label>
                <input
                  type="date"
                  name="body_metric[date]"
                  value={Phoenix.HTML.Form.input_value(@form, :date)}
                  class="input input-bordered w-full"
                  required
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Weight (kg)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[weight_kg]"
                  value={Phoenix.HTML.Form.input_value(@form, :weight_kg)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 75.5"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Body Fat %</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[body_fat_pct]"
                  value={Phoenix.HTML.Form.input_value(@form, :body_fat_pct)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 15.0"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Chest (cm)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[chest_cm]"
                  value={Phoenix.HTML.Form.input_value(@form, :chest_cm)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 100"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Waist (cm)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[waist_cm]"
                  value={Phoenix.HTML.Form.input_value(@form, :waist_cm)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 80"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Hips (cm)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[hips_cm]"
                  value={Phoenix.HTML.Form.input_value(@form, :hips_cm)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 95"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Bicep (cm)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[bicep_cm]"
                  value={Phoenix.HTML.Form.input_value(@form, :bicep_cm)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 35"
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Thigh (cm)</span></label>
                <input
                  type="number"
                  step="0.1"
                  name="body_metric[thigh_cm]"
                  value={Phoenix.HTML.Form.input_value(@form, :thigh_cm)}
                  class="input input-bordered w-full"
                  placeholder="e.g. 55"
                />
              </div>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Notes</span></label>
              <textarea
                name="body_metric[notes]"
                class="textarea textarea-bordered w-full"
                rows="2"
                placeholder="Optional notes..."
              >{Phoenix.HTML.Form.input_value(@form, :notes)}</textarea>
            </div>

            <%= for {field, {msg, _opts}} <- @form.errors do %>
              <p class="text-error text-sm">{Phoenix.Naming.humanize(field)}: {msg}</p>
            <% end %>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                {if @editing, do: "Update", else: "Save"}
              </button>
              <%= if @editing do %>
                <button type="button" phx-click="cancel_edit" class="btn btn-ghost">Cancel</button>
              <% end %>
            </div>
          </form>
        </div>

        <%!-- Weight Chart --%>
        <%= if @metrics != [] and Enum.any?(@metrics, & &1.weight_kg) do %>
          <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
            <h2 class="text-lg font-semibold mb-4">Weight Over Time</h2>
            <div id="weight-chart" phx-hook="ProgressChart" data-chart={@chart_data}>
              <canvas></canvas>
            </div>
          </div>
        <% end %>

        <%!-- History Table --%>
        <div class="bg-white rounded-2xl shadow-lg p-6">
          <h2 class="text-lg font-semibold mb-4">History</h2>
          <%= if @metrics == [] do %>
            <p class="text-gray-500">No entries yet. Log your first measurement above!</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Weight</th>
                    <th>Body Fat</th>
                    <th>Chest</th>
                    <th>Waist</th>
                    <th>Hips</th>
                    <th>Bicep</th>
                    <th>Thigh</th>
                    <th>Notes</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for metric <- @metrics do %>
                    <tr>
                      <td>{metric.date}</td>
                      <td>{format_decimal(metric.weight_kg)}</td>
                      <td>{format_decimal(metric.body_fat_pct)}</td>
                      <td>{format_decimal(metric.chest_cm)}</td>
                      <td>{format_decimal(metric.waist_cm)}</td>
                      <td>{format_decimal(metric.hips_cm)}</td>
                      <td>{format_decimal(metric.bicep_cm)}</td>
                      <td>{format_decimal(metric.thigh_cm)}</td>
                      <td class="max-w-[200px] truncate">{metric.notes || "—"}</td>
                      <td class="flex gap-1">
                        <button phx-click="edit" phx-value-id={metric.id} class="btn btn-xs btn-ghost">
                          ✏️
                        </button>
                        <button
                          phx-click="delete"
                          phx-value-id={metric.id}
                          data-confirm="Delete this entry?"
                          class="btn btn-xs btn-ghost text-error"
                        >
                          🗑️
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
