defmodule GymStudioWeb.Client.BodyMetricsLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.MetricsFixtures

  setup do
    client_user = user_fixture(%{role: :client})
    _client = client_fixture(%{user_id: client_user.id})
    %{client_user: client_user}
  end

  describe "Body Metrics page" do
    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/client/progress/metrics")
      assert path == ~p"/users/log-in"
    end

    test "renders empty state", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/client/progress/metrics")

      assert html =~ "Body Metrics"
      assert html =~ "No entries yet"
    end

    test "creates a new metric entry", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/metrics")

      view
      |> form("form", %{
        "body_metric" => %{
          "date" => "2026-02-28",
          "weight_kg" => "80.5",
          "waist_cm" => "82.0"
        }
      })
      |> render_submit()

      # Verify data appears in the table
      html = render(view)
      assert html =~ "80.5"
      assert html =~ "82.0"
      assert html =~ "2026-02-28"
    end

    test "form values persist after save", %{conn: conn, client_user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/metrics")

      view
      |> form("form", %{
        "body_metric" => %{
          "date" => "2026-02-28",
          "weight_kg" => "80.5"
        }
      })
      |> render_submit()

      # Verify data persisted by checking table
      html = render(view)
      assert html =~ "80.5"
      assert html =~ "2026-02-28"

      # Verify it's actually in the DB
      [metric] = GymStudio.Metrics.list_metrics(user.id)
      assert Decimal.equal?(metric.weight_kg, Decimal.new("80.5"))
    end

    test "edits an existing metric", %{conn: conn, client_user: user} do
      body_metric_fixture(%{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-27",
        "weight_kg" => "75.0"
      })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/client/progress/metrics")

      # Click edit
      [metric] = GymStudio.Metrics.list_metrics(user.id)
      html = render_click(view, "edit", %{"id" => metric.id})
      assert html =~ "Edit Entry"

      # Submit updated form
      view
      |> form("form", %{
        "body_metric" => %{
          "date" => "2026-02-27",
          "weight_kg" => "77.0"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "77.0"

      # Verify in DB
      updated = GymStudio.Metrics.get_metric!(metric.id)
      assert Decimal.equal?(updated.weight_kg, Decimal.new("77.0"))
    end

    test "deletes a metric", %{conn: conn, client_user: user} do
      body_metric_fixture(%{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-27",
        "weight_kg" => "75.0"
      })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/client/progress/metrics")
      assert html =~ "75.0"

      [metric] = GymStudio.Metrics.list_metrics(user.id)
      render_click(view, "delete", %{"id" => metric.id})

      html = render(view)
      assert html =~ "No entries yet"
      assert GymStudio.Metrics.list_metrics(user.id) == []
    end

    test "client cannot edit another client's metric", %{conn: conn} do
      other_user = user_fixture(%{role: :client})
      _other_client = client_fixture(%{user_id: other_user.id})

      metric =
        body_metric_fixture(%{
          "user_id" => other_user.id,
          "logged_by_id" => other_user.id,
          "date" => "2026-02-27",
          "weight_kg" => "75.0"
        })

      attacker = user_fixture(%{role: :client})
      _attacker_client = client_fixture(%{user_id: attacker.id})

      conn = log_in_user(conn, attacker)
      {:ok, view, _html} = live(conn, ~p"/client/progress/metrics")

      # Try to edit another user's metric — should not show edit form
      render_click(view, "edit", %{"id" => metric.id})
      html = render(view)
      # Should still show "Log New Entry", not "Edit Entry"
      assert html =~ "Log New Entry"
      refute html =~ "Edit Entry"
    end

    test "client cannot delete another client's metric", %{conn: conn} do
      other_user = user_fixture(%{role: :client})
      _other_client = client_fixture(%{user_id: other_user.id})

      metric =
        body_metric_fixture(%{
          "user_id" => other_user.id,
          "logged_by_id" => other_user.id,
          "date" => "2026-02-27",
          "weight_kg" => "75.0"
        })

      attacker = user_fixture(%{role: :client})
      _attacker_client = client_fixture(%{user_id: attacker.id})

      conn = log_in_user(conn, attacker)
      {:ok, view, _html} = live(conn, ~p"/client/progress/metrics")

      render_click(view, "delete", %{"id" => metric.id})

      # Metric should still exist
      assert GymStudio.Metrics.get_metric!(metric.id)
    end
  end
end
