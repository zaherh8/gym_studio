defmodule GymStudioWeb.Admin.SessionsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  describe "Admin Sessions Management" do
    setup do
      admin = user_fixture(%{role: :admin})
      client = user_fixture(%{role: :client, name: "Session Client"})
      trainer = user_fixture(%{role: :trainer, name: "Session Trainer"})

      # Create an approved trainer profile so it appears in the dropdown
      {:ok, trainer_profile} =
        GymStudio.Accounts.create_trainer_profile(trainer)

      {:ok, _} = GymStudio.Accounts.approve_trainer(trainer_profile, admin)

      session = training_session_fixture(%{client_id: client.id})
      %{admin: admin, client: client, trainer: trainer, session: session}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/sessions")
    end

    test "lists sessions", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")

      assert html =~ "Manage Sessions"
      assert html =~ "Session Client"
      assert html =~ "pending"
    end

    test "filters sessions by status", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")

      html =
        view
        |> element("form")
        |> render_change(%{"status" => "pending", "trainer" => ""})

      assert html =~ "pending"
    end

    test "overrides session status", %{conn: conn, admin: admin, session: session} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")

      html = render_click(view, "set_status", %{"id" => session.id, "status" => "confirmed"})
      assert html =~ "confirmed"
    end

    test "assigns trainer to session", %{conn: conn, admin: admin, trainer: trainer, session: session} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")

      html = render_click(view, "assign_trainer", %{"id" => session.id, "trainer_id" => trainer.id})
      assert html =~ "Session Trainer"
    end
  end
end
