defmodule GymStudio.Progress.ExerciseLogTest do
  use GymStudio.DataCase

  alias GymStudio.Progress

  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures
  import GymStudio.SchedulingFixtures
  import GymStudio.ProgressFixtures

  defp create_session_context(_) do
    trainer_user = user_fixture(%{role: :trainer})
    trainer = trainer_fixture(%{user_id: trainer_user.id})
    admin = user_fixture(%{role: :admin})

    trainer
    |> GymStudio.Accounts.Trainer.approval_changeset(admin)
    |> GymStudio.Repo.update!()

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

    exercise = exercise_fixture()

    %{
      trainer_user: trainer_user,
      client_user: client_user,
      session: session,
      exercise: exercise
    }
  end

  defp valid_attrs(ctx) do
    %{
      "training_session_id" => ctx.session.id,
      "exercise_id" => ctx.exercise.id,
      "client_id" => ctx.client_user.id,
      "logged_by_id" => ctx.trainer_user.id,
      "sets" => 3,
      "reps" => 10,
      "weight_kg" => "50.0",
      "order" => 0
    }
  end

  describe "create_exercise_log/1" do
    setup :create_session_context

    test "creates with valid attrs", ctx do
      assert {:ok, log} = Progress.create_exercise_log(valid_attrs(ctx))
      assert log.sets == 3
      assert log.reps == 10
      assert log.training_session_id == ctx.session.id
    end

    test "fails without any metric", ctx do
      attrs =
        valid_attrs(ctx)
        |> Map.drop(["sets", "reps", "weight_kg"])

      assert {:error, changeset} = Progress.create_exercise_log(attrs)
      assert errors_on(changeset).sets
    end

    test "fails without required foreign keys", _ctx do
      assert {:error, changeset} = Progress.create_exercise_log(%{"sets" => 3})
      assert errors_on(changeset).training_session_id
      assert errors_on(changeset).exercise_id
    end
  end

  describe "update_exercise_log/2" do
    setup :create_session_context

    test "updates with valid attrs", ctx do
      {:ok, log} = Progress.create_exercise_log(valid_attrs(ctx))
      assert {:ok, updated} = Progress.update_exercise_log(log, %{"reps" => 12})
      assert updated.reps == 12
    end
  end

  describe "delete_exercise_log/1" do
    setup :create_session_context

    test "deletes the log", ctx do
      {:ok, log} = Progress.create_exercise_log(valid_attrs(ctx))
      assert {:ok, _} = Progress.delete_exercise_log(log)
      assert_raise Ecto.NoResultsError, fn -> Progress.get_exercise_log!(log.id) end
    end
  end

  describe "list_exercise_logs_for_session/1" do
    setup :create_session_context

    test "returns logs ordered by order", ctx do
      attrs = valid_attrs(ctx)
      {:ok, _log1} = Progress.create_exercise_log(Map.put(attrs, "order", 1))
      {:ok, _log2} = Progress.create_exercise_log(Map.put(attrs, "order", 0))

      logs = Progress.list_exercise_logs_for_session(ctx.session.id)
      assert length(logs) == 2
      assert Enum.at(logs, 0).order == 0
      assert Enum.at(logs, 1).order == 1
    end

    test "preloads exercise", ctx do
      {:ok, _} = Progress.create_exercise_log(valid_attrs(ctx))
      [log] = Progress.list_exercise_logs_for_session(ctx.session.id)
      assert log.exercise.id == ctx.exercise.id
      assert log.exercise.name != nil
    end
  end

  describe "list_exercise_logs_for_client/2" do
    setup :create_session_context

    test "returns logs for client", ctx do
      {:ok, _} = Progress.create_exercise_log(valid_attrs(ctx))
      logs = Progress.list_exercise_logs_for_client(ctx.client_user.id)
      assert length(logs) == 1
    end

    test "filters by exercise_id", ctx do
      {:ok, _} = Progress.create_exercise_log(valid_attrs(ctx))
      other_exercise = exercise_fixture(%{"name" => "Other Exercise"})

      logs =
        Progress.list_exercise_logs_for_client(ctx.client_user.id, exercise_id: other_exercise.id)

      assert logs == []
    end

    test "respects limit", ctx do
      attrs = valid_attrs(ctx)
      {:ok, _} = Progress.create_exercise_log(Map.put(attrs, "order", 0))
      {:ok, _} = Progress.create_exercise_log(Map.put(attrs, "order", 1))
      logs = Progress.list_exercise_logs_for_client(ctx.client_user.id, limit: 1)
      assert length(logs) == 1
    end
  end

  describe "get_personal_records/2" do
    setup :create_session_context

    test "returns max values", ctx do
      attrs = valid_attrs(ctx)

      {:ok, _} =
        Progress.create_exercise_log(
          Map.merge(attrs, %{"weight_kg" => "80.0", "reps" => 5, "duration_seconds" => 120})
        )

      {:ok, _} =
        Progress.create_exercise_log(
          Map.merge(attrs, %{"weight_kg" => "60.0", "reps" => 12, "duration_seconds" => 60})
        )

      records = Progress.get_personal_records(ctx.client_user.id, ctx.exercise.id)
      assert Decimal.equal?(records.max_weight_kg, Decimal.new("80.0"))
      assert records.max_reps == 12
      assert records.max_duration_seconds == 120
    end

    test "returns nils when no logs exist", ctx do
      records = Progress.get_personal_records(ctx.client_user.id, ctx.exercise.id)
      assert records.max_weight_kg == nil
      assert records.max_reps == nil
      assert records.max_duration_seconds == nil
    end
  end
end
