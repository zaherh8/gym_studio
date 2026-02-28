defmodule GymStudio.MetricsTest do
  use GymStudio.DataCase

  alias GymStudio.Metrics

  import GymStudio.AccountsFixtures
  import GymStudio.MetricsFixtures

  setup do
    user = user_fixture(%{role: :client})
    other_user = user_fixture(%{role: :client})
    %{user: user, other_user: other_user}
  end

  describe "create_metric/1" do
    test "creates a metric with valid attrs", %{user: user} do
      attrs = %{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-28",
        "weight_kg" => "80.5"
      }

      assert {:ok, metric} = Metrics.create_metric(attrs)
      assert metric.weight_kg == Decimal.new("80.5")
      assert metric.date == ~D[2026-02-28]
    end

    test "fails without any measurement", %{user: user} do
      attrs = %{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-28"
      }

      assert {:error, changeset} = Metrics.create_metric(attrs)
      assert errors_on(changeset).weight_kg != []
    end

    test "accepts body measurement without weight", %{user: user} do
      attrs = %{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-28",
        "waist_cm" => "80.0"
      }

      assert {:ok, metric} = Metrics.create_metric(attrs)
      assert metric.waist_cm == Decimal.new("80.0")
      assert metric.weight_kg == nil
    end

    test "upserts on same user_id and date", %{user: user} do
      attrs = %{
        "user_id" => user.id,
        "logged_by_id" => user.id,
        "date" => "2026-02-28",
        "weight_kg" => "80.0"
      }

      assert {:ok, _m1} = Metrics.create_metric(attrs)

      attrs2 = Map.put(attrs, "weight_kg", "82.0")
      assert {:ok, m2} = Metrics.create_metric(attrs2)

      assert m2.weight_kg == Decimal.new("82.0")
      # Same record was upserted
      assert Metrics.list_metrics(user.id) |> length() == 1
    end

    test "unique constraint allows different dates", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id, "weight_kg" => "80.0"}
      assert {:ok, _} = Metrics.create_metric(Map.put(base, "date", "2026-02-27"))
      assert {:ok, _} = Metrics.create_metric(Map.put(base, "date", "2026-02-28"))
      assert length(Metrics.list_metrics(user.id)) == 2
    end
  end

  describe "list_metrics/2" do
    test "returns metrics ordered by date desc", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id, "weight_kg" => "80.0"}
      Metrics.create_metric(Map.put(base, "date", "2026-02-25"))
      Metrics.create_metric(Map.put(base, "date", "2026-02-28"))
      Metrics.create_metric(Map.put(base, "date", "2026-02-26"))

      dates = Metrics.list_metrics(user.id) |> Enum.map(& &1.date)
      assert dates == [~D[2026-02-28], ~D[2026-02-26], ~D[2026-02-25]]
    end

    test "respects limit option", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id, "weight_kg" => "80.0"}

      for d <- 1..5 do
        Metrics.create_metric(
          Map.put(base, "date", "2026-02-#{String.pad_leading("#{d}", 2, "0")}")
        )
      end

      assert length(Metrics.list_metrics(user.id, limit: 3)) == 3
    end

    test "only returns metrics for specified user", %{user: user, other_user: other_user} do
      body_metric_fixture(%{"user_id" => user.id, "logged_by_id" => user.id})

      body_metric_fixture(%{
        "user_id" => other_user.id,
        "logged_by_id" => other_user.id,
        "date" => "2026-01-01"
      })

      assert length(Metrics.list_metrics(user.id)) == 1
    end
  end

  describe "update_metric/2" do
    test "updates a metric", %{user: user} do
      metric =
        body_metric_fixture(%{"user_id" => user.id, "logged_by_id" => user.id})

      assert {:ok, updated} = Metrics.update_metric(metric, %{"weight_kg" => "85.0"})
      assert updated.weight_kg == Decimal.new("85.0")
    end
  end

  describe "delete_metric/1" do
    test "deletes a metric", %{user: user} do
      metric = body_metric_fixture(%{"user_id" => user.id, "logged_by_id" => user.id})
      assert {:ok, _} = Metrics.delete_metric(metric)
      assert Metrics.list_metrics(user.id) == []
    end
  end

  describe "get_latest_metric/1" do
    test "returns most recent metric", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id, "weight_kg" => "80.0"}
      Metrics.create_metric(Map.put(base, "date", "2026-02-25"))
      Metrics.create_metric(Map.put(base, "date", "2026-02-28"))

      latest = Metrics.get_latest_metric(user.id)
      assert latest.date == ~D[2026-02-28]
    end

    test "returns nil when no metrics", %{user: user} do
      assert Metrics.get_latest_metric(user.id) == nil
    end
  end

  describe "get_metric_history/2" do
    test "returns date-value pairs for weight_kg ascending", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id}
      Metrics.create_metric(Map.merge(base, %{"date" => "2026-02-25", "weight_kg" => "80.0"}))
      Metrics.create_metric(Map.merge(base, %{"date" => "2026-02-28", "weight_kg" => "82.0"}))

      history = Metrics.get_metric_history(user.id, :weight_kg)
      assert length(history) == 2
      [{d1, _}, {d2, _}] = history
      assert d1 == ~D[2026-02-25]
      assert d2 == ~D[2026-02-28]
    end

    test "excludes nil values", %{user: user} do
      base = %{"user_id" => user.id, "logged_by_id" => user.id}
      Metrics.create_metric(Map.merge(base, %{"date" => "2026-02-25", "weight_kg" => "80.0"}))
      Metrics.create_metric(Map.merge(base, %{"date" => "2026-02-26", "waist_cm" => "80.0"}))

      history = Metrics.get_metric_history(user.id, :weight_kg)
      assert length(history) == 1
    end
  end
end
