defmodule GymStudio.Notifications do
  @moduledoc """
  The Notifications context handles in-app notifications for users.

  Notifications inform users about important events like session confirmations,
  cancellations, and reminders. They support real-time updates via PubSub.

  ## PubSub Integration

  When a notification is created, it broadcasts to the user's notification channel:

      Phoenix.PubSub.broadcast(GymStudio.PubSub, "notifications:user_id", {:new_notification, notification})

  LiveViews can subscribe to receive real-time notification updates.
  """

  import Ecto.Query, warn: false
  alias GymStudio.Repo
  alias GymStudio.Notifications.Notification

  @pubsub GymStudio.PubSub

  @doc """
  Creates a notification for a user.

  Broadcasts to the user's notification channel for real-time updates.

  ## Examples

      iex> create_notification(%{
      ...>   user_id: user_id,
      ...>   title: "Session Confirmed",
      ...>   message: "Your session on Monday at 10am has been confirmed.",
      ...>   type: "booking_confirmed"
      ...> })
      {:ok, %Notification{}}
  """
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> broadcast_notification()
  end

  @doc """
  Creates a booking confirmed notification.
  """
  def notify_booking_confirmed(user_id, session) do
    create_notification(%{
      user_id: user_id,
      title: "Session Confirmed",
      message: "Your session on #{format_datetime(session.scheduled_at)} has been confirmed.",
      type: "booking_confirmed",
      action_url: "/client/sessions/#{session.id}",
      metadata: %{session_id: session.id}
    })
  end

  @doc """
  Creates a booking cancelled notification.
  """
  def notify_booking_cancelled(user_id, session, reason \\ nil) do
    message =
      if reason do
        "Your session on #{format_datetime(session.scheduled_at)} has been cancelled. Reason: #{reason}"
      else
        "Your session on #{format_datetime(session.scheduled_at)} has been cancelled."
      end

    create_notification(%{
      user_id: user_id,
      title: "Session Cancelled",
      message: message,
      type: "booking_cancelled",
      metadata: %{session_id: session.id}
    })
  end

  @doc """
  Creates a package assigned notification.
  """
  def notify_package_assigned(user_id, package) do
    create_notification(%{
      user_id: user_id,
      title: "New Package Assigned",
      message: "You have been assigned a #{package.total_sessions}-session package.",
      type: "package_assigned",
      action_url: "/client/packages",
      metadata: %{package_id: package.id}
    })
  end

  @doc """
  Creates a trainer approved notification.
  """
  def notify_trainer_approved(user_id) do
    create_notification(%{
      user_id: user_id,
      title: "Profile Approved",
      message:
        "Congratulations! Your trainer profile has been approved. You can now receive session assignments.",
      type: "trainer_approved",
      action_url: "/trainer/dashboard"
    })
  end

  @doc """
  Creates a session reminder notification.
  """
  def notify_session_reminder(user_id, session) do
    create_notification(%{
      user_id: user_id,
      title: "Session Reminder",
      message: "You have a session scheduled for #{format_datetime(session.scheduled_at)}.",
      type: "session_reminder",
      action_url: "/client/sessions/#{session.id}",
      metadata: %{session_id: session.id}
    })
  end

  @doc """
  Gets a notification by ID.
  """
  def get_notification!(id) do
    Repo.get!(Notification, id)
  end

  @doc """
  Lists notifications for a user.

  ## Options
    * `:unread_only` - Only return unread notifications (default: false)
    * `:limit` - Maximum number of notifications to return
  """
  def list_notifications_for_user(user_id, opts \\ []) do
    query =
      Notification
      |> where([n], n.user_id == ^user_id)
      |> order_by([n], desc: n.inserted_at)

    query =
      if opts[:unread_only] do
        where(query, [n], is_nil(n.read_at))
      else
        query
      end

    query =
      if limit = opts[:limit] do
        limit(query, ^limit)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Counts unread notifications for a user.
  """
  def count_unread_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> where([n], is_nil(n.read_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Notification.read_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications for a user as read.
  """
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now(:second)

    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id)
      |> where([n], is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now])

    {:ok, count}
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Subscribes to notifications for a user.

  Call this from LiveView mount to receive real-time notifications.
  """
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  @doc """
  Unsubscribes from notifications for a user.
  """
  def unsubscribe(user_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(user_id))
  end

  # Private functions

  defp topic(user_id), do: "notifications:#{user_id}"

  defp broadcast_notification({:ok, notification} = result) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(notification.user_id),
      {:new_notification, notification}
    )

    result
  end

  defp broadcast_notification(error), do: error

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%A, %B %d at %I:%M %p")
  end
end
