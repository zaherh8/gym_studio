defmodule GymStudioWeb.Client.BookSessionLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures

  alias GymStudio.Scheduling

  describe "Book Session" do
    setup do
      client_user = user_fixture(%{role: :client})
      client = client_fixture(%{user_id: client_user.id})

      # Create a trainer with availability so slots show up
      trainer_user = user_fixture(%{role: :trainer})

      # Set availability for all 7 days (9 AM - 10 PM) so tests always have slots
      for day <- 1..7 do
        Scheduling.set_trainer_availability(trainer_user.id, day, %{
          start_time: ~T[07:00:00],
          end_time: ~T[22:00:00]
        })
      end

      %{client_user: client_user, client: client, trainer_user: trainer_user}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/client/book")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders booking page for authenticated client", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/book")

      assert html =~ "Book a Session"
      assert html =~ "Select Date"
    end

    test "shows no active package warning when client has no package", %{
      conn: conn,
      client_user: client_user
    } do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/book")

      assert html =~ "No Active Package"
    end

    test "does not show package warning when client has active package", %{
      conn: conn,
      client_user: client_user
    } do
      admin = user_fixture(%{role: :admin})

      _package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/book")

      refute html =~ "No Active Package"
    end

    test "prevents booking without active package", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user
    } do
      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/book")

      # Select a date
      date = Date.add(Date.utc_today(), 1)

      view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()

      # Select a time slot (now includes trainer)
      view
      |> element("button[phx-value-slot='10'][phx-value-trainer='#{trainer_user.id}']")
      |> render_click()

      # Try to confirm
      view |> element("button", "Confirm Booking") |> render_click()

      assert has_element?(view, "[role=alert]") or
               render(view) =~ "No Active Package"
    end

    test "3-step flow works with date, time, and confirm", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user
    } do
      admin = user_fixture(%{role: :admin})

      _package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/book")

      # Step 1: Select date
      date = Date.add(Date.utc_today(), 1)

      html = view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()
      assert html =~ "Select Time"

      # Step 2: Select time + trainer
      html =
        view
        |> element("button[phx-value-slot='10'][phx-value-trainer='#{trainer_user.id}']")
        |> render_click()

      assert html =~ "Confirm Booking"

      # Step 3: Confirm - should redirect to sessions
      view |> element("button", "Confirm Booking") |> render_click()
      assert_redirected(view, ~p"/client/sessions")
    end

    test "shows notes field in confirmation step", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user
    } do
      admin = user_fixture(%{role: :admin})

      _package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/book")

      date = Date.add(Date.utc_today(), 1)

      view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()

      html =
        view
        |> element("button[phx-value-slot='10'][phx-value-trainer='#{trainer_user.id}']")
        |> render_click()

      assert html =~ "Session Notes"
      assert html =~ "goals or notes"
    end
  end
end
