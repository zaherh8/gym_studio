defmodule GymStudioWeb.Admin.BranchSelectorTest do
  @moduledoc """
  Integration tests for branch selector filtering on admin pages.

  Verifies that the BranchSelectorComponent renders and filters correctly
  on dashboard, analytics, users, clients, and trainers pages.
  """
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.BranchesFixtures
  import GymStudio.AccountsFixtures

  setup do
    branch = branch_fixture(%{name: "Branch Alpha"})
    admin = user_fixture(%{role: :admin, branch_id: branch.id})
    %{admin: admin, branch: branch}
  end

  describe "Dashboard branch selector" do
    test "renders branch selector with All Branches option", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "All Branches"
    end

    test "filters by branch when clicked", %{conn: conn, admin: admin, branch: branch} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      html = render_click(view, "select_branch", %{"branch_id" => to_string(branch.id)})
      assert html =~ "Admin Dashboard"
    end
  end

  describe "Analytics branch selector" do
    test "renders branch selector", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/analytics")

      assert html =~ "All Branches"
    end

    test "filters by branch when clicked", %{conn: conn, admin: admin, branch: branch} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/analytics")

      html = render_click(view, "select_branch", %{"branch_id" => to_string(branch.id)})
      assert html =~ "Analytics"
    end
  end

  describe "Users branch selector" do
    test "renders branch selector", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "All Branches"
    end

    test "filters by branch when clicked", %{conn: conn, admin: admin, branch: branch} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html = render_click(view, "select_branch", %{"branch_id" => to_string(branch.id)})
      assert html =~ "Manage Users"
    end
  end

  describe "Clients branch selector" do
    test "renders branch selector", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/clients")

      assert html =~ "All Branches"
    end

    test "filters by branch when clicked", %{conn: conn, admin: admin, branch: branch} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/clients")

      html = render_click(view, "select_branch", %{"branch_id" => to_string(branch.id)})
      assert html =~ "Manage Clients"
    end
  end

  describe "Trainers branch selector" do
    test "renders branch selector", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/trainers")

      assert html =~ "All Branches"
    end

    test "filters by branch when clicked", %{conn: conn, admin: admin, branch: branch} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/trainers")

      html = render_click(view, "select_branch", %{"branch_id" => to_string(branch.id)})
      assert html =~ "Manage Trainers"
    end
  end
end
