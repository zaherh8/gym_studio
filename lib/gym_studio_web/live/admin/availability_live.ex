defmodule GymStudioWeb.Admin.AvailabilityLive do
  use GymStudioWeb, :live_view

  alias GymStudio.Scheduling

  @day_names %{
    1 => "Mon",
    2 => "Tue",
    3 => "Wed",
    4 => "Thu",
    5 => "Fri",
    6 => "Sat",
    7 => "Sun"
  }

  @impl true
  def mount(_params, _session, socket) do
    trainers = Scheduling.list_trainers_with_availability()

    # Build availability map: %{trainer_id => %{day => availability}}
    availability_map =
      Enum.into(trainers, %{}, fn %{trainer_id: tid} ->
        avails =
          Scheduling.list_trainer_availabilities(tid)
          |> Enum.into(%{}, fn a -> {a.day_of_week, a} end)

        {tid, avails}
      end)

    socket =
      socket
      |> assign(page_title: "Trainer Availability")
      |> assign(trainers: trainers)
      |> assign(availability_map: availability_map)
      |> assign(day_names: @day_names)
      |> assign(editing: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("edit", %{"trainer" => trainer_id, "day" => day_str}, socket) do
    day = String.to_integer(day_str)
    {:noreply, assign(socket, editing: {trainer_id, day})}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil)}
  end

  @impl true
  def handle_event("save_availability", params, socket) do
    trainer_id = params["trainer_id"]
    day = String.to_integer(params["day"])

    if params["off"] == "true" do
      Scheduling.delete_trainer_availability(trainer_id, day)

      socket =
        socket
        |> put_flash(:info, "Day off set.")
        |> assign(editing: nil)
        |> reload_data()

      {:noreply, socket}
    else
      attrs = %{
        start_time: parse_time(params["start_time"]),
        end_time: parse_time(params["end_time"]),
        active: true
      }

      case Scheduling.set_trainer_availability(trainer_id, day, attrs) do
        {:ok, _} ->
          socket =
            socket
            |> put_flash(:info, "Availability updated.")
            |> assign(editing: nil)
            |> reload_data()

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Invalid time range.")}
      end
    end
  end

  defp reload_data(socket) do
    trainers = Scheduling.list_trainers_with_availability()

    availability_map =
      Enum.into(trainers, %{}, fn %{trainer_id: tid} ->
        avails =
          Scheduling.list_trainer_availabilities(tid)
          |> Enum.into(%{}, fn a -> {a.day_of_week, a} end)

        {tid, avails}
      end)

    assign(socket, trainers: trainers, availability_map: availability_map)
  end

  defp parse_time(nil), do: nil
  defp parse_time(""), do: nil

  defp parse_time(str) when is_binary(str) do
    case Time.from_iso8601(str <> ":00") do
      {:ok, time} -> time
      _ -> nil
    end
  end

  defp format_time_short(nil), do: "-"

  defp format_time_short(%Time{} = t) do
    Calendar.strftime(t, "%H:%M")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <h1 class="text-3xl font-bold text-gray-800 mb-6">Trainer Availability</h1>

        <%= if Enum.empty?(@trainers) do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <p class="text-gray-500">No trainers have availability configured yet.</p>
          </div>
        <% else %>
          <div class="bg-white rounded-2xl shadow-lg overflow-x-auto">
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Trainer</th>
                  <%= for day <- 1..7 do %>
                    <th class="text-center">{@day_names[day]}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <%= for trainer <- @trainers do %>
                  <tr>
                    <td class="font-medium">{trainer.trainer_name || "Unknown"}</td>
                    <%= for day <- 1..7 do %>
                      <td class="text-center text-sm">
                        <%= if @editing == {trainer.trainer_id, day} do %>
                          <form phx-submit="save_availability" class="space-y-1">
                            <input type="hidden" name="trainer_id" value={trainer.trainer_id} />
                            <input type="hidden" name="day" value={day} />
                            <input
                              type="time"
                              name="start_time"
                              class="input input-bordered input-xs w-24"
                              value={
                                if avail = @availability_map[trainer.trainer_id][day],
                                  do: format_time_short(avail.start_time),
                                  else: "07:00"
                              }
                            />
                            <input
                              type="time"
                              name="end_time"
                              class="input input-bordered input-xs w-24"
                              value={
                                if avail = @availability_map[trainer.trainer_id][day],
                                  do: format_time_short(avail.end_time),
                                  else: "22:00"
                              }
                            />
                            <div class="flex gap-1 justify-center">
                              <button type="submit" class="btn btn-primary btn-xs">Save</button>
                              <button type="submit" name="off" value="true" class="btn btn-xs">
                                Off
                              </button>
                              <button
                                type="button"
                                phx-click="cancel_edit"
                                class="btn btn-ghost btn-xs"
                              >
                                ✕
                              </button>
                            </div>
                          </form>
                        <% else %>
                          <%= if avail = @availability_map[trainer.trainer_id][day] do %>
                            <button
                              type="button"
                              phx-click="edit"
                              phx-value-trainer={trainer.trainer_id}
                              phx-value-day={day}
                              class="text-xs hover:text-primary cursor-pointer"
                            >
                              {format_time_short(avail.start_time)}-{format_time_short(avail.end_time)}
                            </button>
                          <% else %>
                            <button
                              type="button"
                              phx-click="edit"
                              phx-value-trainer={trainer.trainer_id}
                              phx-value-day={day}
                              class="text-xs text-gray-300 hover:text-primary cursor-pointer"
                            >
                              Off
                            </button>
                          <% end %>
                        <% end %>
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
