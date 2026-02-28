defmodule GymStudioWeb.Trainer.ClientListLiveTest do
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

    %{trainer_user: trainer_user, trainer: trainer, admin: admin}
  end

  describe "Client List" do
    test "renders empty state when no clients", %{conn: conn, trainer_user: trainer_user} do
      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients")

      assert html =~ "My Clients"
      assert html =~ "No clients found"
    end

    test "renders client cards with session stats", %{
      conn: conn,
      trainer_user: trainer_user
    } do
      client_user = user_fixture(%{role: :client, name: "Alice Cooper"})
      _client = client_fixture(%{user_id: client_user.id})

      _session =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      _session2 =
        training_session_fixture(%{
          client_id: client_user.id,
          trainer_id: trainer_user.id,
          status: "completed",
          scheduled_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, _view, html} = live(conn, ~p"/trainer/clients")

      assert html =~ "Alice Cooper"
      assert html =~ "Total sessions"
      assert html =~ "2"
      assert html =~ "View Progress"
    end

    test "search filters clients by name", %{conn: conn, trainer_user: trainer_user} do
      alice = user_fixture(%{role: :client, name: "Alice Cooper"})
      _alice_client = client_fixture(%{user_id: alice.id})

      bob = user_fixture(%{role: :client, name: "Bob Marley"})
      _bob_client = client_fixture(%{user_id: bob.id})

      _s1 =
        training_session_fixture(%{
          client_id: alice.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      _s2 =
        training_session_fixture(%{
          client_id: bob.id,
          trainer_id: trainer_user.id,
          status: "confirmed"
        })

      conn = log_in_user(conn, trainer_user)
      {:ok, view, _html} = live(conn, ~p"/trainer/clients")

      html = render_change(view, "search", %{"search" => "Alice"})
      assert html =~ "Alice Cooper"
      refute html =~ "Bob Marley"
    end
  end
end
