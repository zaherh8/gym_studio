defmodule GymStudio.BranchesTest do
  use GymStudio.DataCase

  alias GymStudio.Branches
  alias GymStudio.Branches.Branch

  describe "list_branches/1" do
    test "returns all branches ordered by name" do
      {:ok, _b1} = create_branch_fixture(%{name: "React — Z Branch", slug: "z-branch"})
      {:ok, _b2} = create_branch_fixture(%{name: "React — A Branch", slug: "a-branch"})

      branches = Branches.list_branches()
      assert length(branches) == 2
      assert hd(branches).name == "React — A Branch"
    end

    test "filters by active status" do
      {:ok, _active} =
        create_branch_fixture(%{name: "Active Branch", slug: "active", active: true})

      {:ok, _inactive} =
        create_branch_fixture(%{name: "Inactive Branch", slug: "inactive", active: false})

      active = Branches.list_branches(active: true)
      assert length(active) == 1
      assert hd(active).slug == "active"

      inactive = Branches.list_branches(active: false)
      assert length(inactive) == 1
      assert hd(inactive).slug == "inactive"
    end

    test "returns empty list when no branches exist" do
      assert [] = Branches.list_branches()
    end
  end

  describe "get_branch!/1" do
    test "returns the branch with given id" do
      {:ok, branch} = create_branch_fixture(%{name: "Test Branch", slug: "test-branch"})

      retrieved = Branches.get_branch!(branch.id)
      assert retrieved.id == branch.id
      assert retrieved.name == "Test Branch"
      assert retrieved.slug == "test-branch"
    end

    test "raises error with non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Branches.get_branch!(999_999)
      end
    end
  end

  describe "get_branch_by_slug/1" do
    test "returns the branch with given slug" do
      {:ok, branch} = create_branch_fixture(%{name: "Sin El Fil", slug: "sin-el-fil"})

      retrieved = Branches.get_branch_by_slug("sin-el-fil")
      assert retrieved.id == branch.id
    end

    test "returns nil for non-existent slug" do
      assert nil == Branches.get_branch_by_slug("nonexistent")
    end
  end

  describe "create_branch/1" do
    test "creates a branch with valid attributes" do
      attrs = %{
        name: "React — Sin El Fil",
        slug: "sin-el-fil",
        address: "Plot 274, Sin El Fil",
        capacity: 4,
        phone: "+961 1 234 567",
        latitude: 33.8713,
        longitude: 35.5297,
        operating_hours: %{
          "mon" => "06:00-22:00",
          "tue" => "06:00-22:00"
        },
        active: true
      }

      assert {:ok, %Branch{} = branch} = Branches.create_branch(attrs)
      assert branch.name == "React — Sin El Fil"
      assert branch.slug == "sin-el-fil"
      assert branch.address == "Plot 274, Sin El Fil"
      assert branch.capacity == 4
      assert branch.phone == "+961 1 234 567"
      assert branch.latitude == 33.8713
      assert branch.longitude == 35.5297
      assert branch.operating_hours["mon"] == "06:00-22:00"
      assert branch.active == true
    end

    test "creates a branch with minimal attributes" do
      attrs = %{name: "Minimal Branch", slug: "minimal", capacity: 10}

      assert {:ok, %Branch{} = branch} = Branches.create_branch(attrs)
      assert branch.name == "Minimal Branch"
      assert branch.slug == "minimal"
      assert branch.capacity == 10
      assert branch.active == true
      assert branch.address == nil
      assert branch.phone == nil
    end

    test "returns error with missing required fields" do
      attrs = %{name: "No Slug"}

      assert {:error, changeset} = Branches.create_branch(attrs)
      assert "can't be blank" in errors_on(changeset).slug
      assert "can't be blank" in errors_on(changeset).capacity
    end

    test "returns error with invalid slug format" do
      attrs = %{name: "Bad Slug", slug: "Invalid Slug!", capacity: 4}

      assert {:error, changeset} = Branches.create_branch(attrs)

      assert "must be a valid slug (lowercase letters, numbers, and hyphens)" in errors_on(
               changeset
             ).slug
    end

    test "returns error with duplicate slug" do
      {:ok, _existing} = create_branch_fixture(%{name: "Existing", slug: "duplicate-slug"})

      attrs = %{name: "New Branch", slug: "duplicate-slug", capacity: 6}

      assert {:error, changeset} = Branches.create_branch(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "returns error with zero or negative capacity" do
      attrs = %{name: "Zero Cap", slug: "zero-cap", capacity: 0}

      assert {:error, changeset} = Branches.create_branch(attrs)
      assert "must be greater than 0" in errors_on(changeset).capacity

      attrs2 = %{name: "Neg Cap", slug: "neg-cap", capacity: -1}

      assert {:error, changeset2} = Branches.create_branch(attrs2)
      assert "must be greater than 0" in errors_on(changeset2).capacity
    end
  end

  describe "update_branch/2" do
    test "updates a branch with valid attributes" do
      {:ok, branch} =
        create_branch_fixture(%{name: "Old Name", slug: "old-slug", capacity: 4})

      assert {:ok, updated} = Branches.update_branch(branch, %{name: "New Name", capacity: 6})
      assert updated.name == "New Name"
      assert updated.capacity == 6
      assert updated.slug == "old-slug"
    end

    test "returns error with invalid attributes" do
      {:ok, branch} = create_branch_fixture(%{name: "Test", slug: "test", capacity: 4})

      assert {:error, changeset} = Branches.update_branch(branch, %{capacity: -1})
      assert "must be greater than 0" in errors_on(changeset).capacity
    end

    test "ignores slug changes — slug is immutable after creation" do
      {:ok, _b1} = create_branch_fixture(%{name: "Branch A", slug: "slug-a"})
      {:ok, b2} = create_branch_fixture(%{name: "Branch B", slug: "slug-b"})

      # Attempting to update slug is silently ignored
      assert {:ok, updated} = Branches.update_branch(b2, %{slug: "slug-a"})
      assert updated.slug == "slug-b"
    end
  end

  describe "delete_branch/1" do
    test "deletes a branch" do
      {:ok, branch} = create_branch_fixture(%{name: "To Delete", slug: "to-delete"})

      assert {:ok, %Branch{}} = Branches.delete_branch(branch)

      assert_raise Ecto.NoResultsError, fn ->
        Branches.get_branch!(branch.id)
      end
    end
  end

  # Helper
  defp create_branch_fixture(attrs) do
    defaults = %{
      name: "Test Branch",
      slug: "test-branch-#{System.unique_integer([:positive])}",
      capacity: 4
    }

    Branches.create_branch(Map.merge(defaults, Map.new(attrs)))
  end
end
