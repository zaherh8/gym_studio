defmodule GymStudioWeb.Client.BookSessionLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Packages, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = Accounts.get_client_by_user_id(user.id)

    active_package =
      if client do
        case Packages.get_active_package_for_client(client.user_id) do
          {:ok, package} -> package
          {:error, :no_active_package} -> nil
        end
      else
        nil
      end

    # Load past bookings to find preferred times
    past_sessions =
      if client do
        Scheduling.list_sessions_for_client(user.id,
          status: "completed",
          preload: [:trainer]
        )
      else
        []
      end

    has_enough_history = length(past_sessions) >= 3

    preferred_hours =
      if has_enough_history, do: compute_preferred_hours(past_sessions), else: MapSet.new()

    preferred_trainer_id =
      if has_enough_history, do: compute_preferred_trainer(past_sessions), else: nil

    available_dates = generate_available_dates()
    selected_date = List.first(available_dates)

    socket =
      socket
      |> assign(page_title: "Book a Session")
      |> assign(client: client)
      |> assign(active_package: active_package)
      |> assign(available_dates: available_dates)
      |> assign(selected_date: selected_date)
      |> assign(available_slots: load_slots(selected_date))
      |> assign(selected_slot: nil)
      |> assign(selected_trainer_id: nil)
      |> assign(notes: "")
      |> assign(step: 1)
      |> assign(preferred_hours: preferred_hours)
      |> assign(preferred_trainer_id: preferred_trainer_id)

    {:ok, socket}
  end

  defp compute_preferred_hours(sessions) do
    sessions
    |> Enum.map(fn s -> DateTime.to_time(s.scheduled_at).hour end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_h, count} -> -count end)
    |> Enum.take(3)
    |> Enum.map(fn {h, _} -> h end)
    |> MapSet.new()
  end

  defp compute_preferred_trainer(sessions) do
    sessions
    |> Enum.map(& &1.trainer_id)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        socket =
          socket
          |> assign(selected_date: date)
          |> assign(available_slots: load_slots(date))
          |> assign(selected_slot: nil)
          |> assign(selected_trainer_id: nil)
          |> assign(step: 2)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_slot", %{"slot" => slot, "trainer" => trainer_id}, socket) do
    socket =
      socket
      |> assign(selected_slot: slot)
      |> assign(selected_trainer_id: trainer_id)
      |> assign(step: 3)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, notes: notes)}
  end

  @impl true
  def handle_event("confirm_booking", _params, socket) do
    user = socket.assigns.current_scope.user
    selected_date = socket.assigns.selected_date
    selected_slot = socket.assigns.selected_slot
    selected_trainer_id = socket.assigns.selected_trainer_id
    active_package = socket.assigns.active_package

    cond do
      is_nil(active_package) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You need an active package to book a session. Please contact your trainer."
         )}

      active_package.remaining_sessions <= 0 ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No remaining sessions in your package. Please contact your trainer to purchase a new one."
         )}

      is_nil(selected_slot) ->
        {:noreply, put_flash(socket, :error, "Please select a time slot.")}

      true ->
        {hour, _} = Integer.parse(selected_slot)
        scheduled_at = DateTime.new!(selected_date, Time.new!(hour, 0, 0), "Etc/UTC")

        booking_attrs = %{
          client_id: user.id,
          trainer_id: selected_trainer_id,
          scheduled_at: scheduled_at,
          duration_minutes: 60,
          notes: if(socket.assigns.notes != "", do: socket.assigns.notes, else: nil)
        }

        case Scheduling.book_session(booking_attrs) do
          {:ok, _session} ->
            socket =
              socket
              |> put_flash(
                :info,
                "Session booked successfully! You'll be notified once confirmed."
              )
              |> push_navigate(to: ~p"/client/sessions")

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not book session. Please try again.")}
        end
    end
  end

  @impl true
  def handle_event("back_to_date", _params, socket) do
    {:noreply, assign(socket, step: 1, selected_slot: nil, selected_trainer_id: nil)}
  end

  @impl true
  def handle_event("back_to_time", _params, socket) do
    {:noreply, assign(socket, step: 2)}
  end

  defp load_slots(nil), do: []

  defp load_slots(date) do
    Scheduling.get_all_available_slots(date)
  end

  defp generate_available_dates do
    today = Date.utc_today()
    Enum.map(0..13, &Date.add(today, &1))
  end

  defp format_time(hour) when hour == 0, do: "12:00 AM"
  defp format_time(hour) when hour < 12, do: "#{hour}:00 AM"
  defp format_time(12), do: "12:00 PM"
  defp format_time(hour), do: "#{hour - 12}:00 PM"

  defp format_date_full(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp selected_trainer_name(assigns) do
    case Enum.find(assigns.available_slots, fn s ->
           s.value == assigns.selected_slot && s.trainer_id == assigns.selected_trainer_id
         end) do
      nil -> "Unassigned"
      slot -> slot.trainer_name
    end
  end

  # Group slots by trainer for visual display
  defp group_slots_by_trainer(slots) do
    slots
    |> Enum.group_by(fn s -> {s.trainer_id, s.trainer_name} end)
    |> Enum.sort_by(fn {{_id, name}, _} -> name end)
  end

  defp is_recommended?(slot, preferred_hours, _preferred_trainer_id) do
    hour = String.to_integer(slot.value)
    MapSet.member?(preferred_hours, hour)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-8">
      <div class="container mx-auto px-4">
        <div class="max-w-2xl mx-auto">
          <!-- Header -->
          <div class="text-center mb-8">
            <h1 class="text-3xl font-bold mb-2">Book a Session</h1>
            <p class="text-base-content/60">Select your preferred date and time</p>
          </div>

          <%= if @client == nil do %>
            <div class="card bg-base-100 shadow-lg p-8 text-center">
              <div class="text-warning mb-4">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-16 w-16 mx-auto"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              </div>
              <h2 class="text-xl font-semibold mb-2">Profile Setup Required</h2>
              <p class="text-base-content/60">
                Your client profile is not set up yet. Please contact an administrator.
              </p>
            </div>
          <% else %>
            <%= if is_nil(@active_package) do %>
              <div class="alert alert-warning mb-6">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6 shrink-0"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <div>
                  <h3 class="font-bold">No Active Package</h3>
                  <p class="text-sm">
                    You need an active package with remaining sessions to book. Contact your trainer to get started.
                  </p>
                </div>
              </div>
            <% end %>
            <%= if @active_package && @active_package.remaining_sessions <= 0 do %>
              <div class="alert alert-error mb-6">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6 shrink-0"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <div>
                  <h3 class="font-bold">No Remaining Sessions</h3>
                  <p class="text-sm">
                    All sessions in your current package have been used. Please purchase a new package.
                  </p>
                </div>
              </div>
            <% end %>
            
    <!-- Progress Steps -->
            <div class="flex justify-center mb-8">
              <div class="flex items-center space-x-4">
                <div class={"flex items-center justify-center w-10 h-10 rounded-full font-semibold #{if @step >= 1, do: "bg-primary text-primary-content", else: "bg-base-300 text-base-content/60"}"}>
                  1
                </div>
                <div class={"w-16 h-1 #{if @step >= 2, do: "bg-primary", else: "bg-base-300"}"}></div>
                <div class={"flex items-center justify-center w-10 h-10 rounded-full font-semibold #{if @step >= 2, do: "bg-primary text-primary-content", else: "bg-base-300 text-base-content/60"}"}>
                  2
                </div>
                <div class={"w-16 h-1 #{if @step >= 3, do: "bg-primary", else: "bg-base-300"}"}></div>
                <div class={"flex items-center justify-center w-10 h-10 rounded-full font-semibold #{if @step >= 3, do: "bg-primary text-primary-content", else: "bg-base-300 text-base-content/60"}"}>
                  3
                </div>
              </div>
            </div>
            
    <!-- Step 1: Select Date -->
            <div class={"card bg-base-100 shadow-lg p-6 mb-6 #{if @step != 1, do: "opacity-60"}"}>
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-semibold flex items-center gap-2">
                  📅 Select Date
                </h2>
                <%= if @step > 1 do %>
                  <button phx-click="back_to_date" class="text-primary hover:underline text-sm">
                    Change
                  </button>
                <% end %>
              </div>

              <%= if @step == 1 do %>
                <div class="overflow-x-auto pb-2">
                  <div class="flex gap-3" style="min-width: max-content;">
                    <%= for date <- @available_dates do %>
                      <button
                        type="button"
                        phx-click="select_date"
                        phx-value-date={Date.to_string(date)}
                        class={"flex flex-col items-center justify-center p-4 rounded-xl border-2 transition-all min-w-[80px] #{if @selected_date == date, do: "border-primary bg-primary/10 text-primary", else: "border-base-300 hover:border-primary/50"}"}
                      >
                        <span class="text-xs font-medium uppercase text-base-content/50">
                          {Calendar.strftime(date, "%a")}
                        </span>
                        <span class="text-2xl font-bold">{Calendar.strftime(date, "%d")}</span>
                        <span class="text-xs text-base-content/50">
                          {Calendar.strftime(date, "%b")}
                        </span>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <p class="font-medium">{format_date_full(@selected_date)}</p>
              <% end %>
            </div>
            
    <!-- Step 2: Select Time & Trainer (Grouped by Trainer) -->
            <div class={"card bg-base-100 shadow-lg p-6 mb-6 #{if @step < 2, do: "opacity-40 pointer-events-none"}"}>
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-semibold flex items-center gap-2">
                  🕐 Select Time & Trainer
                </h2>
                <%= if @step > 2 do %>
                  <button phx-click="back_to_time" class="text-primary hover:underline text-sm">
                    Change
                  </button>
                <% end %>
              </div>

              <%= if @step == 2 do %>
                <%= if Enum.empty?(@available_slots) do %>
                  <div class="text-center py-6">
                    <p class="text-base-content/50 mb-2">No trainers available on this date.</p>
                    <p class="text-sm text-base-content/30">Try selecting a different date.</p>
                  </div>
                <% else %>
                  <div class="space-y-6">
                    <%= for {{trainer_id, trainer_name}, slots} <- group_slots_by_trainer(@available_slots) do %>
                      <div>
                        <div class="flex items-center gap-2 mb-3">
                          <div class="avatar placeholder">
                            <div class="bg-primary text-primary-content rounded-full w-8">
                              <span class="text-xs">{String.first(trainer_name || "?")}</span>
                            </div>
                          </div>
                          <span class="font-semibold">{trainer_name}</span>
                          <%= if trainer_id == @preferred_trainer_id do %>
                            <span class="badge badge-primary badge-xs">Preferred</span>
                          <% end %>
                        </div>
                        <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                          <%= for slot <- Enum.sort_by(slots, & &1.value) do %>
                            <% recommended =
                              is_recommended?(slot, @preferred_hours, @preferred_trainer_id) %>
                            <button
                              type="button"
                              phx-click="select_slot"
                              phx-value-slot={slot.value}
                              phx-value-trainer={slot.trainer_id}
                              class={"py-2.5 px-3 rounded-xl border-2 text-center transition-all relative #{cond do
                                @selected_slot == slot.value && @selected_trainer_id == slot.trainer_id -> "border-primary bg-primary text-primary-content"
                                recommended -> "border-primary/30 bg-primary/5 hover:border-primary/50"
                                true -> "border-base-300 hover:border-primary/50"
                              end}"}
                            >
                              <div class="font-medium text-sm">{slot.label}</div>
                              <%= if recommended and not (@selected_slot == slot.value && @selected_trainer_id == slot.trainer_id) do %>
                                <div class="text-[10px] text-primary font-medium">★ Recommended</div>
                              <% end %>
                            </button>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% else %>
                <%= if @selected_slot do %>
                  <p class="font-medium">
                    {format_time(String.to_integer(@selected_slot))} - {format_time(
                      String.to_integer(@selected_slot) + 1
                    )}
                    <span class="text-base-content/50 ml-1">
                      with {selected_trainer_name(assigns)}
                    </span>
                  </p>
                <% end %>
              <% end %>
            </div>
            
    <!-- Step 3: Confirm -->
            <div class={"card bg-base-100 shadow-lg p-6 #{if @step < 3, do: "opacity-40 pointer-events-none"}"}>
              <h2 class="text-xl font-semibold flex items-center gap-2 mb-4">
                ✅ Confirm Booking
              </h2>

              <%= if @step == 3 do %>
                <div class="bg-base-200 rounded-xl p-4 mb-4 space-y-3">
                  <div class="flex items-center gap-4">
                    <div class="bg-primary/10 p-3 rounded-lg">📅</div>
                    <div>
                      <p class="text-sm text-base-content/50">Date</p>
                      <p class="font-semibold">{format_date_full(@selected_date)}</p>
                    </div>
                  </div>
                  <div class="flex items-center gap-4">
                    <div class="bg-primary/10 p-3 rounded-lg">🕐</div>
                    <div>
                      <p class="text-sm text-base-content/50">Time</p>
                      <p class="font-semibold">
                        {format_time(String.to_integer(@selected_slot))} - {format_time(
                          String.to_integer(@selected_slot) + 1
                        )}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center gap-4">
                    <div class="bg-primary/10 p-3 rounded-lg">👤</div>
                    <div>
                      <p class="text-sm text-base-content/50">Trainer</p>
                      <p class="font-semibold">{selected_trainer_name(assigns)}</p>
                    </div>
                  </div>
                </div>

                <div class="form-control mb-4">
                  <label class="label">
                    <span class="label-text font-medium">Session Notes (optional)</span>
                  </label>
                  <textarea
                    phx-change="update_notes"
                    name="notes"
                    class="textarea textarea-bordered h-20"
                    placeholder="Any goals or notes for this session..."
                  >{@notes}</textarea>
                </div>

                <button
                  type="button"
                  phx-click="confirm_booking"
                  class="w-full btn btn-primary btn-lg"
                >
                  Confirm Booking
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
