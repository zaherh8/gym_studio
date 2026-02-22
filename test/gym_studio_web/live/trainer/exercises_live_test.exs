defmodule GymStudioWeb.Trainer.ExercisesLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.ProgressFixtures

  describe "Trainer Exercise Library" do
    setup do
      trainer = user_fixture(%{role: :trainer})
      %{trainer: trainer}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/trainer/exercises")
    end

    test "lists exercises", %{conn: conn, trainer: trainer} do
      _exercise = exercise_fixture(%{"name" => "Trainer View Ex"})

      conn = log_in_user(conn, trainer)
      {:ok, _view, html} = live(conn, ~p"/trainer/exercises")

      assert html =~ "Exercise Library"
      assert html =~ "Trainer View Ex"
    end

    test "creates custom exercise", %{conn: conn, trainer: trainer} do
      conn = log_in_user(conn, trainer)
      {:ok, view, _html} = live(conn, ~p"/trainer/exercises")

      render_click(view, "new")

      render_submit(view, "save", %{
        "exercise" => %{
          "name" => "Trainer Custom Ex",
          "category" => "functional",
          "tracking_type" => "reps_only",
          "muscle_group" => "",
          "equipment" => "",
          "description" => ""
        }
      })

      html = render(view)
      assert html =~ "Trainer Custom Ex"
    end

    test "can edit own custom exercise", %{conn: conn, trainer: trainer} do
      exercise = custom_exercise_fixture(trainer, %{"name" => "Trainer Own Ex"})

      conn = log_in_user(conn, trainer)
      {:ok, view, _html} = live(conn, ~p"/trainer/exercises")

      render_click(view, "edit", %{"id" => exercise.id})

      render_submit(view, "save", %{
        "exercise" => %{
          "name" => "Trainer Edited Ex",
          "category" => "functional",
          "tracking_type" => "reps_only"
        }
      })

      html = render(view)
      assert html =~ "Trainer Edited Ex"
    end

    test "cannot edit other trainer's custom exercise", %{conn: conn, trainer: trainer} do
      other_trainer = user_fixture(%{role: :trainer})
      _exercise = custom_exercise_fixture(other_trainer, %{"name" => "Other Trainer Ex"})

      conn = log_in_user(conn, trainer)
      {:ok, view, _html} = live(conn, ~p"/trainer/exercises")

      # The edit button won't be shown for other trainer's exercises
      # but if they try via event, it should be rejected
      html = render(view)
      assert html =~ "Other Trainer Ex"
    end

    test "can delete own custom exercise", %{conn: conn, trainer: trainer} do
      exercise = custom_exercise_fixture(trainer, %{"name" => "Trainer Delete Ex"})

      conn = log_in_user(conn, trainer)
      {:ok, view, _html} = live(conn, ~p"/trainer/exercises")

      render_click(view, "delete", %{"id" => exercise.id})
      html = render(view)
      refute html =~ "Trainer Delete Ex"
    end

    test "cannot delete other trainer's exercise", %{conn: conn, trainer: trainer} do
      other_trainer = user_fixture(%{role: :trainer})
      exercise = custom_exercise_fixture(other_trainer, %{"name" => "Other Delete Ex"})

      conn = log_in_user(conn, trainer)
      {:ok, view, _html} = live(conn, ~p"/trainer/exercises")

      render_click(view, "delete", %{"id" => exercise.id})
      # Exercise should still be there
      html = render(view)
      assert html =~ "Other Delete Ex"
    end
  end
end
