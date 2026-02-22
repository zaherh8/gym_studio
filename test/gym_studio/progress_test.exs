defmodule GymStudio.ProgressTest do
  use GymStudio.DataCase

  alias GymStudio.Progress
  alias GymStudio.Progress.Exercise

  import GymStudio.AccountsFixtures
  import GymStudio.ProgressFixtures

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
end
