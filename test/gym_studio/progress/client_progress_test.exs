defmodule GymStudio.Progress.ClientProgressTest do
  use GymStudio.DataCase

  alias GymStudio.Progress

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

    exercise = exercise_fixture(%{"name" => "Bench Press", "category" => "strength"})

    exercise2 =
      exercise_fixture(%{
        "name" => "Treadmill Run",
        "category" => "cardio",
        "tracking_type" => "duration"
      })

    %{
      client_user: client_user,
      client: client,
      trainer_user: trainer_user,
      admin: admin,
      session: session,
      exercise: exercise,
      exercise2: exercise2
    }
  end

  describe "list_client_exercises/1" do
    test "returns empty list when client has no logs", %{client_user: client_user} do
      assert Progress.list_client_exercises(client_user.id) == []
    end

    test "returns exercises with stats", %{
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      _log =
        exercise_log_fixture(%{
          "training_session_id" => session.id,
          "exercise_id" => exercise.id,
          "client_id" => client_user.id,
          "logged_by_id" => trainer_user.id,
          "sets" => 3,
          "reps" => 10,
          "weight_kg" => Decimal.new("80.0")
        })

      result = Progress.list_client_exercises(client_user.id)
      assert length(result) == 1
      [ex] = result
      assert ex.exercise_name == "Bench Press"
      assert ex.total_sessions == 1
      assert ex.latest_sets == 3
      assert ex.latest_reps == 10
      assert Decimal.equal?(ex.latest_weight_kg, Decimal.new("80.0"))
      assert ex.has_pr == true
    end

    test "filters by category", %{
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise,
      exercise2: exercise2
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

      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise2.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "duration_seconds" => 1800
      })

      result = Progress.list_client_exercises(client_user.id, category: "strength")
      assert length(result) == 1
      assert hd(result).exercise_name == "Bench Press"

      result = Progress.list_client_exercises(client_user.id, category: "cardio")
      assert length(result) == 1
      assert hd(result).exercise_name == "Treadmill Run"
    end
  end

  describe "get_exercise_history/2" do
    test "returns logs ordered by date desc", %{
      client_user: client_user,
      trainer_user: trainer_user,
      session: session,
      exercise: exercise
    } do
      _log1 =
        exercise_log_fixture(%{
          "training_session_id" => session.id,
          "exercise_id" => exercise.id,
          "client_id" => client_user.id,
          "logged_by_id" => trainer_user.id,
          "sets" => 3,
          "reps" => 10,
          "weight_kg" => Decimal.new("60.0")
        })

      _log2 =
        exercise_log_fixture(%{
          "training_session_id" => session.id,
          "exercise_id" => exercise.id,
          "client_id" => client_user.id,
          "logged_by_id" => trainer_user.id,
          "sets" => 4,
          "reps" => 8,
          "weight_kg" => Decimal.new("70.0")
        })

      history = Progress.get_exercise_history(client_user.id, exercise.id)
      assert length(history) == 2
      weights = Enum.map(history, & &1.weight_kg)
      assert Decimal.new("60.0") in weights
      assert Decimal.new("70.0") in weights
    end

    test "returns empty list for no logs", %{client_user: client_user, exercise: exercise} do
      assert Progress.get_exercise_history(client_user.id, exercise.id) == []
    end
  end

  describe "get_exercise_stats/2" do
    test "returns correct stats", %{
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
        "weight_kg" => Decimal.new("60.0")
      })

      exercise_log_fixture(%{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client_user.id,
        "logged_by_id" => trainer_user.id,
        "sets" => 4,
        "reps" => 8,
        "weight_kg" => Decimal.new("80.0")
      })

      stats = Progress.get_exercise_stats(client_user.id, exercise.id)
      assert Decimal.equal?(stats.max_weight_kg, Decimal.new("80.0"))
      assert stats.max_reps == 10
      assert stats.total_sessions == 2
      # Volume: (3*10*60) + (4*8*80) = 1800 + 2560 = 4360
      assert Decimal.equal?(stats.total_volume, Decimal.new("4360.0"))
    end

    test "returns zero stats for no logs", %{client_user: client_user, exercise: exercise} do
      stats = Progress.get_exercise_stats(client_user.id, exercise.id)
      assert stats.max_weight_kg == nil
      assert stats.max_reps == nil
      assert stats.total_sessions == 0
    end
  end
end
