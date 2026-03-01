defmodule GymStudioWeb.Trainer.DashboardLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Trainer Dashboard" do
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

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/trainer")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders dashboard for authenticated trainer", %{
      conn: conn,
      trainer_user: trainer_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Trainer Dashboard"
      assert html =~ "Total Clients"
      assert html =~ "Sessions This Week"
      assert html =~ "Pending Requests"
    end

    test "displays warning when trainer profile not set up", %{conn: conn} do
      user = user_fixture(%{role: :trainer})
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Your trainer profile is not set up yet"
    end

    test "displays pending approval status", %{conn: conn} do
      trainer_user = user_fixture(%{role: :trainer})
      _trainer = trainer_fixture(%{user_id: trainer_user.id})
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Your trainer account is currently pending"
    end

    test "displays today's sessions with client name", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Jane Client"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      today = Date.utc_today()
      today_at_2pm = DateTime.new!(today, ~T[14:00:00], "Etc/UTC")

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: today_at_2pm,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Jane Client"
      assert html =~ "14:00"
    end

    test "displays pending session requests with confirm and cancel buttons", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Bob Pending"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Bob Pending"
      assert html =~ "Confirm"
      assert html =~ "Cancel"
    end

    test "confirms a pending session", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer")

      html = render_click(view, "confirm_session", %{"session_id" => session.id})
      assert html =~ "badge-success"
    end

    test "cancels a session with reason via modal", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      # Simulate what book_session does: consume a session from the package
      {:ok, _} = GymStudio.Packages.use_session(package)

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer")

      # Open cancel modal
      html =
        render_click(view, "open_cancel_modal", %{"session_id" => session.id})

      assert html =~ "Cancel Session"
      assert html =~ "Reason for cancellation"

      # Update reason and confirm
      render_click(view, "update_cancel_reason", %{"reason" => "Client requested"})
      html = render_click(view, "cancel_session")

      # Session should no longer appear in pending requests
      refute html =~ "Confirm"
      assert html =~ "No pending session requests"
    end

    test "completes a confirmed session with notes via modal", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      today = Date.utc_today()
      today_at_2pm = DateTime.new!(today, ~T[14:00:00], "Etc/UTC")

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: today_at_2pm,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer")

      # Open complete modal
      html =
        render_click(view, "open_complete_modal", %{"session_id" => session.id})

      assert html =~ "Complete Session"

      # Add notes and complete
      render_click(view, "update_trainer_notes", %{"notes" => "Great progress"})
      html = render_click(view, "complete_session")

      assert html =~ "badge-info"
    end

    test "displays empty states", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "No sessions scheduled for today"
      assert html =~ "No pending session requests"
      assert html =~ "No upcoming sessions"
    end

    test "displays upcoming sessions for next 7 days", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Future Client"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      three_days = DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: three_days,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Future Client"
      assert html =~ "Upcoming Sessions"
    end

    test "displays stats for trainer", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Total Clients"
    end
  end
end
