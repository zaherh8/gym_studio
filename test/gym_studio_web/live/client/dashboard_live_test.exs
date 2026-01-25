defmodule GymStudioWeb.Client.DashboardLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Client Dashboard" do
    setup do
      # Create a client user
      client_user = user_fixture(%{role: :client})
      client = client_fixture(%{user_id: client_user.id})

      %{client_user: client_user, client: client}
    end

    test "requires authentication", %{conn: conn} do
      # Without authentication, should redirect to login
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/client")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders dashboard for authenticated client", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)

      {:ok, _view, html} = live(conn, ~p"/client")

      assert html =~ "Welcome back!"
      assert html =~ "Book Session"
      assert html =~ "My Sessions"
      assert html =~ "Packages"
      assert html =~ "Upcoming Sessions"
    end

    test "displays 'no active package' when client has no package", %{
      conn: conn,
      client_user: client_user
    } do
      conn = log_in_user(conn, client_user)

      {:ok, _view, html} = live(conn, ~p"/client")

      assert html =~ "No active package"
      assert html =~ "Contact your trainer to get started"
    end

    test "displays active package information", %{
      conn: conn,
      client_user: client_user,
      client: _client
    } do
      # Create an active package for the client
      admin = user_fixture(%{role: :admin})

      _package =
        used_package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12",
          used_sessions: 4,
          expires_at: DateTime.utc_now() |> DateTime.add(60, :day)
        })

      conn = log_in_user(conn, client_user)

      {:ok, _view, html} = live(conn, ~p"/client")

      assert html =~ "Active Package"
      assert html =~ "8"
      assert html =~ "/12 sessions"
    end

    test "displays upcoming sessions", %{
      conn: conn,
      client_user: client_user
    } do
      # Create a trainer and upcoming session
      trainer_user = user_fixture(%{role: :trainer})
      _trainer = trainer_fixture(%{user_id: trainer_user.id})
      admin = user_fixture(%{role: :admin})

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

      conn = log_in_user(conn, client_user)

      {:ok, _view, html} = live(conn, ~p"/client")

      assert html =~ trainer_user.email
      assert html =~ "Confirmed"
    end

    test "displays 'no upcoming sessions' when client has no sessions", %{
      conn: conn,
      client_user: client_user
    } do
      conn = log_in_user(conn, client_user)

      {:ok, _view, html} = live(conn, ~p"/client")

      assert html =~ "No upcoming sessions"
      assert html =~ "Book Your First Session"
    end
  end
end
