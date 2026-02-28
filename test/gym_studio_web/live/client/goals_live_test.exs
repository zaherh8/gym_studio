defmodule GymStudioWeb.Client.GoalsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.GoalsFixtures

  setup do
    client_user = user_fixture(%{role: :client})
    _client = client_fixture(%{user_id: client_user.id})
    %{client_user: client_user}
  end

  describe "Goals page" do
    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/client/progress/goals")
      assert path == ~p"/users/log-in"
    end

    test "renders empty state", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/client/progress/goals")

      assert html =~ "Fitness Goals"
      assert html =~ "No goals yet"
    end

    test "creates a new goal", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/goals")

      view
      |> form("form[phx-submit=save_goal]", %{
        "fitness_goal" => %{
          "title" => "Bench 100kg",
          "target_value" => "100",
          "target_unit" => "kg"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Bench 100kg"
      assert html =~ "0 / 100 kg"
    end

    test "form values persist after save", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/goals")

      view
      |> form("form[phx-submit=save_goal]", %{
        "fitness_goal" => %{
          "title" => "Run 30 min",
          "target_value" => "30",
          "target_unit" => "minutes"
        }
      })
      |> render_submit()

      [goal] = GymStudio.Goals.list_goals(user.id)
      assert goal.title == "Run 30 min"
      assert Decimal.equal?(goal.target_value, Decimal.new("30"))
    end

    test "updates progress on a goal", %{conn: conn, client_user: user} do
      goal =
        goal_fixture(%{
          "client_id" => user.id,
          "created_by_id" => user.id,
          "title" => "Squat 120kg",
          "target_value" => "120"
        })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/goals")

      render_click(view, "edit_progress", %{"id" => goal.id})

      view
      |> form("form[phx-submit=save_progress]", %{"goal_id" => goal.id, "current_value" => "60"})
      |> render_submit()

      html = render(view)
      assert html =~ "60 / 120 kg"
      assert html =~ "50%"
    end

    test "achieves a goal", %{conn: conn, client_user: user} do
      goal_fixture(%{
        "client_id" => user.id,
        "created_by_id" => user.id,
        "title" => "Test Achieve"
      })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/goals")

      render_click(view, "achieve", %{"id" => hd(GymStudio.Goals.list_goals(user.id)).id})

      html = render(view)
      assert html =~ "Achieved"
      refute html =~ "Update Progress"
    end

    test "filters by status", %{conn: conn, client_user: user} do
      goal_fixture(%{
        "client_id" => user.id,
        "created_by_id" => user.id,
        "title" => "Active Goal"
      })

      goal_fixture(%{
        "client_id" => user.id,
        "created_by_id" => user.id,
        "title" => "Done Goal",
        "status" => "achieved"
      })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/client/progress/goals")

      assert html =~ "Active Goal"
      assert html =~ "Done Goal"

      render_change(view, "filter_status", %{"status" => "active"})
      html = render(view)
      assert html =~ "Active Goal"
      refute html =~ "Done Goal"
    end

    test "authorization — cannot achieve another user's goal", %{conn: conn} do
      other_user = user_fixture(%{role: :client})
      client_fixture(%{user_id: other_user.id})

      goal =
        goal_fixture(%{
          "client_id" => other_user.id,
          "created_by_id" => other_user.id,
          "title" => "Other Goal"
        })

      attacker = user_fixture(%{role: :client})
      client_fixture(%{user_id: attacker.id})
      conn = log_in_user(conn, attacker)
      {:ok, view, _html} = live(conn, ~p"/client/progress/goals")

      render_click(view, "achieve", %{"id" => goal.id})

      # Goal should still be active (not achieved)
      assert GymStudio.Goals.get_goal!(goal.id).status == "active"
    end
  end
end
