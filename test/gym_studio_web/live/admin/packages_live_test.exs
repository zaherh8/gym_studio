defmodule GymStudioWeb.Admin.PackagesLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures

  describe "Admin Packages Management" do
    setup do
      admin = user_fixture(%{role: :admin})
      client = user_fixture(%{role: :client, name: "Package Client"})
      %{admin: admin, client: client}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/packages")
    end

    test "lists packages with status and usage", %{conn: conn, admin: admin, client: client} do
      _package = package_fixture(%{client_id: client.id, assigned_by_id: admin.id})

      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/packages")

      assert html =~ "Manage Packages"
      assert html =~ "Package Client"
      assert html =~ "standard_8"
      assert html =~ "Active"
    end

    test "renders new package form", %{conn: conn, admin: admin, client: client} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/packages/new")

      assert html =~ "Assign New Package"
      assert html =~ client.name
    end

    test "creates a new package", %{conn: conn, admin: admin, client: client} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/packages/new")

      view
      |> element("form")
      |> render_submit(%{
        "client_id" => client.id,
        "package_type" => "standard_12",
        "expires_at" => ""
      })

      assert_redirect(view, ~p"/admin/packages")
    end

    test "deactivates a package", %{conn: conn, admin: admin, client: client} do
      package = package_fixture(%{client_id: client.id, assigned_by_id: admin.id})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/packages")

      html = render_click(view, "deactivate", %{"id" => package.id})
      assert html =~ "Inactive"
    end
  end
end
