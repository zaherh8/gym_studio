defmodule GymStudioWeb.Trainer.SessionsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "Trainer Sessions" do
    setup do
      trainer_user = user_fixture(%{role: :trainer})
      trainer = trainer_fixture(%{user_id: trainer_user.id})
      admin = user_fixture(%{role: :admin})

      trainer =
        trainer
        |> GymStudio.Accounts.Trainer.approval_changeset(admin)
        |> GymStudio.Repo.update!()

      %{trainer_user: trainer_user, trainer: trainer, admin: admin}
    end

    test "renders sessions page with empty state", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/sessions")

      assert html =~ "My Sessions"
      assert html =~ "No sessions found"
    end

    test "displays sessions with client name and email", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Alice Smith"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/sessions")

      assert html =~ "Alice Smith"
      assert html =~ "badge-success"
    end

    test "filters sessions by status", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client, name: "Filter Client"})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/sessions")

      # Filter to confirmed - should show empty
      html = render_click(view, "filter", %{"status" => "confirmed"})
      assert html =~ "No sessions found"

      # Filter to pending - should show session
      html = render_click(view, "filter", %{"status" => "pending"})
      assert html =~ "Filter Client"
    end

    test "confirms a pending session", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/sessions")

      html = render_click(view, "confirm_session", %{"session_id" => session.id})
      assert html =~ "badge-success"
    end

    test "cancels a session with reason", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/sessions")

      # Open cancel modal
      html = render_click(view, "open_cancel_modal", %{"session_id" => session.id})
      assert html =~ "Cancel Session"

      render_click(view, "update_cancel_reason", %{"reason" => "Schedule conflict"})
      html = render_click(view, "cancel_session")
      assert html =~ "badge-error"
    end

    test "completes a session with notes", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      today = Date.utc_today()
      today_at_2pm = DateTime.new!(today, ~T[14:00:00], "Etc/UTC")

      session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: today_at_2pm,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/sessions")

      # Open complete modal
      html = render_click(view, "open_complete_modal", %{"session_id" => session.id})
      assert html =~ "Complete Session"

      render_click(view, "update_trainer_notes", %{"notes" => "Client did great"})
      html = render_click(view, "complete_session")
      assert html =~ "badge-info"
    end

    test "shows status badges with correct colors", %{
      conn: conn,
      trainer_user: trainer_user,
      admin: admin
    } do
      client_user = user_fixture(%{role: :client})
      _client = client_fixture(%{user_id: client_user.id})

      package =
        package_fixture(%{
          client_id: client_user.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        })

      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      _pending =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          package_id: package.id,
          scheduled_at: tomorrow,
          status: "pending"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/sessions")

      assert html =~ "badge-warning"
    end
  end
end
