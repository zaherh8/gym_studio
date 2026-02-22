defmodule GymStudioWeb.Admin.ExercisesLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.ProgressFixtures

  describe "Admin Exercise Library" do
    setup do
      admin = user_fixture(%{role: :admin})
      %{admin: admin}
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, _}} = live(conn, ~p"/admin/exercises")
    end

    test "lists exercises", %{conn: conn, admin: admin} do
      _exercise = exercise_fixture(%{"name" => "Admin Test Bench"})

      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/exercises")

      assert html =~ "Exercise Library"
      assert html =~ "Admin Test Bench"
    end

    test "filters exercises by category", %{conn: conn, admin: admin} do
      _strength = exercise_fixture(%{"name" => "Filter Strength Ex", "category" => "strength"})

      _cardio =
        exercise_fixture(%{
          "name" => "Filter Cardio Ex",
          "category" => "cardio",
          "tracking_type" => "duration"
        })

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      html = render_change(view, "filter", %{"search" => "", "category" => "strength"})
      assert html =~ "Filter Strength Ex"
      refute html =~ "Filter Cardio Ex"
    end

    test "searches exercises", %{conn: conn, admin: admin} do
      _ex1 = exercise_fixture(%{"name" => "Search Target Alpha"})
      _ex2 = exercise_fixture(%{"name" => "Search Other Beta"})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      html = render_change(view, "filter", %{"search" => "Alpha", "category" => ""})
      assert html =~ "Search Target Alpha"
      refute html =~ "Search Other Beta"
    end

    test "creates a new exercise", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      render_click(view, "new")

      render_submit(view, "save", %{
        "exercise" => %{
          "name" => "New Admin Exercise",
          "category" => "strength",
          "tracking_type" => "weight_reps",
          "muscle_group" => "chest",
          "equipment" => "barbell",
          "description" => ""
        }
      })

      html = render(view)
      assert html =~ "New Admin Exercise"
    end

    test "edits an exercise", %{conn: conn, admin: admin} do
      exercise = exercise_fixture(%{"name" => "Editable Ex"})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      render_click(view, "edit", %{"id" => exercise.id})

      render_submit(view, "save", %{
        "exercise" => %{
          "name" => "Edited Ex Name",
          "category" => "strength",
          "tracking_type" => "weight_reps"
        }
      })

      html = render(view)
      assert html =~ "Edited Ex Name"
    end

    test "deletes custom exercise", %{conn: conn, admin: admin} do
      exercise = custom_exercise_fixture(admin, %{"name" => "Deletable Ex"})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      render_click(view, "delete", %{"id" => exercise.id})
      html = render(view)
      refute html =~ "Deletable Ex"
    end

    test "cannot delete predefined exercise", %{conn: conn, admin: admin} do
      exercise = exercise_fixture(%{"name" => "Protected Ex"})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/exercises")

      render_click(view, "delete", %{"id" => exercise.id})
      assert render(view) =~ "Protected Ex"
    end
  end
end
