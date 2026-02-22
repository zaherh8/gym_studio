defmodule GymStudio.ProgressFixtures do
  alias GymStudio.Progress

  def exercise_fixture(attrs \\ %{}) do
    {:ok, exercise} =
      attrs
      |> Enum.into(%{
        "name" => "Exercise #{System.unique_integer([:positive])}",
        "category" => "strength",
        "tracking_type" => "weight_reps",
        "muscle_group" => "chest",
        "equipment" => "barbell"
      })
      |> Progress.create_exercise()

    exercise
  end

  def custom_exercise_fixture(user, attrs \\ %{}) do
    {:ok, exercise} =
      attrs
      |> Enum.into(%{
        "name" => "Custom Exercise #{System.unique_integer([:positive])}",
        "category" => "strength",
        "tracking_type" => "weight_reps"
      })
      |> Progress.create_exercise(user)

    exercise
  end

  def exercise_log_fixture(attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{
        "sets" => 3,
        "reps" => 10,
        "weight_kg" => Decimal.new("50.0"),
        "order" => 0
      })
      |> Progress.create_exercise_log()

    log
  end
end
