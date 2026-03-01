defmodule GymStudioWeb.Admin.CalendarLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  alias GymStudio.Scheduling

  describe "Admin Calendar" do
    setup do
      admin = user_fixture(%{role: :admin})
      client = user_fixture(%{role: :client, name: "Cal Client"})
      trainer = user_fixture(%{role: :trainer, name: "Cal Trainer"})

      {:ok, trainer_profile} = GymStudio.Accounts.create_trainer_profile(trainer)
      {:ok, _} = GymStudio.Accounts.approve_trainer(trainer_profile, admin)

      %{admin: admin, client: client, trainer: trainer}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/calendar")
    end

    test "renders calendar page", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/calendar")
      assert html =~ "Gym Calendar"
    end

    test "shows Unassigned for sessions without trainer", %{
      conn: conn,
      admin: admin,
      client: client
    } do
      # Use a unique time to avoid collisions with seed data
      tomorrow = Date.add(Date.utc_today(), 2)
      scheduled_at = DateTime.new!(tomorrow, ~T[15:00:00], "Etc/UTC")
      session = training_session_fixture(%{client_id: client.id, scheduled_at: scheduled_at})

      # Verify the session has no trainer
      loaded = Scheduling.get_session!(session.id)
      assert is_nil(loaded.trainer_id)

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/calendar")

      # Navigate to the week containing the session
      render_click(view, "next_week")

      # Open session modal — should show Unassigned badge
      html = render_click(view, "show_session", %{"session-id" => session.id})
      assert html =~ "Unassigned"
    end

    test "assigns trainer to unassigned session via modal", %{
      conn: conn,
      admin: admin,
      client: client,
      trainer: trainer
    } do
      tomorrow = Date.add(Date.utc_today(), 1)
      day_of_week = Date.day_of_week(tomorrow)
      scheduled_at = DateTime.new!(tomorrow, ~T[10:00:00], "Etc/UTC")

      {:ok, _} =
        Scheduling.set_trainer_availability(trainer.id, day_of_week, %{
          start_time: ~T[08:00:00],
          end_time: ~T[18:00:00],
          active: true
        })

      session = training_session_fixture(%{client_id: client.id, scheduled_at: scheduled_at})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/calendar")

      # Navigate to the week containing tomorrow
      render_click(view, "next_week")

      # Open session modal
      render_click(view, "show_session", %{"session-id" => session.id})

      # Should show assign trainer section
      html = render(view)
      assert html =~ "Assign a Trainer"
      assert html =~ "Cal Trainer"

      # Assign the trainer
      render_click(view, "assign_trainer", %{
        "trainer_id" => trainer.id
      })

      # Verify the session now has the trainer assigned
      updated = Scheduling.get_session!(session.id)
      assert updated.trainer_id == trainer.id
    end
  end
end
