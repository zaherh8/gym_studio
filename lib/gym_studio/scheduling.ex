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
    %TrainingSession{}
    |> TrainingSession.changeset(attrs)
    |> Repo.insert()
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
    session
    |> TrainingSession.approval_changeset(%{
      trainer_id: trainer_id,
      approved_by_id: approved_by_id
    })
    |> Repo.update()
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
    session
    |> TrainingSession.cancellation_changeset(%{
      cancelled_by_id: cancelled_by_id,
      cancellation_reason: reason
    })
    |> Repo.update()
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
    session
    |> TrainingSession.completion_changeset(attrs)
    |> Repo.update()
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
    |> order_by([ts], [asc: ts.day_of_week, asc: ts.start_time])
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
      |> TrainingSession.changeset(%{status: "confirmed"})
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
  Completes a session by ID.
  """
  def complete_session_by_id(session_id) when is_binary(session_id) do
    session = get_session!(session_id)
    complete_session(session)
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

  defp filter_by_date_range(query, from_date, nil) do
    where(query, [s], s.scheduled_at >= ^from_date)
  end

  defp filter_by_date_range(query, nil, to_date) do
    where(query, [s], s.scheduled_at <= ^to_date)
  end

  defp filter_by_date_range(query, from_date, to_date) do
    where(query, [s], s.scheduled_at >= ^from_date and s.scheduled_at <= ^to_date)
  end
end
