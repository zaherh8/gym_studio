defmodule GymStudio.NotificationsTest do
  use GymStudio.DataCase

  alias GymStudio.Notifications
  alias GymStudio.Notifications.Notification

  import GymStudio.AccountsFixtures
  import GymStudio.NotificationsFixtures

  describe "create_notification/1" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "creates a notification with valid attrs", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Test Title",
        message: "Test message",
        type: "general"
      }

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.user_id == user.id
      assert notification.title == "Test Title"
      assert notification.message == "Test message"
      assert notification.type == "general"
      assert is_nil(notification.read_at)
    end

    test "creates notification with optional fields", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Test",
        message: "Message",
        type: "booking_confirmed",
        action_url: "/sessions/123",
        metadata: %{"session_id" => "123"}
      }

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.action_url == "/sessions/123"
      assert notification.metadata == %{"session_id" => "123"}
    end

    test "fails with invalid type", %{user: user} do
      attrs = %{
        user_id: user.id,
        title: "Test",
        message: "Message",
        type: "invalid_type"
      }

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "fails without required fields" do
      assert {:error, changeset} = Notifications.create_notification(%{})
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).message
      assert "can't be blank" in errors_on(changeset).type
    end
  end

  describe "list_notifications_for_user/2" do
    setup do
      user = user_fixture()
      other_user = user_fixture()
      %{user: user, other_user: other_user}
    end

    test "returns notifications for specific user", %{user: user, other_user: other_user} do
      notification1 = notification_fixture(user_id: user.id, title: "User 1")
      _notification2 = notification_fixture(user_id: other_user.id, title: "User 2")

      notifications = Notifications.list_notifications_for_user(user.id)
      assert length(notifications) == 1
      assert hd(notifications).id == notification1.id
    end

    test "returns notifications in descending order by inserted_at", %{user: user} do
      n1 = notification_fixture(user_id: user.id, title: "First")
      n2 = notification_fixture(user_id: user.id, title: "Second")

      notifications = Notifications.list_notifications_for_user(user.id)
      notification_ids = Enum.map(notifications, & &1.id)

      # Verify both notifications are returned
      assert length(notifications) == 2
      assert n1.id in notification_ids
      assert n2.id in notification_ids

      # Verify descending order (most recent first based on inserted_at)
      [first | _] = notifications
      assert first.inserted_at >= List.last(notifications).inserted_at
    end

    test "filters unread only", %{user: user} do
      _unread = notification_fixture(user_id: user.id, title: "Unread")
      _read = read_notification_fixture(user_id: user.id, title: "Read")

      unread_notifications = Notifications.list_notifications_for_user(user.id, unread_only: true)
      assert length(unread_notifications) == 1
      assert hd(unread_notifications).title == "Unread"
    end

    test "respects limit option", %{user: user} do
      for i <- 1..5 do
        notification_fixture(user_id: user.id, title: "Notification #{i}")
      end

      notifications = Notifications.list_notifications_for_user(user.id, limit: 3)
      assert length(notifications) == 3
    end
  end

  describe "count_unread_notifications/1" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "counts only unread notifications", %{user: user} do
      _unread1 = notification_fixture(user_id: user.id)
      _unread2 = notification_fixture(user_id: user.id)
      _read = read_notification_fixture(user_id: user.id)

      assert Notifications.count_unread_notifications(user.id) == 2
    end

    test "returns 0 when no unread notifications", %{user: user} do
      _read = read_notification_fixture(user_id: user.id)

      assert Notifications.count_unread_notifications(user.id) == 0
    end
  end

  describe "mark_as_read/1" do
    setup do
      user = user_fixture()
      notification = notification_fixture(user_id: user.id)
      %{notification: notification}
    end

    test "marks notification as read", %{notification: notification} do
      assert is_nil(notification.read_at)

      assert {:ok, updated} = Notifications.mark_as_read(notification)
      assert not is_nil(updated.read_at)
    end
  end

  describe "mark_all_as_read/1" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "marks all unread notifications as read", %{user: user} do
      _n1 = notification_fixture(user_id: user.id)
      _n2 = notification_fixture(user_id: user.id)
      _n3 = notification_fixture(user_id: user.id)

      assert Notifications.count_unread_notifications(user.id) == 3

      assert {:ok, 3} = Notifications.mark_all_as_read(user.id)
      assert Notifications.count_unread_notifications(user.id) == 0
    end
  end

  describe "delete_notification/1" do
    setup do
      user = user_fixture()
      notification = notification_fixture(user_id: user.id)
      %{notification: notification}
    end

    test "deletes notification", %{notification: notification} do
      assert {:ok, _} = Notifications.delete_notification(notification)
      assert_raise Ecto.NoResultsError, fn -> Notifications.get_notification!(notification.id) end
    end
  end

  describe "notification types" do
    test "Notification.types/0 returns valid types" do
      types = Notification.types()

      assert "booking_confirmed" in types
      assert "booking_cancelled" in types
      assert "session_reminder" in types
      assert "package_assigned" in types
      assert "trainer_approved" in types
      assert "general" in types
    end
  end
end
