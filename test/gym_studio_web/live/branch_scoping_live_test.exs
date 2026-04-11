defmodule GymStudioWeb.BranchScopingLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import GymStudio.BranchesFixtures

  describe "Client profile shows branch" do
    setup do
      branch = branch_fixture(%{name: "Sin El Fil"})
      user = user_fixture(%{role: :client, branch_id: branch.id})
      %{branch: branch, user: user}
    end

    test "client profile displays branch name", %{conn: conn, branch: branch, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/client/profile")

      assert html =~ "My Branch"
      assert html =~ branch.name
    end
  end

  describe "Client dashboard shows branch" do
    setup do
      branch = branch_fixture(%{name: "Achrafieh"})
      user = user_fixture(%{role: :client, branch_id: branch.id})
      %{branch: branch, user: user}
    end

    test "client dashboard displays branch badge", %{conn: conn, branch: branch, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/client")

      assert html =~ branch.name
    end
  end

  describe "Trainer profile shows branch" do
    setup do
      branch = branch_fixture(%{name: "Dbayeh"})
      user = user_fixture(%{role: :trainer, branch_id: branch.id})
      %{branch: branch, user: user}
    end

    test "trainer profile displays branch name", %{conn: conn, branch: branch, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/trainer/profile")

      assert html =~ "My Branch"
      assert html =~ branch.name
    end
  end

  describe "Trainer dashboard shows branch" do
    setup do
      branch = branch_fixture(%{name: "Jounieh"})
      user = user_fixture(%{role: :trainer, branch_id: branch.id})
      %{branch: branch, user: user}
    end

    test "trainer dashboard displays branch badge", %{conn: conn, branch: branch, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/trainer")

      assert html =~ branch.name
    end
  end
end
