defmodule GymStudioWeb.Admin.BranchesLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.BranchesFixtures
  import GymStudio.AccountsFixtures

  describe "Branch list page" do
    setup do
      branch = branch_fixture(%{name: "Test Branch Alpha", capacity: 6})
      admin = user_fixture(%{role: :admin, branch_id: branch.id})
      %{admin: admin, branch: branch}
    end

    test "renders branches list", %{conn: conn, admin: admin} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches")

      assert html =~ "Test Branch Alpha"
    end

    test "shows branch status badges", %{conn: conn, admin: admin} do
      _inactive_branch = branch_fixture(%{name: "Inactive Branch", active: false})

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches")

      assert html =~ "Test Branch Alpha"
      assert html =~ "Inactive Branch"
    end
  end

  describe "Branch show page" do
    setup do
      branch =
        branch_fixture(%{
          name: "Show Branch",
          address: "123 Main St",
          capacity: 8,
          phone: "+961 1 234 567"
        })

      admin = user_fixture(%{role: :admin, branch_id: branch.id})
      %{admin: admin, branch: branch}
    end

    test "shows branch details and stats", %{conn: conn, admin: admin, branch: branch} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches/#{branch.id}")

      assert html =~ "Show Branch"
      assert html =~ "123 Main St"
    end
  end

  describe "Branch creation" do
    setup do
      branch = branch_fixture()
      admin = user_fixture(%{role: :admin, branch_id: branch.id})
      %{admin: admin}
    end

    test "renders new branch form", %{conn: conn, admin: admin} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches/new")

      assert html =~ "New Branch"
    end

    test "creates a new branch via LiveView form", %{conn: conn, admin: admin} do
      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches/new")

      view
      |> form("form",
        branch: %{
          name: "New Test Branch",
          slug: "new-test-branch",
          capacity: 10,
          address: "456 Oak Ave"
        }
      )
      |> render_submit()

      # Should redirect to branches list on success
      assert_redirect(view, ~p"/admin/branches")
    end
  end

  describe "Branch editing" do
    setup do
      branch = branch_fixture(%{name: "Edit Me", capacity: 5})
      admin = user_fixture(%{role: :admin, branch_id: branch.id})
      %{admin: admin, branch: branch}
    end

    test "renders edit form with existing data", %{conn: conn, admin: admin, branch: branch} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches/#{branch.id}/edit")

      assert html =~ "Edit Branch"
      assert html =~ "Edit Me"
    end
  end

  describe "Toggle branch active status" do
    test "deactivates an active branch", %{conn: conn} do
      branch = branch_fixture(%{name: "Toggle Branch", active: true})
      admin = user_fixture(%{role: :admin, branch_id: branch.id})

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches")

      html =
        view
        |> element("button[phx-click='toggle_active'][phx-value-id='#{branch.id}']")
        |> render_click()

      # After deactivation, the branch should show "Activate" button
      assert html =~ "Activate"
    end

    test "activates an inactive branch", %{conn: conn} do
      branch = branch_fixture(%{name: "Inactive Branch", active: false})
      other_branch = branch_fixture()
      admin = user_fixture(%{role: :admin, branch_id: other_branch.id})

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/branches")

      html =
        view
        |> element("button[phx-click='toggle_active'][phx-value-id='#{branch.id}']")
        |> render_click()

      # After activation, should show "Deactivate" button
      assert html =~ "Deactivate"
    end
  end
end
