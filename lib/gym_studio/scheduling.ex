defmodule GymStudio.Scheduling do
  @moduledoc """
  The Scheduling context manages training sessions and time slots.

  ## Booking Flow
  1. Client books a session using `book_session/2` (status: pending)
  2. Admin/Trainer approves using `approve_session/3` (status: confirmed, assigns trainer)
  3. After session, trainer marks complete using `complete_session/2` (status: completed)
  4. Sessions can be cancelled using `cancel_session/3` or marked no-show using `mark_no_show/1`
  """

  import Ecto.Query, warn: false
  alias GymStudio.Repo

  alias GymStudio.Scheduling.TrainingSession
  alias GymStudio.Scheduling.TimeSlot
  alias GymStudio.Scheduling.TrainerAvailability
  alias GymStudio.Scheduling.TrainerTimeOff

  # Training Session functions

  @doc """
  Books a new training session for a client.

  The session is created with "pending" status and awaits admin/trainer approval.

  ## Examples

      iex> book_session(%{client_id: client.id, scheduled_at: ~U[2026-02-01 10:00:00Z], duration_minutes: 60})
      {:ok, %TrainingSession{}}

      iex> book_session(%{})
      {:error, %Ecto.Changeset{}}
  """
  def book_session(attrs \\ %{}) do
    result =
      %TrainingSession{}
      |> TrainingSession.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, session} ->
        # Notify the client that their session is booked (pending)
        GymStudio.Notifications.create_notification(%{
          user_id: session.client_id,
          title: "Session Booked",
          message:
            "Your session on #{Calendar.strftime(session.scheduled_at, "%A, %B %d at %I:%M %p")} has been booked and is pending confirmation.",
          type: "booking_created",
          action_url: "/client/sessions",
          metadata: %{session_id: session.id}
        })

        result

      _ ->
        result
    end
  end

  @doc """
  Approves a pending training session and assigns a trainer.

  ## Parameters
  - `session` - The TrainingSession struct to approve
  - `trainer_id` - The ID of the trainer to assign
  - `approved_by_id` - The ID of the user (admin/trainer) approving the session

  ## Examples

      iex> approve_session(session, trainer.id, admin.id)
      {:ok, %TrainingSession{}}

      iex> approve_session(completed_session, trainer.id, admin.id)
      {:error, %Ecto.Changeset{}}
  """
  def approve_session(%TrainingSession{} = session, trainer_id, approved_by_id) do
    result =
      session
      |> TrainingSession.approval_changeset(%{
        trainer_id: trainer_id,
        approved_by_id: approved_by_id
      })
      |> Repo.update()

    case result do
      {:ok, updated_session} ->
        GymStudio.Notifications.notify_booking_confirmed(
          updated_session.client_id,
          updated_session
        )

        result

      _ ->
        result
    end
  end

  @doc """
  Cancels a training session.

  ## Parameters
  - `session` - The TrainingSession struct to cancel
  - `cancelled_by_id` - The ID of the user cancelling the session
  - `reason` - The reason for cancellation

  ## Examples

      iex> cancel_session(session, user.id, "Client requested cancellation")
      {:ok, %TrainingSession{}}
  """
  def cancel_session(%TrainingSession{} = session, cancelled_by_id, reason) do
    result =
      session
      |> TrainingSession.cancellation_changeset(%{
        cancelled_by_id: cancelled_by_id,
        cancellation_reason: reason
      })
      |> Repo.update()

    case result do
      {:ok, updated_session} ->
        GymStudio.Notifications.notify_booking_cancelled(
          updated_session.client_id,
          updated_session,
          reason
        )

        result

      _ ->
        result
    end
  end

  @doc """
  Marks a confirmed training session as completed.

  Optionally includes trainer notes about the session.

  ## Examples

      iex> complete_session(session, %{trainer_notes: "Great progress today"})
      {:ok, %TrainingSession{}}

      iex> complete_session(pending_session, %{})
      {:error, %Ecto.Changeset{}}
  """
  def complete_session(%TrainingSession{} = session, attrs \\ %{}) do
    result =
      session
      |> TrainingSession.completion_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_session} ->
        GymStudio.Notifications.create_notification(%{
          user_id: updated_session.client_id,
          title: "Session Completed",
          message:
            "Your session on #{Calendar.strftime(updated_session.scheduled_at, "%A, %B %d at %I:%M %p")} has been marked as completed.",
          type: "session_completed",
          action_url: "/client/sessions",
          metadata: %{session_id: updated_session.id}
        })

        result

      _ ->
        result
    end
  end

  @doc """
  Marks a confirmed training session as no-show.

  Used when a client doesn't attend their scheduled session.

  ## Examples

      iex> mark_no_show(session)
      {:ok, %TrainingSession{}}
  """
  def mark_no_show(%TrainingSession{} = session) do
    session
    |> TrainingSession.no_show_changeset()
    |> Repo.update()
  end

  @doc """
  Gets a single training session.

  Raises `Ecto.NoResultsError` if the Training session does not exist.

  ## Examples

      iex> get_session!(123)
      %TrainingSession{}

      iex> get_session!(456)
      ** (Ecto.NoResultsError)
  """
  def get_session!(id) do
    TrainingSession
    |> preload([:client, :trainer, :package, :approved_by, :cancelled_by])
    |> Repo.get!(id)
  end

  @doc """
  Lists training sessions for a specific client.

  ## Options
  - `:status` - Filter by status (e.g., "pending", "confirmed")
  - `:from_date` - Only sessions scheduled on or after this date
  - `:to_date` - Only sessions scheduled on or before this date
  - `:preload` - List of associations to preload (default: [:trainer, :package])

  ## Examples

      iex> list_sessions_for_client(client.id, status: "confirmed")
      [%TrainingSession{}, ...]

      iex> list_sessions_for_client(client.id, from_date: ~U[2026-02-01 00:00:00Z])
      [%TrainingSession{}, ...]
  """
  def list_sessions_for_client(client_id, opts \\ []) do
    TrainingSession
    |> where([s], s.client_id == ^client_id)
    |> filter_by_status(opts[:status])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([s], desc: s.scheduled_at)
    |> preload(^Keyword.get(opts, :preload, [:trainer, :package]))
    |> Repo.all()
  end

  @doc """
  Lists training sessions for a specific trainer.

  ## Options
  - `:status` - Filter by status (e.g., "pending", "confirmed")
  - `:from_date` - Only sessions scheduled on or after this date
  - `:to_date` - Only sessions scheduled on or before this date
  - `:preload` - List of associations to preload (default: [:client, :package])

  ## Examples

      iex> list_sessions_for_trainer(trainer.id, status: "confirmed")
      [%TrainingSession{}, ...]
  """
  def list_sessions_for_trainer(trainer_id, opts \\ []) do
    TrainingSession
    |> where([s], s.trainer_id == ^trainer_id)
    |> filter_by_status(opts[:status])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([s], desc: s.scheduled_at)
    |> preload(^Keyword.get(opts, :preload, [:client, :package]))
    |> Repo.all()
  end

  @doc """
  Lists all pending training sessions.

  Used by admins to see sessions awaiting approval.

  ## Examples

      iex> list_pending_sessions()
      [%TrainingSession{}, ...]
  """
  def list_pending_sessions do
    TrainingSession
    |> where([s], s.status == "pending")
    |> order_by([s], asc: s.scheduled_at)
    |> preload([:client, :package])
    |> Repo.all()
  end

  @doc """
  Lists upcoming training sessions within the next N days.

  ## Parameters
  - `days` - Number of days to look ahead (default: 7)

  ## Examples

      iex> list_upcoming_sessions(7)
      [%TrainingSession{}, ...]
  """
  def list_upcoming_sessions(days \\ 7) do
    now = DateTime.utc_now()
    future = DateTime.add(now, days, :day)

    TrainingSession
    |> where([s], s.status in ["pending", "confirmed"])
    |> where([s], s.scheduled_at >= ^now and s.scheduled_at <= ^future)
    |> order_by([s], asc: s.scheduled_at)
    |> preload([:client, :trainer, :package])
    |> Repo.all()
  end

  @doc """
  Gets available time slots for a given date.

  Returns active time slots that match the day of the week for the given date.

  ## Examples

      iex> get_available_slots(~D[2026-02-10])
      [%TimeSlot{}, ...]
  """
  def get_available_slots(%Date{} = date) do
    day_of_week = Date.day_of_week(date)

    TimeSlot
    |> where([ts], ts.day_of_week == ^day_of_week and ts.active == true)
    |> order_by([ts], asc: ts.start_time)
    |> Repo.all()
  end

  # Time Slot functions

  @doc """
  Creates a time slot.

  ## Examples

      iex> create_time_slot(%{day_of_week: 1, start_time: ~T[09:00:00], end_time: ~T[10:00:00]})
      {:ok, %TimeSlot{}}

      iex> create_time_slot(%{})
      {:error, %Ecto.Changeset{}}
  """
  def create_time_slot(attrs \\ %{}) do
    %TimeSlot{}
    |> TimeSlot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a time slot.

  ## Examples

      iex> update_time_slot(time_slot, %{active: false})
      {:ok, %TimeSlot{}}

      iex> update_time_slot(time_slot, %{day_of_week: 0})
      {:error, %Ecto.Changeset{}}
  """
  def update_time_slot(%TimeSlot{} = time_slot, attrs) do
    time_slot
    |> TimeSlot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all time slots.

  ## Options
  - `:active_only` - Only return active time slots (default: false)

  ## Examples

      iex> list_time_slots()
      [%TimeSlot{}, ...]

      iex> list_time_slots(active_only: true)
      [%TimeSlot{}, ...]
  """
  def list_time_slots(opts \\ []) do
    query = TimeSlot

    query =
      if Keyword.get(opts, :active_only, false) do
        where(query, [ts], ts.active == true)
      else
        query
      end

    query
    |> order_by([ts], asc: ts.day_of_week, asc: ts.start_time)
    |> Repo.all()
  end

  @doc """
  Gets a single time slot.

  Raises `Ecto.NoResultsError` if the Time slot does not exist.

  ## Examples

      iex> get_time_slot!(123)
      %TimeSlot{}

      iex> get_time_slot!(456)
      ** (Ecto.NoResultsError)
  """
  def get_time_slot!(id), do: Repo.get!(TimeSlot, id)

  @doc """
  Deletes a time slot.

  ## Examples

      iex> delete_time_slot(time_slot)
      {:ok, %TimeSlot{}}

      iex> delete_time_slot(time_slot)
      {:error, %Ecto.Changeset{}}
  """
  def delete_time_slot(%TimeSlot{} = time_slot) do
    Repo.delete(time_slot)
  end

  # Additional trainer/client specific queries

  @doc """
  Lists pending sessions for a specific trainer.
  """
  def list_pending_sessions_for_trainer(trainer_id) do
    TrainingSession
    |> where([s], s.trainer_id == ^trainer_id and s.status == "pending")
    |> order_by([s], asc: s.scheduled_at)
    |> preload([:client, :package])
    |> Repo.all()
  end

  @doc """
  Lists upcoming sessions for a specific client.

  ## Options
  - `:limit` - Maximum number of sessions to return
  """
  def list_upcoming_sessions_for_client(client_id, opts \\ []) do
    now = DateTime.utc_now()

    query =
      TrainingSession
      |> where([s], s.client_id == ^client_id)
      |> where([s], s.status in ["pending", "confirmed"])
      |> where([s], s.scheduled_at >= ^now)
      |> order_by([s], asc: s.scheduled_at)
      |> preload([:trainer, :package])

    query =
      if limit = opts[:limit] do
        limit(query, ^limit)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists all unique clients for a trainer with session stats.

  Returns a list of maps with `:user`, `:total_sessions`, and `:last_session_date`.

  ## Options

    * `:search` - Filter by client name (case-insensitive, ILIKE-safe)

  ## Examples

      iex> list_trainer_clients(trainer_id)
      [%{user: %User{}, total_sessions: 5, last_session_date: ~U[...]}]

  """
  def list_trainer_clients(trainer_id, opts \\ []) do
    search = opts[:search]

    query =
      TrainingSession
      |> where([s], s.trainer_id == ^trainer_id)
      |> join(:inner, [s], c in GymStudio.Accounts.User, on: s.client_id == c.id)
      |> group_by([s, c], [c.id, c.name, c.email])
      |> select([s, c], %{
        user_id: c.id,
        name: c.name,
        email: c.email,
        total_sessions: count(s.id),
        last_session_date: max(s.scheduled_at)
      })

    query =
      if search && search != "" do
        sanitized = sanitize_ilike(search)
        where(query, [_s, c], ilike(c.name, ^"%#{sanitized}%"))
      else
        query
      end

    query
    |> order_by([_s, c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Checks if a trainer has at least one training session with the given client.

  ## Examples

      iex> trainer_has_client?(trainer_id, client_id)
      true

  """
  def trainer_has_client?(trainer_id, client_id) do
    TrainingSession
    |> where([s], s.trainer_id == ^trainer_id and s.client_id == ^client_id)
    |> limit(1)
    |> Repo.exists?()
  end

  defp sanitize_ilike(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  @doc """
  Counts unique clients for a trainer.
  """
  def count_unique_clients_for_trainer(trainer_id) do
    TrainingSession
    |> where([s], s.trainer_id == ^trainer_id)
    |> select([s], count(s.client_id, :distinct))
    |> Repo.one() || 0
  end

  @doc """
  Counts sessions for a trainer in the current week.
  """
  def count_sessions_this_week(trainer_id) do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today, :monday)
    end_of_week = Date.add(start_of_week, 6)

    start_datetime = DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC")
    end_datetime = DateTime.new!(end_of_week, ~T[23:59:59], "Etc/UTC")

    TrainingSession
    |> where([s], s.trainer_id == ^trainer_id)
    |> where([s], s.scheduled_at >= ^start_datetime and s.scheduled_at <= ^end_datetime)
    |> where([s], s.status in ["pending", "confirmed", "completed"])
    |> Repo.aggregate(:count) || 0
  end

  @doc """
  Confirms a pending session (wrapper for approve when trainer is already assigned).
  """
  def confirm_session(session_id) when is_binary(session_id) do
    session = get_session!(session_id)
    confirm_session(session)
  end

  def confirm_session(%TrainingSession{} = session) do
    if session.status == "pending" and session.trainer_id do
      session
      |> Ecto.Changeset.change(%{status: "confirmed"})
      |> Repo.update()
    else
      {:error, :invalid_status}
    end
  end

  @doc """
  Cancels a session by ID with a default reason.
  """
  def cancel_session(session_id) when is_binary(session_id) do
    session = get_session!(session_id)
    cancel_session(session, nil, "Cancelled by user")
  end

  @doc """
  Cancels a session by ID with a specific user and reason.
  """
  def cancel_session_by_id(session_id, cancelled_by_id, reason)
      when is_binary(session_id) do
    session = get_session!(session_id)
    cancel_session(session, cancelled_by_id, reason)
  end

  @doc """
  Completes a session by ID with optional attrs (e.g. trainer_notes).
  """
  def complete_session_by_id(session_id, attrs \\ %{}) when is_binary(session_id) do
    session = get_session!(session_id)
    complete_session(session, attrs)
  end

  @doc """
  Books a session for a client using a time slot.
  """
  def book_session(client_id, slot_id) when is_binary(client_id) and is_binary(slot_id) do
    slot = get_time_slot!(slot_id)

    # Create a DateTime from the slot for today or next occurrence
    today = Date.utc_today()
    target_day = slot.day_of_week
    current_day = Date.day_of_week(today)

    days_until =
      if target_day >= current_day do
        target_day - current_day
      else
        7 - current_day + target_day
      end

    target_date = Date.add(today, days_until)
    scheduled_at = DateTime.new!(target_date, slot.start_time, "Etc/UTC")

    book_session(%{
      client_id: client_id,
      scheduled_at: scheduled_at,
      duration_minutes: Time.diff(slot.end_time, slot.start_time, :minute)
    })
  end

  @doc """
  Lists available time slots for a trainer on a specific date.
  """
  def list_available_slots(trainer_id, %Date{} = date) do
    # Get all slots for the day of week
    day_slots = get_available_slots(date)

    # Get already booked sessions for the trainer on this date
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    booked_times =
      TrainingSession
      |> where([s], s.trainer_id == ^trainer_id)
      |> where([s], s.scheduled_at >= ^start_of_day and s.scheduled_at <= ^end_of_day)
      |> where([s], s.status in ["pending", "confirmed"])
      |> select([s], s.scheduled_at)
      |> Repo.all()
      |> Enum.map(&DateTime.to_time/1)

    # Filter out slots that are already booked
    Enum.reject(day_slots, fn slot ->
      slot.start_time in booked_times
    end)
  end

  # Private query helpers

  defp filter_by_status(query, nil), do: query

  defp filter_by_status(query, status) do
    where(query, [s], s.status == ^status)
  end

  defp filter_by_date_range(query, nil, nil), do: query

  defp filter_by_date_range(query, %Date{} = from_date, nil) do
    from_dt = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    where(query, [s], s.scheduled_at >= ^from_dt)
  end

  defp filter_by_date_range(query, nil, %Date{} = to_date) do
    to_dt = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")
    where(query, [s], s.scheduled_at <= ^to_dt)
  end

  defp filter_by_date_range(query, %Date{} = from_date, %Date{} = to_date) do
    from_dt = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_dt = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")
    where(query, [s], s.scheduled_at >= ^from_dt and s.scheduled_at <= ^to_dt)
  end

  defp filter_by_date_range(query, from_date, nil) do
    where(query, [s], s.scheduled_at >= ^from_date)
  end

  defp filter_by_date_range(query, nil, to_date) do
    where(query, [s], s.scheduled_at <= ^to_date)
  end

  defp filter_by_date_range(query, from_date, to_date) do
    where(query, [s], s.scheduled_at >= ^from_date and s.scheduled_at <= ^to_date)
  end

  # Analytics queries

  @doc """
  Counts sessions grouped by status.
  """
  def count_sessions_by_status do
    TrainingSession
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Counts sessions per week for the last N weeks.
  Returns a list of {week_start_date, count} tuples.
  """
  def sessions_per_week(num_weeks \\ 4) do
    today = Date.utc_today()
    start_of_this_week = Date.beginning_of_week(today, :monday)

    Enum.map(0..(num_weeks - 1), fn weeks_ago ->
      week_start = Date.add(start_of_this_week, -7 * weeks_ago)
      week_end = Date.add(week_start, 6)
      from_dt = DateTime.new!(week_start, ~T[00:00:00], "Etc/UTC")
      to_dt = DateTime.new!(week_end, ~T[23:59:59], "Etc/UTC")

      count =
        TrainingSession
        |> where([s], s.scheduled_at >= ^from_dt and s.scheduled_at <= ^to_dt)
        |> Repo.aggregate(:count) || 0

      {week_start, week_end, count}
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns popular time slots based on session bookings.
  Groups by hour of day and returns counts.
  """
  def popular_time_slots do
    TrainingSession
    |> select([s], {fragment("extract(hour from ?)::integer", s.scheduled_at), count(s.id)})
    |> group_by([s], fragment("extract(hour from ?)", s.scheduled_at))
    |> order_by([s], desc: count(s.id))
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn {hour, count} -> {hour, count} end)
  end

  @doc """
  Counts sessions per trainer.
  Returns a list of {trainer_name, count} tuples.
  """
  def trainer_session_counts do
    TrainingSession
    |> where([s], not is_nil(s.trainer_id))
    |> join(:inner, [s], t in assoc(s, :trainer))
    |> group_by([s, t], [t.id, t.name, t.email])
    |> select([s, t], {coalesce(t.name, t.email), count(s.id)})
    |> order_by([s, t], desc: count(s.id))
    |> Repo.all()
  end

  @doc """
  Counts sessions today.
  """
  def count_sessions_today do
    today = Date.utc_today()
    from_dt = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    to_dt = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")

    TrainingSession
    |> where([s], s.scheduled_at >= ^from_dt and s.scheduled_at <= ^to_dt)
    |> where([s], s.status in ["pending", "confirmed", "completed"])
    |> Repo.aggregate(:count) || 0
  end

  @doc """
  Counts sessions this week (all trainers).
  """
  def count_all_sessions_this_week do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today, :monday)
    end_of_week = Date.add(start_of_week, 6)
    from_dt = DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC")
    to_dt = DateTime.new!(end_of_week, ~T[23:59:59], "Etc/UTC")

    TrainingSession
    |> where([s], s.scheduled_at >= ^from_dt and s.scheduled_at <= ^to_dt)
    |> where([s], s.status in ["pending", "confirmed", "completed"])
    |> Repo.aggregate(:count) || 0
  end

  @doc """
  Lists all sessions with optional filters.

  ## Options
    * `:status` - Filter by status
    * `:trainer_id` - Filter by trainer
    * `:client_id` - Filter by client
    * `:from_date` - Filter from date
    * `:to_date` - Filter to date
  """
  def list_all_sessions(opts \\ []) do
    TrainingSession
    |> filter_by_status(opts[:status])
    |> filter_by_trainer(opts[:trainer_id])
    |> filter_by_client(opts[:client_id])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([s], desc: s.scheduled_at)
    |> preload([:client, :trainer, :package])
    |> Repo.all()
  end

  defp filter_by_trainer(query, nil), do: query
  defp filter_by_trainer(query, ""), do: query

  defp filter_by_trainer(query, trainer_id) do
    where(query, [s], s.trainer_id == ^trainer_id)
  end

  defp filter_by_client(query, nil), do: query
  defp filter_by_client(query, ""), do: query

  defp filter_by_client(query, client_id) do
    where(query, [s], s.client_id == ^client_id)
  end

  @doc """
  Admin override: directly set a session's status.
  """
  def admin_update_session(%TrainingSession{} = session, attrs) do
    session
    |> Ecto.Changeset.cast(attrs, [:status, :trainer_id, :notes])
    |> Repo.update()
  end

  @doc """
  Updates a session's status directly (admin override).
  """
  def update_session_status(%TrainingSession{} = session, new_status) do
    session
    |> Ecto.Changeset.change(%{status: new_status})
    |> Repo.update()
  end

  @doc """
  Assigns a trainer to a session.
  """
  def assign_trainer(%TrainingSession{} = session, trainer_id) do
    session
    |> Ecto.Changeset.change(%{trainer_id: trainer_id})
    |> Repo.update()
  end

  # =============================================================================
  # Trainer Availability
  # =============================================================================

  @doc """
  Lists all availability records for a trainer, ordered by day_of_week.
  """
  def list_trainer_availabilities(trainer_id) do
    TrainerAvailability
    |> where([a], a.trainer_id == ^trainer_id)
    |> order_by([a], asc: a.day_of_week)
    |> Repo.all()
  end

  @doc """
  Upserts trainer availability for a specific day of week.
  """
  def set_trainer_availability(trainer_id, day_of_week, attrs) do
    existing =
      TrainerAvailability
      |> where([a], a.trainer_id == ^trainer_id and a.day_of_week == ^day_of_week)
      |> Repo.one()

    changeset_attrs = Map.merge(attrs, %{trainer_id: trainer_id, day_of_week: day_of_week})

    case existing do
      nil ->
        %TrainerAvailability{}
        |> TrainerAvailability.changeset(changeset_attrs)
        |> Repo.insert()

      avail ->
        avail
        |> TrainerAvailability.changeset(changeset_attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes trainer availability for a specific day (marks as day off).
  """
  def delete_trainer_availability(trainer_id, day_of_week) do
    TrainerAvailability
    |> where([a], a.trainer_id == ^trainer_id and a.day_of_week == ^day_of_week)
    |> Repo.delete_all()

    :ok
  end

  # =============================================================================
  # Trainer Time Off
  # =============================================================================

  @doc """
  Lists time-off entries for a trainer.

  ## Options
  - `:from_date` - Filter from date (default: today)
  - `:to_date` - Filter to date
  """
  def list_trainer_time_offs(trainer_id, opts \\ []) do
    from_date = Keyword.get(opts, :from_date)
    to_date = Keyword.get(opts, :to_date)

    TrainerTimeOff
    |> where([t], t.trainer_id == ^trainer_id)
    |> then(fn q ->
      if from_date, do: where(q, [t], t.date >= ^from_date), else: q
    end)
    |> then(fn q ->
      if to_date, do: where(q, [t], t.date <= ^to_date), else: q
    end)
    |> order_by([t], asc: t.date)
    |> Repo.all()
  end

  @doc """
  Creates a time-off entry.
  """
  def create_time_off(attrs) do
    %TrainerTimeOff{}
    |> TrainerTimeOff.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a time-off entry by ID.
  """
  def delete_time_off(id) do
    case Repo.get(TrainerTimeOff, id) do
      nil -> {:error, :not_found}
      time_off -> Repo.delete(time_off)
    end
  end

  @doc """
  Gets a time-off entry, scoped to a trainer for authorization.
  """
  def get_time_off(id, trainer_id) do
    TrainerTimeOff
    |> where([t], t.id == ^id and t.trainer_id == ^trainer_id)
    |> Repo.one()
  end

  # =============================================================================
  # Available Slots (combines availability + bookings + time-offs)
  # =============================================================================

  @doc """
  Returns available hourly slots for a trainer on a given date.

  Combines:
  1. Trainer's weekly availability for that day of week
  2. Minus existing bookings (pending/confirmed)
  3. Minus time-off entries

  Returns a list of `%{hour: integer, label: string, trainer_id: id, trainer_name: string}`.
  """
  def get_trainer_available_slots(trainer_id, %Date{} = date) do
    day_of_week = Date.day_of_week(date)

    # 1. Get availability for this day
    availability =
      TrainerAvailability
      |> where(
        [a],
        a.trainer_id == ^trainer_id and a.day_of_week == ^day_of_week and a.active == true
      )
      |> Repo.one()

    case availability do
      nil ->
        []

      %{start_time: start_time, end_time: end_time} ->
        start_hour = start_time.hour
        end_hour = end_time.hour

        # Generate all possible hours
        all_hours = Enum.to_list(start_hour..(end_hour - 1))

        # 2. Remove booked hours
        start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

        booked_hours =
          TrainingSession
          |> where([s], s.trainer_id == ^trainer_id)
          |> where([s], s.scheduled_at >= ^start_of_day and s.scheduled_at <= ^end_of_day)
          |> where([s], s.status in ["pending", "confirmed"])
          |> select([s], s.scheduled_at)
          |> Repo.all()
          |> Enum.map(fn dt -> dt.hour end)
          |> MapSet.new()

        # 3. Remove time-off hours
        time_offs =
          TrainerTimeOff
          |> where([t], t.trainer_id == ^trainer_id and t.date == ^date)
          |> Repo.all()

        time_off_hours =
          Enum.flat_map(time_offs, fn to ->
            if is_nil(to.start_time) || is_nil(to.end_time) do
              # All day off
              all_hours
            else
              Enum.to_list(to.start_time.hour..(to.end_time.hour - 1))
            end
          end)
          |> MapSet.new()

        blocked = MapSet.union(booked_hours, time_off_hours)

        all_hours
        |> Enum.reject(&MapSet.member?(blocked, &1))
        |> Enum.map(fn hour ->
          %{hour: hour, label: format_hour(hour), value: Integer.to_string(hour)}
        end)
    end
  end

  @doc """
  Returns available slots across ALL trainers for a given date.
  Returns `[%{hour: integer, label: string, trainer_id: id, trainer_name: string}]`.
  """
  def get_all_available_slots(%Date{} = date) do
    day_of_week = Date.day_of_week(date)

    # Get all trainers with availability on this day
    availabilities =
      TrainerAvailability
      |> where([a], a.day_of_week == ^day_of_week and a.active == true)
      |> join(:inner, [a], u in GymStudio.Accounts.User, on: a.trainer_id == u.id)
      |> select([a, u], %{
        trainer_id: a.trainer_id,
        trainer_name: u.name,
        start_time: a.start_time,
        end_time: a.end_time
      })
      |> Repo.all()

    # For each trainer, compute available slots
    Enum.flat_map(availabilities, fn %{
                                       trainer_id: tid,
                                       trainer_name: tname,
                                       start_time: st,
                                       end_time: et
                                     } ->
      start_hour = st.hour
      end_hour = et.hour
      all_hours = Enum.to_list(start_hour..(end_hour - 1))

      # Booked hours
      start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

      booked_hours =
        TrainingSession
        |> where([s], s.trainer_id == ^tid)
        |> where([s], s.scheduled_at >= ^start_of_day and s.scheduled_at <= ^end_of_day)
        |> where([s], s.status in ["pending", "confirmed"])
        |> select([s], s.scheduled_at)
        |> Repo.all()
        |> Enum.map(fn dt -> dt.hour end)
        |> MapSet.new()

      # Time-off hours
      time_offs =
        TrainerTimeOff
        |> where([t], t.trainer_id == ^tid and t.date == ^date)
        |> Repo.all()

      time_off_hours =
        Enum.flat_map(time_offs, fn to ->
          if is_nil(to.start_time) || is_nil(to.end_time) do
            all_hours
          else
            Enum.to_list(to.start_time.hour..(to.end_time.hour - 1))
          end
        end)
        |> MapSet.new()

      blocked = MapSet.union(booked_hours, time_off_hours)

      all_hours
      |> Enum.reject(&MapSet.member?(blocked, &1))
      |> Enum.map(fn hour ->
        %{
          hour: hour,
          label: format_hour(hour),
          value: Integer.to_string(hour),
          trainer_id: tid,
          trainer_name: tname || "Trainer"
        }
      end)
    end)
    |> Enum.sort_by(& &1.hour)
  end

  @doc """
  Lists all trainers who have availability configured.
  """
  def list_trainers_with_availability do
    TrainerAvailability
    |> join(:inner, [a], u in GymStudio.Accounts.User, on: a.trainer_id == u.id)
    |> select([a, u], %{trainer_id: u.id, trainer_name: u.name})
    |> distinct(true)
    |> Repo.all()
  end

  defp format_hour(hour) when hour < 12, do: "#{hour}:00 AM"
  defp format_hour(12), do: "12:00 PM"
  defp format_hour(hour), do: "#{hour - 12}:00 PM"
end
