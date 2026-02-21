defmodule GymStudioWeb.Admin.DashboardLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures

  describe "Admin Dashboard" do
    setup do
      admin = user_fixture(%{role: :admin})
      %{admin: admin}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin")
    end

    test "renders dashboard for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Admin Dashboard"
      assert html =~ "Total Clients"
      assert html =~ "Total Trainers"
      assert html =~ "Active Packages"
      assert html =~ "Quick Actions"
    end

    test "shows user counts", %{conn: conn, admin: admin} do
      _client = user_fixture(%{role: :client})
      _trainer = user_fixture(%{role: :trainer})

      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Total Clients"
      assert html =~ "Total Trainers"
      assert html =~ "Admins"
    end

    test "shows quick action links", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Manage Sessions"
      assert html =~ "Manage Trainers"
      assert html =~ "Assign Package"
      assert html =~ "Manage Users"
      assert html =~ "Analytics"
    end

    test "shows session stats", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Sessions Today"
      assert html =~ "Sessions This Week"
      assert html =~ "Pending Sessions"
    end
  end
end
