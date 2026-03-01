defmodule GymStudioWeb.Trainer.ScheduleLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Trainer Schedule" do
    setup do
      trainer_user = user_fixture(%{role: :trainer})
      trainer = trainer_fixture(%{user_id: trainer_user.id})
      admin = user_fixture(%{role: :admin})

      trainer =
        trainer
        |> GymStudio.Accounts.Trainer.approval_changeset(admin)
        |> GymStudio.Repo.update!()

      %{trainer_user: trainer_user, trainer: trainer, admin: admin}
    end

    test "renders schedule page", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/schedule")

      assert html =~ "My Schedule"
    end

    test "navigates between weeks", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/schedule")

      html = render_click(view, "next_week")
      assert html =~ "My Schedule"

      html = render_click(view, "previous_week")
      assert html =~ "My Schedule"

      html = render_click(view, "today")
      assert html =~ "My Schedule"
    end

    test "shows sessions on the schedule with client name", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Schedule Client"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      # Create a session for today
      today = Date.utc_today()
      today_at_10am = DateTime.new!(today, ~T[10:00:00], "Etc/UTC")

      # Create a time slot for today's day of week
      day_of_week = Date.day_of_week(today)

      _slot =
        time_slot_fixture(%{
          day_of_week: day_of_week,
          start_time: ~T[10:00:00],
          end_time: ~T[11:00:00]
        })

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: today_at_10am,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/schedule")

      assert html =~ "Schedule Client"
    end

    test "shows available slots", %{conn: conn, trainer_user: trainer_user} do
      today = Date.utc_today()
      day_of_week = Date.day_of_week(today)

      _slot =
        time_slot_fixture(%{
          day_of_week: day_of_week,
          start_time: ~T[09:00:00],
          end_time: ~T[10:00:00]
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/schedule")

      assert html =~ "Available"
    end

    test "shows legend", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/schedule")

      assert html =~ "Available"
      assert html =~ "Pending"
      assert html =~ "Confirmed"
      assert html =~ "Completed"
      assert html =~ "Cancelled"
    end
  end
end
