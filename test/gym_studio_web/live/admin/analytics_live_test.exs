defmodule GymStudioWeb.Admin.AnalyticsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  describe "Admin Analytics" do
    setup do
      admin = user_fixture(%{role: :admin})
      client = user_fixture(%{role: :client})
      _session = training_session_fixture(%{client_id: client.id})
      %{admin: admin}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/analytics")
    end

    test "renders analytics page with all sections", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/analytics")

      assert html =~ "Analytics"
      assert html =~ "Sessions by Status"
      assert html =~ "Sessions Per Week"
      assert html =~ "Popular Time Slots"
      assert html =~ "Trainer Session Counts"
      assert html =~ "Revenue tracking coming soon"
    end

    test "shows session status cards", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/analytics")

      assert html =~ "Pending"
      assert html =~ "Confirmed"
      assert html =~ "Completed"
      assert html =~ "Cancelled"
      assert html =~ "Total"
    end
  end
end
