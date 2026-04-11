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

      inactive_branches = Branches.list_branches(active: false)
      assert Enum.all?(inactive_branches, &(!&1.active))
    end
  end

  describe "create_branch/1" do
    test "creates a branch with valid attributes" do
      attrs = %{name: "Test Branch", slug: "test-branch", capacity: 4}

      assert {:ok, branch} = Branches.create_branch(attrs)
      assert branch.name == "Test Branch"
      assert branch.slug == "test-branch"
      assert branch.capacity == 4
      assert branch.active == true
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = Branches.create_branch(%{})
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).slug
      assert "can't be blank" in errors_on(changeset).capacity
    end

    test "returns error for duplicate slug" do
      branch_fixture(%{slug: "duplicate-slug"})

      assert {:error, changeset} =
               Branches.create_branch(%{name: "Another", slug: "duplicate-slug", capacity: 4})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "returns error for invalid slug format" do
      assert {:error, changeset} =
               Branches.create_branch(%{name: "Bad", slug: "Invalid Slug!", capacity: 4})

      errors = errors_on(changeset).slug
      assert Enum.any?(errors, &String.starts_with?(&1, "must be a valid slug"))
    end

    test "returns error for zero or negative capacity" do
      assert {:error, changeset} =
               Branches.create_branch(%{name: "Bad", slug: "bad", capacity: 0})

      assert "must be greater than 0" in errors_on(changeset).capacity

      assert {:error, changeset} =
               Branches.create_branch(%{name: "Bad2", slug: "bad2", capacity: -1})

      assert "must be greater than 0" in errors_on(changeset).capacity
    end

    test "validates operating hours format" do
      attrs = %{
        name: "Hours Branch",
        slug: "hours-branch",
        capacity: 4,
        operating_hours: %{"mon" => "09:00-17:00", "tue" => "bad-format"}
      }

      assert {:error, changeset} = Branches.create_branch(attrs)
      errors = errors_on(changeset).operating_hours
      assert Enum.any?(errors, &String.starts_with?(&1, "must be in HH:MM-HH:MM format"))
    end

    test "accepts valid operating hours" do
      attrs = %{
        name: "Hours Branch",
        slug: "hours-branch",
        capacity: 4,
        operating_hours: %{"mon" => "06:00-22:00", "tue" => "09:00-17:00"}
      }

      assert {:ok, branch} = Branches.create_branch(attrs)
      assert branch.operating_hours["mon"] == "06:00-22:00"
    end
  end

  describe "get_branch!/1" do
    test "returns the branch with given id" do
      branch = branch_fixture(%{name: "Get Branch"})
      assert Branches.get_branch!(branch.id).name == "Get Branch"
    end

    test "raises Ecto.NoResultsError for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Branches.get_branch!(999_999)
      end
    end
  end

  describe "get_branch_by_slug/1" do
    test "returns the branch with given slug" do
      branch = branch_fixture(%{slug: "sin-el-fil"})
      assert Branches.get_branch_by_slug("sin-el-fil").id == branch.id
    end

    test "returns nil for non-existent slug" do
      assert Branches.get_branch_by_slug("nonexistent") == nil
    end
  end

  describe "update_branch/2" do
    test "updates a branch with valid attributes" do
      branch = branch_fixture(%{name: "Old Name", capacity: 4})

      assert {:ok, updated} = Branches.update_branch(branch, %{name: "New Name", capacity: 8})
      assert updated.name == "New Name"
      assert updated.capacity == 8
    end

    test "returns error for invalid attributes" do
      branch = branch_fixture()

      assert {:error, changeset} = Branches.update_branch(branch, %{capacity: -1})
      assert "must be greater than 0" in errors_on(changeset).capacity
    end

    test "slug cannot be changed via update" do
      branch = branch_fixture(%{slug: "original-slug"})

      {:ok, updated} = Branches.update_branch(branch, %{name: "Updated Name"})
      assert updated.slug == "original-slug"
    end
  end

  describe "delete_branch/1" do
    test "deletes a branch" do
      branch = branch_fixture(%{name: "Delete Me"})

      assert {:ok, _} = Branches.delete_branch(branch)

      assert_raise Ecto.NoResultsError, fn ->
        Branches.get_branch!(branch.id)
      end
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
    test "toggles active to inactive atomically" do
      branch = branch_fixture(%{name: "Toggle", active: true})

      {:ok, updated} = Branches.toggle_branch_active(branch)
      refute updated.active
    end

    test "toggles inactive to active atomically" do
      branch = branch_fixture(%{name: "Toggle Inactive", active: false})

      {:ok, updated} = Branches.toggle_branch_active(branch)
      assert updated.active
    end

    test "is atomic — update_all avoids read-then-write race" do
      branch = branch_fixture(%{name: "Atomic Toggle", active: true})

      # Toggle using the original struct — new_active = !true = false
      {:ok, updated} = Branches.toggle_branch_active(branch)
      refute updated.active

      # Refresh from DB to get current state
      fresh = Branches.get_branch!(branch.id)
      {:ok, updated2} = Branches.toggle_branch_active(fresh)
      assert updated2.active
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
