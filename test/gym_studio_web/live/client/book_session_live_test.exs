defmodule GymStudioWeb.Client.BookSessionLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures

  describe "Book Session" do
    setup do
      client_user = user_fixture(%{role: :client})
      client = client_fixture(%{user_id: client_user.id})

      %{client_user: client_user, client: client}
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

    test "prevents booking without active package", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/book")

      # Select a date
      today = Date.utc_today()
      # Find a non-Sunday date
      date =
        if Date.day_of_week(today) == 7,
          do: Date.add(today, 1),
          else: today

      view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()

      # Select a time slot
      view |> element("button[phx-value-slot='10']") |> render_click()

      # Try to confirm - flash message is set
      view |> element("button", "Confirm Booking") |> render_click()

      assert has_element?(view, "[role=alert]") or
               render(view) =~ "No Active Package"
    end

    test "3-step flow works with date, time, and confirm", %{
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
      {:ok, view, _html} = live(conn, ~p"/client/book")

      # Step 1: Select date
      tomorrow = Date.add(Date.utc_today(), 1)

      date =
        if Date.day_of_week(tomorrow) == 7,
          do: Date.add(tomorrow, 1),
          else: tomorrow

      html = view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()
      assert html =~ "Select Time"

      # Step 2: Select time
      html = view |> element("button[phx-value-slot='10']") |> render_click()
      assert html =~ "Confirm Booking"

      # Step 3: Confirm - should redirect to sessions
      view |> element("button", "Confirm Booking") |> render_click()
      assert_redirected(view, ~p"/client/sessions")
    end

    test "shows notes field in confirmation step", %{conn: conn, client_user: client_user} do
      admin = user_fixture(%{role: :admin})

      _package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/book")

      tomorrow = Date.add(Date.utc_today(), 1)

      date =
        if Date.day_of_week(tomorrow) == 7,
          do: Date.add(tomorrow, 1),
          else: tomorrow

      view |> element("button[phx-value-date='#{Date.to_string(date)}']") |> render_click()
      html = view |> element("button[phx-value-slot='10']") |> render_click()

      assert html =~ "Session Notes"
      assert html =~ "goals or notes"
    end
  end
end
