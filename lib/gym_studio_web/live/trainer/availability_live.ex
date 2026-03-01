defmodule GymStudioWeb.Trainer.AvailabilityLive do
  use GymStudioWeb, :live_view

  alias GymStudio.Scheduling

  @day_names %{
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday",
    7 => "Sunday"
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(page_title: "My Availability")
      |> assign(trainer_id: user.id)
      |> assign(day_names: @day_names)
      |> assign(editing_day: nil)
      |> assign(show_time_off_form: false)
      |> load_data()

    {:ok, socket}
  end

  defp load_data(socket) do
    trainer_id = socket.assigns.trainer_id

    availabilities =
      Scheduling.list_trainer_availabilities(trainer_id)
      |> Enum.into(%{}, fn a -> {a.day_of_week, a} end)

    time_offs =
      Scheduling.list_trainer_time_offs(trainer_id, from_date: Date.utc_today())

    socket
    |> assign(availabilities: availabilities)
    |> assign(time_offs: time_offs)
  end

  @impl true
  def handle_event("edit_day", %{"day" => day_str}, socket) do
    day = String.to_integer(day_str)
    {:noreply, assign(socket, editing_day: day)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_day: nil)}
  end

  @impl true
  def handle_event("save_day", params, socket) do
    day = String.to_integer(params["day"])
    trainer_id = socket.assigns.trainer_id

    if params["off"] == "true" do
      Scheduling.delete_trainer_availability(trainer_id, day)

      socket =
        socket
        |> put_flash(:info, "#{@day_names[day]} marked as day off.")
        |> assign(editing_day: nil)
        |> load_data()

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
            |> put_flash(:info, "#{@day_names[day]} availability updated.")
            |> assign(editing_day: nil)
            |> load_data()

          {:noreply, socket}

        {:error, changeset} ->
          errors = format_errors(changeset)

          {:noreply, put_flash(socket, :error, "Error: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("toggle_time_off_form", _params, socket) do
    {:noreply, assign(socket, show_time_off_form: !socket.assigns.show_time_off_form)}
  end

  @impl true
  def handle_event("add_time_off", params, socket) do
    trainer_id = socket.assigns.trainer_id

    attrs = %{
      trainer_id: trainer_id,
      date: params["date"],
      reason: params["reason"]
    }

    attrs =
      if params["all_day"] == "true" do
        attrs
      else
        attrs
        |> Map.put(:start_time, parse_time(params["start_time"]))
        |> Map.put(:end_time, parse_time(params["end_time"]))
      end

    case Scheduling.create_time_off(attrs) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Time off added.")
          |> assign(show_time_off_form: false)
          |> load_data()

        {:noreply, socket}

      {:error, changeset} ->
        errors = format_errors(changeset)
        {:noreply, put_flash(socket, :error, "Error: #{errors}")}
    end
  end

  @impl true
  def handle_event("delete_time_off", %{"id" => id}, socket) do
    trainer_id = socket.assigns.trainer_id

    case Scheduling.get_time_off(id, trainer_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Time off not found.")}

      _time_off ->
        case Scheduling.delete_time_off(id) do
          {:ok, _} ->
            socket =
              socket
              |> put_flash(:info, "Time off deleted.")
              |> load_data()

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not delete time off.")}
        end
    end
  end

  defp parse_time(nil), do: nil
  defp parse_time(""), do: nil

  defp parse_time(str) when is_binary(str) do
    case Time.from_iso8601(str <> ":00") do
      {:ok, time} -> time
      _ -> nil
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, msgs} ->
      "#{Phoenix.Naming.humanize(field)}: #{Enum.join(msgs, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp format_time_display(nil), do: ""

  defp format_time_display(%Time{} = t) do
    Calendar.strftime(t, "%I:%M %p")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4 max-w-3xl">
        <h1 class="text-3xl font-bold text-gray-800 mb-6">My Availability</h1>

        <%!-- Weekly Schedule --%>
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Weekly Schedule</h2>

          <div class="space-y-3">
            <%= for day <- 1..7 do %>
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded-xl">
                <div class="flex-1">
                  <span class="font-semibold text-gray-700">{@day_names[day]}</span>
                  <%= if avail = @availabilities[day] do %>
                    <span class="ml-2 text-sm text-gray-500">
                      {format_time_display(avail.start_time)} - {format_time_display(avail.end_time)}
                    </span>
                  <% else %>
                    <span class="ml-2 text-sm text-gray-400 italic">Day Off</span>
                  <% end %>
                </div>

                <%= if @editing_day == day do %>
                  <form phx-submit="save_day" class="flex flex-wrap items-center gap-2">
                    <input type="hidden" name="day" value={day} />
                    <div class="flex items-center gap-1">
                      <input
                        type="time"
                        name="start_time"
                        class="input input-bordered input-sm w-32"
                        value={
                          if @availabilities[day],
                            do: Time.to_string(@availabilities[day].start_time) |> String.slice(0, 5),
                            else: "07:00"
                        }
                      />
                      <span class="text-gray-400">-</span>
                      <input
                        type="time"
                        name="end_time"
                        class="input input-bordered input-sm w-32"
                        value={
                          if @availabilities[day],
                            do: Time.to_string(@availabilities[day].end_time) |> String.slice(0, 5),
                            else: "22:00"
                        }
                      />
                    </div>
                    <button type="submit" class="btn btn-primary btn-sm">Save</button>
                    <button
                      type="submit"
                      name="off"
                      value="true"
                      class="btn btn-ghost btn-sm text-error"
                    >
                      Day Off
                    </button>
                    <button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-sm">
                      Cancel
                    </button>
                  </form>
                <% else %>
                  <button
                    type="button"
                    phx-click="edit_day"
                    phx-value-day={day}
                    class="btn btn-ghost btn-sm"
                  >
                    Edit
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Time Off Section --%>
        <div class="bg-white rounded-2xl shadow-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-gray-800">Time Off</h2>
            <button
              type="button"
              phx-click="toggle_time_off_form"
              class="btn btn-primary btn-sm"
            >
              {if @show_time_off_form, do: "Cancel", else: "+ Add Time Off"}
            </button>
          </div>

          <%= if @show_time_off_form do %>
            <form phx-submit="add_time_off" class="bg-gray-50 rounded-xl p-4 mb-4 space-y-3">
              <div class="form-control">
                <label class="label"><span class="label-text font-medium">Date</span></label>
                <input
                  type="date"
                  name="date"
                  class="input input-bordered"
                  min={Date.to_string(Date.utc_today())}
                  required
                />
              </div>

              <div class="form-control">
                <label class="label cursor-pointer justify-start gap-2">
                  <input
                    type="checkbox"
                    name="all_day"
                    value="true"
                    class="checkbox checkbox-primary"
                    checked
                  />
                  <span class="label-text">All Day</span>
                </label>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div class="form-control">
                  <label class="label"><span class="label-text">Start Time</span></label>
                  <input type="time" name="start_time" class="input input-bordered input-sm" />
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">End Time</span></label>
                  <input type="time" name="end_time" class="input input-bordered input-sm" />
                </div>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Reason (optional)</span></label>
                <input
                  type="text"
                  name="reason"
                  class="input input-bordered"
                  placeholder="e.g., Vacation, Personal"
                />
              </div>

              <button type="submit" class="btn btn-primary">Add Time Off</button>
            </form>
          <% end %>

          <%= if Enum.empty?(@time_offs) do %>
            <p class="text-gray-400 text-center py-4">No upcoming time off scheduled.</p>
          <% else %>
            <div class="space-y-2">
              <%= for to <- @time_offs do %>
                <div class="flex items-center justify-between p-3 bg-gray-50 rounded-xl">
                  <div>
                    <span class="font-medium text-gray-700">
                      {Calendar.strftime(to.date, "%A, %B %d, %Y")}
                    </span>
                    <%= if to.start_time && to.end_time do %>
                      <span class="text-sm text-gray-500 ml-2">
                        {format_time_display(to.start_time)} - {format_time_display(to.end_time)}
                      </span>
                    <% else %>
                      <span class="text-sm text-gray-400 ml-2">All Day</span>
                    <% end %>
                    <%= if to.reason do %>
                      <span class="text-sm text-gray-400 ml-2">— {to.reason}</span>
                    <% end %>
                  </div>
                  <button
                    type="button"
                    phx-click="delete_time_off"
                    phx-value-id={to.id}
                    class="btn btn-ghost btn-sm text-error"
                    data-confirm="Delete this time off?"
                  >
                    Delete
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
