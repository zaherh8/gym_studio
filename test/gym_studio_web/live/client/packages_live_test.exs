defmodule GymStudioWeb.Client.PackagesLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures

  describe "Packages View" do
    setup do
      client_user = user_fixture(%{role: :client})
      client = client_fixture(%{user_id: client_user.id})

      %{client_user: client_user, client: client}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/client/packages")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders packages page", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/packages")

      assert html =~ "My Packages"
    end

    test "shows empty state when no packages", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/packages")

      assert html =~ "don&#39;t have any packages"
      assert html =~ "Contact your trainer"
    end

    test "displays active package with progress bar", %{conn: conn, client_user: client_user} do
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
      {:ok, _view, html} = live(conn, ~p"/client/packages")

      assert html =~ "Active"
      assert html =~ "8"
      assert html =~ "of 12 sessions remaining"
      assert html =~ "Expires:"
    end

    test "displays available package options", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/packages")

      assert html =~ "Available Packages"
      assert html =~ "Contact your trainer"
    end
  end
end
