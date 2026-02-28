defmodule GymStudioWeb.Client.ProgressLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.ProgressFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  setup do
    client_user = user_fixture(%{role: :client})
    client = client_fixture(%{user_id: client_user.id})
    trainer_user = user_fixture(%{role: :trainer})
    _trainer = trainer_fixture(%{user_id: trainer_user.id})
    admin = user_fixture(%{role: :admin})

    package =
      used_package_fixture(%{
        client_id: client_user.id,
        assigned_by_id: admin.id,
        package_type: "standard_8"
      })

    session =
      training_session_fixture(%{
        client_id: client_user.id,
        trainer_id: trainer_user.id,
        package_id: package.id,
        status: "completed"
      })

    exercise = exercise_fixture(%{"name" => "Test Bench Press", "category" => "strength"})

    %{
      client_user: client_user,
      client: client,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    }
  end

  describe "Progress Dashboard" do
    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/client/progress")
      assert redirect_path == ~p"/users/log-in"
    end

    test "renders empty state when no exercises", %{conn: conn, client_user: client_user} do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/progress")

      assert html =~ "My Progress"
      assert html =~ "No exercises logged yet"
    end

    test "renders exercise cards with stats", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "sets" => 3,
        "reps" => 10,
        "weight_kg" => Decimal.new("80.0")
      })

      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/progress")

      assert html =~ "Test Bench Press"
      assert html =~ "80.0 kg"
      assert html =~ "1 session(s) logged"
      assert html =~ "🏆"
    end

    test "filters by category", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      cardio_exercise =
        exercise_fixture(%{
          "name" => "Test Treadmill",
          "category" => "cardio",
          "tracking_type" => "duration"
        })

      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "sets" => 3,
        "reps" => 10,
        "weight_kg" => Decimal.new("80.0")
      })

      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => cardio_exercise.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "duration_seconds" => 1800
      })

      conn = log_in_user(conn, client_user)
      {:ok, view, _html} = live(conn, ~p"/client/progress")

      html = render_change(view, "filter_category", %{"category" => "strength"})
      assert html =~ "Test Bench Press"
      refute html =~ "Test Treadmill"

      html = render_change(view, "filter_category", %{"category" => ""})
      assert html =~ "Test Bench Press"
      assert html =~ "Test Treadmill"
    end
  end

  describe "Exercise Detail" do
    test "requires authentication", %{conn: conn, exercise: exercise} do
      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, ~p"/client/progress/exercises/#{exercise.id}")

      assert redirect_path == ~p"/users/log-in"
    end

    test "renders exercise detail with stats", %{
      conn: conn,
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "sets" => 3,
        "reps" => 10,
        "weight_kg" => Decimal.new("80.0")
      })

      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/progress/exercises/#{exercise.id}")

      assert html =~ "Test Bench Press"
      assert html =~ "Max Weight"
      assert html =~ "80.0"
      assert html =~ "Max Reps"
      assert html =~ "10"
      assert html =~ "Total Sessions"
      assert html =~ "Exercise History"
    end

    test "shows empty state for exercise with no logs", %{
      conn: conn,
      client_user: client_user,
      exercise: exercise
    } do
      conn = log_in_user(conn, client_user)
      {:ok, _view, html} = live(conn, ~p"/client/progress/exercises/#{exercise.id}")

      assert html =~ "No history found"
    end

    test "client cannot see another client's data", %{
      conn: conn,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      other_client = user_fixture(%{role: :client})
      _other_client_record = client_fixture(%{user_id: other_client.id})

      # Log exercise for original client (session.client_id)
      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => session.client_id,
        "logged_by_id" => trainer_user.id,
        "sets" => 5,
        "reps" => 5,
        "weight_kg" => Decimal.new("100.0")
      })

      # other_client should see empty
      conn = log_in_user(conn, other_client)
      {:ok, _view, html} = live(conn, ~p"/client/progress/exercises/#{exercise.id}")

      assert html =~ "No history found"
      refute html =~ "100.0"
    end
  end
end
