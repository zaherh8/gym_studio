defmodule GymStudio.GoalsFixtures do
  @moduledoc """
  Test helpers for creating fitness goals.
  """

  alias GymStudio.Goals

  def valid_goal_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "title" => "Bench Press #{System.unique_integer([:positive])}kg",
      "target_value" => "100",
      "target_unit" => "kg",
      "description" => "Test goal"
    })
  end

  def goal_fixture(attrs \\ %{}) do
    {:ok, goal} =
      attrs
      |> valid_goal_attributes()
      |> Goals.create_goal()

    goal
  end
end
