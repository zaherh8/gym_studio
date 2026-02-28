defmodule GymStudioWeb.Trainer.ClientMetricsLive do
  @moduledoc """
  Trainer read-only view of a client's body metrics and weight chart.
  Reuses logic from `GymStudio.Metrics`.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Metrics, Scheduling}

  @impl true
  def mount(%{"client_id" => client_id}, _session, socket) do
    trainer = socket.assigns.current_scope.user

    if Scheduling.trainer_has_client?(trainer.id, client_id) do
      client = Accounts.get_user!(client_id)
      metrics = Metrics.list_metrics(client_id)
      chart_data = build_weight_chart_data(client_id)

      socket =
        socket
        |> assign(page_title: "#{client.name || "Client"}'s Body Metrics")
        |> assign(client: client)
        |> assign(metrics: metrics)
        |> assign(chart_data: chart_data)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Not authorized to view this client's metrics.")
        |> redirect(to: ~p"/trainer/clients")

      {:ok, socket}
    end
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
          <.link navigate={~p"/trainer/clients/#{@client.id}/progress"} class="btn btn-ghost btn-sm">
            ← Back to Progress
          </.link>
          <div>
            <h1 class="text-2xl md:text-3xl font-bold text-gray-800">
              {@client.name || "Client"}'s Body Metrics
            </h1>
            <p class="text-gray-600 mt-1">Weight, body fat, and measurements</p>
          </div>
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
            <p class="text-gray-500">No entries yet.</p>
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
