defmodule GymStudioWeb.Trainer.SessionLogLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures
  import GymStudio.ProgressFixtures

  setup do
    trainer_user = user_fixture(%{role: :trainer})
    trainer = trainer_fixture(%{user_id: trainer_user.id})
    admin = user_fixture(%{role: :admin})

    trainer
    |> GymStudio.Accounts.Trainer.approval_changeset(admin)
    |> GymStudio.Repo.update!()

    client_user = user_fixture(%{role: :client, name: "Test Client"})
    _client = client_fixture(%{user_id: client_user.id})

    package =
      package_fixture(%{
        client_id: client_user.id,
        assigned_by_id: admin.id,
        package_type: "standard_12"
      })

    session =
      training_session_fixture(%{
        client_id: client_user.id,
        trainer_id: trainer_user.id,
        package_id: package.id,
        status: "confirmed"
      })

    exercise = exercise_fixture(%{"name" => "Bench Press"})

    %{
      trainer_user: trainer_user,
      client_user: client_user,
      admin: admin,
      session: session,
      exercise: exercise
    }
  end

  test "renders session log page", %{conn: conn, trainer_user: trainer_user, session: session} do
    conn = log_in_user(conn, trainer_user)
    {:ok, _view, html} = live(conn, ~p"/trainer/sessions/#{session.id}/log")

    assert html =~ "Log Exercises"
    assert html =~ "Test Client"
    assert html =~ "No exercises logged yet"
  end

  test "also accessible via /exercises route", %{
    conn: conn,
    trainer_user: trainer_user,
    session: session
  } do
    conn = log_in_user(conn, trainer_user)
    {:ok, _view, html} = live(conn, ~p"/trainer/sessions/#{session.id}/exercises")

    assert html =~ "Log Exercises"
  end

  test "redirects for pending session", %{
    conn: conn,
    trainer_user: trainer_user,
    client_user: client_user
  } do
    pending_session =
      training_session_fixture(%{
        client_id: client_user.id,
        trainer_id: trainer_user.id,
        status: "pending"
      })

    conn = log_in_user(conn, trainer_user)

    {:ok, conn} =
      live(conn, ~p"/trainer/sessions/#{pending_session.id}/log") |> follow_redirect(conn)

    assert conn.resp_body =~ "My Sessions"
  end

  test "unauthorized trainer cannot access another trainer's session", %{
    conn: conn,
    session: session,
    admin: admin
  } do
    other_trainer_user = user_fixture(%{role: :trainer})
    other_trainer = trainer_fixture(%{user_id: other_trainer_user.id})

    other_trainer
    |> GymStudio.Accounts.Trainer.approval_changeset(admin)
    |> GymStudio.Repo.update!()

    conn = log_in_user(conn, other_trainer_user)

    {:ok, conn} =
      live(conn, ~p"/trainer/sessions/#{session.id}/log") |> follow_redirect(conn)

    assert conn.resp_body =~ "My Sessions"
  end

  test "can search and add exercise", %{
    conn: conn,
    trainer_user: trainer_user,
    session: session,
    exercise: exercise
  } do
    conn = log_in_user(conn, trainer_user)
    {:ok, view, _html} = live(conn, ~p"/trainer/sessions/#{session.id}/log")

    # Open search
    html = view |> element("button", "Add Exercise") |> render_click()
    assert html =~ "Search exercises"

    # Search
    html = view |> render_keyup("search_exercises", %{"query" => "Bench"})
    assert html =~ "Bench Press"

    # Add exercise
    html = view |> element("button[phx-value-exercise_id=\"#{exercise.id}\"]") |> render_click()
    assert html =~ "Bench Press"
    refute html =~ "No exercises logged yet"
  end

  test "can delete exercise log", %{
    conn: conn,
    trainer_user: trainer_user,
    session: session,
    exercise: exercise
  } do
    conn = log_in_user(conn, trainer_user)
    {:ok, view, _html} = live(conn, ~p"/trainer/sessions/#{session.id}/log")

    # Add exercise first
    view |> element("button", "Add Exercise") |> render_click()
    view |> render_keyup("search_exercises", %{"query" => "Bench"})
    view |> element("button[phx-value-exercise_id=\"#{exercise.id}\"]") |> render_click()

    # Delete it
    html = view |> element("button[phx-click=\"delete_log\"]") |> render_click()
    assert html =~ "No exercises logged yet"
  end
end
