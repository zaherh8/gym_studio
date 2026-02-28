defmodule GymStudioWeb.Trainer.ClientProgressLiveTest do
  use GymStudioWeb.ConnCase

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.SchedulingFixtures

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

    test "renders client metrics page", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/metrics")

      assert html =~ "Alice Cooper&#39;s Body Metrics"
      assert html =~ "Back to Progress"
      # No form for creating/editing (read-only)
      refute html =~ "Log New Entry"
    end

    test "renders client goals page", %{
      conn: conn,
      trainer_user: trainer_user,
      client_user: client_user
    } do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients/#{client_user.id}/progress/goals")

      assert html =~ "Alice Cooper&#39;s Goals"
      assert html =~ "Back to Progress"
      # No form for creating goals (read-only)
      refute html =~ "New Goal"
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
