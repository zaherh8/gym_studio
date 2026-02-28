defmodule GymStudioWeb.Trainer.ClientProgressLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

  alias GymStudio.{Goals, Metrics}

  setup do
    trainer_user = user_fixture(%{role: :trainer, name: "Coach Dan"})
    trainer = trainer_fixture(%{user_id: trainer_user.id})
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer
      |> GymStudio.Accounts.Trainer.approval_changeset(admin)
      |> GymStudio.Repo.update!()

    client_user = user_fixture(%{role: :client, name: "Alice Cooper"})
    _client = client_fixture(%{user_id: client_user.id})

    %{
      trainer_user: trainer_user,
      trainer: trainer,
      admin: admin,
      client_user: client_user
    }
  end

  describe "authorized trainer" do
    setup %{trainer_user: trainer_user, client_user: client_user} do
      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      :ok
    end

    test "renders client progress page", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress")

      assert html =~ "Alice Cooper&#39;s Progress"
      assert html =~ "Back to My Clients"
      assert html =~ "Body Metrics"
      assert html =~ "Goals"
    end

    test "renders client metrics page with form", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      assert html =~ "Alice Cooper&#39;s Body Metrics"
      assert html =~ "Back to Progress"
      assert html =~ "Log New Entry"
    end

    test "renders client goals page with form", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      assert html =~ "Alice Cooper&#39;s Goals"
      assert html =~ "Back to Progress"
      assert html =~ "New Goal"
    end

    # ── Metrics Write ────────────────────────────────────────────

    test "trainer can create metric for client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      view
      |> form("form[phx-submit=save]", %{
        "body_metric" => %{
          "date" => "2025-01-15",
          "weight_kg" => "80.5",
          "body_fat_pct" => "18.0"
        }
      })
      |> render_submit()

      # Verify the metric was created with correct ownership
      [metric] = Metrics.list_metrics(client_user.id)
      assert metric.logged_by_id == trainer_user.id
      assert metric.user_id == client_user.id
      assert Decimal.equal?(metric.weight_kg, Decimal.new("80.5"))

      # Verify it shows in the table
      html = render(view)
      assert html =~ "80.5"
    end

    test "trainer can edit metric they logged", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, _metric} =
        Metrics.create_metric(%{
          "user_id" => client_user.id,
          "logged_by_id" => trainer_user.id,
          "date" => "2025-01-10",
          "weight_kg" => "75.0"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      # Click edit via event
      render_click(view, "edit", %{"id" => hd(Metrics.list_metrics(client_user.id)).id})

      view
      |> form("form[phx-submit=save]", %{
        "body_metric" => %{
          "date" => "2025-01-10",
          "weight_kg" => "76.0"
        }
      })
      |> render_submit()

      [metric] = Metrics.list_metrics(client_user.id)
      assert Decimal.equal?(metric.weight_kg, Decimal.new("76.0"))
    end

    test "trainer cannot edit metric logged by client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, metric} =
        Metrics.create_metric(%{
          "user_id" => client_user.id,
          "logged_by_id" => client_user.id,
          "date" => "2025-01-10",
          "weight_kg" => "75.0"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      # Should show "Client entry" instead of edit/delete buttons
      assert html =~ "Client entry"

      # Try to edit anyway via event — should be denied
      render_click(view, "edit", %{"id" => metric.id})
      # Verify form is NOT in edit mode (still shows "Log New Entry")
      assert render(view) =~ "Log New Entry"
    end

    test "trainer can delete metric they logged", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, metric} =
        Metrics.create_metric(%{
          "user_id" => client_user.id,
          "logged_by_id" => trainer_user.id,
          "date" => "2025-01-10",
          "weight_kg" => "75.0"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      render_click(view, "delete", %{"id" => metric.id})
      assert Metrics.list_metrics(client_user.id) == []
    end

    test "trainer cannot delete metric logged by client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, metric} =
        Metrics.create_metric(%{
          "user_id" => client_user.id,
          "logged_by_id" => client_user.id,
          "date" => "2025-01-10",
          "weight_kg" => "75.0"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      render_click(view, "delete", %{"id" => metric.id})
      # Metric should still exist — trainer can't delete client's entry
      assert length(Metrics.list_metrics(client_user.id)) == 1
    end

    # ── Goals Write ──────────────────────────────────────────────

    test "trainer can create goal for client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      view
      |> form("form[phx-submit=save_goal]", %{
        "fitness_goal" => %{
          "title" => "Squat 120kg",
          "target_value" => "120",
          "target_unit" => "kg"
        }
      })
      |> render_submit()

      [goal] = Goals.list_goals(client_user.id)
      assert goal.created_by_id == trainer_user.id
      assert goal.client_id == client_user.id
      assert goal.title == "Squat 120kg"

      assert render(view) =~ "Squat 120kg"
    end

    test "trainer can update progress on client goal", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, goal} =
        Goals.create_goal(%{
          "client_id" => client_user.id,
          "created_by_id" => client_user.id,
          "title" => "Run 5K",
          "target_value" => "5",
          "target_unit" => "kg"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      # Open progress editor
      render_click(view, "edit_progress", %{"id" => goal.id})

      view
      |> form("form[phx-submit=save_progress]", %{
        "goal_id" => goal.id,
        "current_value" => "3"
      })
      |> render_submit()

      updated = Goals.get_goal!(goal.id)
      assert Decimal.equal?(updated.current_value, Decimal.new("3"))
    end

    test "trainer can achieve goal", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, goal} =
        Goals.create_goal(%{
          "client_id" => client_user.id,
          "created_by_id" => client_user.id,
          "title" => "Run 5K",
          "target_value" => "5",
          "target_unit" => "kg"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      render_click(view, "achieve", %{"id" => goal.id})

      updated = Goals.get_goal!(goal.id)
      assert updated.status == "achieved"
    end

    test "trainer can abandon goal", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, goal} =
        Goals.create_goal(%{
          "client_id" => client_user.id,
          "created_by_id" => client_user.id,
          "title" => "Run 5K",
          "target_value" => "5",
          "target_unit" => "kg"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      render_click(view, "abandon", %{"id" => goal.id})

      updated = Goals.get_goal!(goal.id)
      assert updated.status == "abandoned"
    end

    test "trainer can delete goal they created", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, goal} =
        Goals.create_goal(%{
          "client_id" => client_user.id,
          "created_by_id" => trainer_user.id,
          "title" => "Trainer Goal",
          "target_value" => "10",
          "target_unit" => "kg"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      render_click(view, "delete", %{"id" => goal.id})
      assert Goals.list_goals(client_user.id) == []
    end

    test "trainer cannot delete goal created by client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      {:ok, goal} =
        Goals.create_goal(%{
          "client_id" => client_user.id,
          "created_by_id" => client_user.id,
          "title" => "Client Goal",
          "target_value" => "10",
          "target_unit" => "kg"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      render_click(view, "delete", %{"id" => goal.id})
      # Goal should still exist — trainer can't delete client's goal
      assert length(Goals.list_goals(client_user.id)) == 1
    end
  end

  describe "unauthorized trainer" do
    test "redirects when trainer has no sessions with client", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)

      assert {:error, {:redirect, %{to: "/trainer/clients", flash: %{"error" => msg}}}} =
               live(conn, ~p"/trainer/clients/#{client_user.id}/progress")

      assert msg =~ "Not authorized"
    end

    test "redirects from metrics when unauthorized", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)

      assert {:error, {:redirect, %{to: "/trainer/clients", flash: %{"error" => msg}}}} =
               live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      assert msg =~ "Not authorized"
    end

    test "redirects from goals when unauthorized", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)

      assert {:error, {:redirect, %{to: "/trainer/clients", flash: %{"error" => msg}}}} =
               live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      assert msg =~ "Not authorized"
    end
  end
end
