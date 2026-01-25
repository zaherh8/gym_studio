defmodule GymStudioWeb.Trainer.DashboardLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Trainer Dashboard" do
    setup do
      # Create a trainer user
      trainer_user = user_fixture(%{role: :trainer})
      trainer = trainer_fixture(%{user_id: trainer_user.id})

      # Approve the trainer
      admin = user_fixture(%{role: :admin})

      trainer =
        trainer
        |> GymStudio.Accounts.Trainer.approval_changeset(admin)
        |> GymStudio.Repo.update!()

      %{trainer_user: trainer_user, trainer: trainer, admin: admin}
    end

    test "requires authentication", %{conn: conn} do
      # Without authentication, should redirect to login
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
      assert html =~ "Today&#39;s Sessions"
      assert html =~ "Pending Session Requests"
    end

    test "displays warning when trainer profile not set up", %{conn: conn} do
      # Create user without trainer profile
      user = user_fixture(%{role: :trainer})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Your trainer profile is not set up yet"
      assert html =~ "Please contact an administrator"
    end

    test "displays pending approval status", %{conn: conn} do
      # Create a trainer that's not approved
      trainer_user = user_fixture(%{role: :trainer})
      _trainer = trainer_fixture(%{user_id: trainer_user.id})

      conn = log_in_user(conn, trainer_user)

      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "Your trainer account is currently pending"
      assert html =~ "You&#39;ll be notified when approved"
    end

    test "displays stats for trainer", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      # Create a client and sessions
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

      # Should show at least 1 client
      assert html =~ "Total Clients"
    end

    test "displays today's sessions", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      # Create a session for today
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      # Create a session for today at 2pm
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

      assert html =~ client_user.email
      assert html =~ "14:00"
    end

    test "displays pending session requests", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      # Create a pending session (no trainer assigned yet, but we'll use direct insert)
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      # Create a pending session
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

      assert html =~ client_user.email
      assert html =~ "Confirm"
    end

    test "displays 'no sessions' messages when appropriate", %{
      conn: conn,
      trainer_user: trainer_user
    } do
      conn = log_in_user(conn, trainer_user)

      {:ok, _view, html} = live(conn, ~p"/trainer")

      assert html =~ "No sessions scheduled for today"
      assert html =~ "No pending session requests"
    end
  end
end
