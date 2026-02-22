defmodule GymStudio.ProgressTest do
  use GymStudio.DataCase

  alias GymStudio.Progress
  alias GymStudio.Progress.Exercise

  import GymStudio.AccountsFixtures
  import GymStudio.ProgressFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures

  describe "exercises" do
    test "list_exercises/0 returns all exercises" do
      exercise = exercise_fixture()
      assert exercise in Progress.list_exercises()
    end

    test "list_exercises/1 filters by category" do
      strength = exercise_fixture(%{"category" => "strength", "name" => "Str Ex"})

      _cardio =
        exercise_fixture(%{
          "category" => "cardio",
          "name" => "Car Ex",
          "tracking_type" => "duration"
        })

      result = Progress.list_exercises(category: "strength")
      assert strength in result
      refute Enum.any?(result, &(&1.category == "cardio"))
    end

    test "list_exercises/1 filters by search" do
      bench = exercise_fixture(%{"name" => "Unique Bench Press"})
      _squat = exercise_fixture(%{"name" => "Unique Squat"})

      result = Progress.list_exercises(search: "Bench")
      assert bench in result
      assert length(result) == 1
    end

    test "list_exercises/1 filters custom_only" do
      user = user_fixture()
      _predefined = exercise_fixture(%{"name" => "Pred Ex"})
      custom = custom_exercise_fixture(user, %{"name" => "Cust Ex"})

      result = Progress.list_exercises(custom_only: true)
      assert custom in result
      refute Enum.any?(result, &(&1.is_custom == false))
    end

    test "get_exercise!/1 returns the exercise" do
      exercise = exercise_fixture()
      assert Progress.get_exercise!(exercise.id) == exercise
    end

    test "create_exercise/2 with valid data creates an exercise" do
      assert {:ok, %Exercise{} = exercise} =
               Progress.create_exercise(%{
                 "name" => "New Exercise",
                 "category" => "strength",
                 "tracking_type" => "weight_reps"
               })

      assert exercise.name == "New Exercise"
      assert exercise.is_custom == false
    end

    test "create_exercise/2 with user sets is_custom and created_by_id" do
      user = user_fixture()

      assert {:ok, %Exercise{} = exercise} =
               Progress.create_exercise(
                 %{"name" => "Custom Ex", "category" => "cardio", "tracking_type" => "duration"},
                 user
               )

      assert exercise.is_custom == true
      assert exercise.created_by_id == user.id
    end

    test "create_exercise/2 with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = Progress.create_exercise(%{"name" => ""})
    end

    test "create_exercise/2 enforces unique name" do
      exercise_fixture(%{"name" => "Duplicate Name"})

      assert {:error, changeset} =
               Progress.create_exercise(%{
                 "name" => "Duplicate Name",
                 "category" => "strength",
                 "tracking_type" => "weight_reps"
               })

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "update_exercise/2 updates the exercise" do
      exercise = exercise_fixture()
      assert {:ok, updated} = Progress.update_exercise(exercise, %{"name" => "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "delete_exercise/1 deletes custom exercises" do
      user = user_fixture()
      exercise = custom_exercise_fixture(user)
      assert {:ok, _} = Progress.delete_exercise(exercise)
      assert_raise Ecto.NoResultsError, fn -> Progress.get_exercise!(exercise.id) end
    end

    test "delete_exercise/1 rejects predefined exercises" do
      exercise = exercise_fixture()
      assert {:error, :cannot_delete_predefined} = Progress.delete_exercise(exercise)
    end

    test "search_exercises/1 returns matching exercises" do
      exercise = exercise_fixture(%{"name" => "Searchable Bench Press"})
      results = Progress.search_exercises("Searchable")
      assert exercise in results
    end

    test "search_exercises/1 escapes ILIKE wildcards" do
      exercise = exercise_fixture(%{"name" => "100% Effort Exercise"})
      results = Progress.search_exercises("100%")
      assert exercise in results
    end

    test "list_categories/0 returns categories" do
      assert "strength" in Progress.list_categories()
      assert "cardio" in Progress.list_categories()
    end

    test "list_muscle_groups/0 returns muscle groups" do
      assert "chest" in Progress.list_muscle_groups()
    end

    test "list_equipment/0 returns equipment" do
      assert "barbell" in Progress.list_equipment()
    end
  end

  describe "exercise_logs" do
    setup do
      trainer_user = user_fixture(%{role: :trainer})
      admin = user_fixture(%{role: :admin})
      client_user = user_fixture(%{role: :client})
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

      exercise = exercise_fixture(%{"name" => "Test Bench Press"})

      %{
        trainer_user: trainer_user,
        client_user: client_user,
        session: session,
        exercise: exercise
      }
    end

    test "create_exercise_log/1 creates a log", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      attrs = %{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client.id,
        "logged_by_id" => trainer.id,
        "sets" => 3,
        "reps" => 10,
        "weight_kg" => "50.0",
        "order" => 0
      }

      assert {:ok, log} = Progress.create_exercise_log(attrs)
      assert log.sets == 3
      assert log.reps == 10
    end

    test "create_exercise_log/1 requires at least one metric", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      attrs = %{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client.id,
        "logged_by_id" => trainer.id,
        "order" => 0
      }

      assert {:error, changeset} = Progress.create_exercise_log(attrs)
      assert errors_on(changeset)[:sets] != nil
    end

    test "list_exercise_logs/1 returns ordered logs", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      base = %{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client.id,
        "logged_by_id" => trainer.id,
        "sets" => 3,
        "reps" => 10
      }

      {:ok, _log1} = Progress.create_exercise_log(Map.put(base, "order", 1))
      {:ok, _log0} = Progress.create_exercise_log(Map.put(base, "order", 0))

      logs = Progress.list_exercise_logs(session.id)
      assert length(logs) == 2
      assert Enum.at(logs, 0).order == 0
      assert Enum.at(logs, 1).order == 1
    end

    test "update_exercise_log/2 updates a log", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      {:ok, log} =
        Progress.create_exercise_log(%{
          "training_session_id" => session.id,
          "exercise_id" => exercise.id,
          "client_id" => client.id,
          "logged_by_id" => trainer.id,
          "sets" => 3,
          "reps" => 10,
          "order" => 0
        })

      assert {:ok, updated} = Progress.update_exercise_log(log, %{"sets" => 5})
      assert updated.sets == 5
    end

    test "delete_exercise_log/1 deletes a log", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      {:ok, log} =
        Progress.create_exercise_log(%{
          "training_session_id" => session.id,
          "exercise_id" => exercise.id,
          "client_id" => client.id,
          "logged_by_id" => trainer.id,
          "sets" => 3,
          "reps" => 10,
          "order" => 0
        })

      assert {:ok, _} = Progress.delete_exercise_log(log)
      assert_raise Ecto.NoResultsError, fn -> Progress.get_exercise_log!(log.id) end
    end

    test "get_personal_records/1 returns best weight per exercise", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      base = %{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client.id,
        "logged_by_id" => trainer.id,
        "sets" => 3,
        "reps" => 10,
        "order" => 0
      }

      {:ok, _} = Progress.create_exercise_log(Map.put(base, "weight_kg", "50.0"))

      {:ok, _} =
        Progress.create_exercise_log(Map.merge(base, %{"weight_kg" => "80.0", "order" => 1}))

      records = Progress.get_personal_records(client.id)
      assert length(records) == 1
      record = hd(records)
      assert record.exercise_name == "Test Bench Press"
      assert Decimal.equal?(record.max_weight_kg, Decimal.new("80.0"))
    end

    test "reorder_exercise_logs/2 updates order", %{
      session: session,
      exercise: exercise,
      trainer_user: trainer,
      client_user: client
    } do
      base = %{
        "training_session_id" => session.id,
        "exercise_id" => exercise.id,
        "client_id" => client.id,
        "logged_by_id" => trainer.id,
        "sets" => 3,
        "reps" => 10
      }

      {:ok, log0} = Progress.create_exercise_log(Map.put(base, "order", 0))
      {:ok, log1} = Progress.create_exercise_log(Map.put(base, "order", 1))

      # Reverse order
      assert {:ok, _} = Progress.reorder_exercise_logs(session.id, [log1.id, log0.id])

      logs = Progress.list_exercise_logs(session.id)
      assert Enum.at(logs, 0).id == log1.id
      assert Enum.at(logs, 1).id == log0.id
    end
  end
end
