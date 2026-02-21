defmodule GymStudioWeb.Admin.UsersLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures

  describe "Admin Users Management" do
    setup do
      admin = user_fixture(%{role: :admin})
      client = user_fixture(%{role: :client, name: "Test Client"})
      trainer = user_fixture(%{role: :trainer, name: "Test Trainer"})
      %{admin: admin, client: client, trainer: trainer}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/users")
    end

    test "lists all users", %{conn: conn, admin: admin, client: client, trainer: trainer} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Manage Users"
      assert html =~ client.name
      assert html =~ trainer.name
    end

    test "filters users by role", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html =
        view
        |> element("form")
        |> render_change(%{"search" => "", "role" => "client"})

      assert html =~ "client"
    end

    test "searches users by name", %{conn: conn, admin: admin, client: client} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html =
        view
        |> element("form")
        |> render_change(%{"search" => client.name, "role" => ""})

      assert html =~ client.name
    end

    test "toggles user active status", %{conn: conn, admin: admin, client: client} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html = render_click(view, "toggle_active", %{"id" => client.id})
      assert html =~ "Inactive"
    end

    test "changes user role with confirmation", %{conn: conn, admin: admin, client: client} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Show confirmation dialog
      render_click(view, "show_role_change", %{"id" => client.id, "role" => "trainer"})
      html = render(view)
      assert html =~ "Confirm Role Change"

      # Confirm
      html = render_click(view, "confirm_role_change", %{})
      assert html =~ "trainer"
    end
  end
end
