defmodule GymStudioWeb.Client.SessionsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Sessions List" do
    setup do
      client_user = user_fixture(%{role: :client})
      client = client_fixture(%{user_id: client_user.id})

      %{client_user: client_user, client: client}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/client/sessions")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders sessions page for authenticated client", %{
      conn: conn,
      client_user: client_user
    } do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/sessions")

      assert html =~ "My Sessions"
      assert html =~ "Book New Session"
    end

    test "shows empty state when no sessions", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/sessions")

      assert html =~ "No sessions found"
    end

    test "displays sessions with status badges", %{conn: conn, client_user: client_user} do
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
      {:ok, _view, html} = live(conn, ~p"/client/sessions")

      assert html =~ "confirmed"
      assert html =~ "badge-success"
    end

    test "filters sessions by status", %{conn: conn, client_user: client_user} do
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

      _confirmed =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "confirmed"
        })

      _pending =
        training_session_fixture(%{
          client_id: client_user.id,
          scheduled_at: DateTime.add(tomorrow, 1, :day),
          status: "pending"
        })

      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/sessions")

      # Filter by confirmed
      html = view |> element("button[phx-value-status='confirmed']") |> render_click()
      assert html =~ "confirmed"
    end

    test "cancel button on pending sessions", %{conn: conn, client_user: client_user} do
      _pending =
        training_session_fixture(%{
          client_id: client_user.id,
          scheduled_at: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second),
          status: "pending"
        })

      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/sessions")

      assert html =~ "Cancel"
    end
  end
end
