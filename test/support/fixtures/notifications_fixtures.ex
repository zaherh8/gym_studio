defmodule GymStudio.NotificationsFixtures do
  @moduledoc """
  Test fixtures for the Notifications context.
  """

  alias GymStudio.Notifications

  @doc """
  Generate a notification.

  ## Options
    * `:user_id` - The user ID (required)
    * `:title` - Notification title (default: "Test Notification")
    * `:message` - Notification message (default: "This is a test notification.")
    * `:type` - Notification type (default: "general")
    * `:action_url` - Optional action URL
    * `:metadata` - Optional metadata map
  """
  def notification_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test Notification",
        message: "This is a test notification.",
        type: "general"
      })

    {:ok, notification} = Notifications.create_notification(attrs)
    notification
  end

  @doc """
  Generate a read notification.
  """
  def read_notification_fixture(attrs \\ %{}) do
    notification = notification_fixture(attrs)
    {:ok, read_notification} = Notifications.mark_as_read(notification)
    read_notification
  end
end
