defmodule GymStudio.BranchesTest do
  use GymStudio.DataCase, async: true

  import GymStudio.BranchesFixtures

  alias GymStudio.Branches

  describe "list_branches/1" do
    test "returns all branches ordered by name" do
      _b1 = branch_fixture(%{name: "Zeta Branch", slug: "zeta-1"})
      _b2 = branch_fixture(%{name: "Alpha Branch", slug: "alpha-1"})

      branches = Branches.list_branches()
      assert length(branches) >= 2
      names = Enum.map(branches, & &1.name)
      assert names == Enum.sort(names)
    end

    test "filters by active status" do
      _active = branch_fixture(%{name: "Active", slug: "active-1", active: true})
      _inactive = branch_fixture(%{name: "Inactive", slug: "inactive-1", active: false})

      active_branches = Branches.list_branches(active: true)
      assert Enum.all?(active_branches, & &1.active)
    end
  end

  describe "get_branch_stats/1" do
    test "returns stats for a branch" do
      branch = branch_fixture(%{name: "Stats Branch"})

      stats = Branches.get_branch_stats(branch.id)

      assert Map.has_key?(stats, :client_count)
      assert Map.has_key?(stats, :trainer_count)
      assert Map.has_key?(stats, :sessions_this_week)
      assert stats.client_count == 0
      assert stats.trainer_count == 0
    end
  end

  describe "toggle_branch_active/1" do
    test "toggles active to inactive" do
      branch = branch_fixture(%{name: "Toggle", active: true})

      {:ok, updated} = Branches.toggle_branch_active(branch)
      refute updated.active
    end

    test "toggles inactive to active" do
      branch = branch_fixture(%{name: "Toggle Inactive", active: false})

      {:ok, updated} = Branches.toggle_branch_active(branch)
      assert updated.active
    end
  end

  describe "change_branch/2" do
    test "returns a changeset" do
      branch = branch_fixture(%{name: "Change Test"})
      changeset = Branches.change_branch(branch)
      assert %Ecto.Changeset{} = changeset
    end
  end
end
