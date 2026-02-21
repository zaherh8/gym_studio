defmodule GymStudio.PackagesTest do
  use GymStudio.DataCase

  alias GymStudio.Packages
  alias GymStudio.Packages.SessionPackage

  import GymStudio.AccountsFixtures
  import GymStudio.PackagesFixtures

  describe "package_types/0" do
    test "returns the map of available package types" do
      types = Packages.package_types()

      assert types == %{
               "standard_8" => 8,
               "standard_12" => 12,
               "premium_20" => 20
             }
    end
  end

  describe "assign_package/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client: client, admin: admin}
    end

    test "assigns a valid package to a client", %{client: client, admin: admin} do
      attrs = %{
        client_id: client.id,
        package_type: "standard_12",
        assigned_by_id: admin.id
      }

      assert {:ok, %SessionPackage{} = package} = Packages.assign_package(attrs)
      assert package.client_id == client.id
      assert package.package_type == "standard_12"
      assert package.total_sessions == 12
      assert package.used_sessions == 0
      assert package.assigned_by_id == admin.id
      assert package.active == true
    end

    test "assigns package with expiration date", %{client: client, admin: admin} do
      expires_at = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      attrs = %{
        client_id: client.id,
        package_type: "premium_20",
        assigned_by_id: admin.id,
        expires_at: expires_at
      }

      assert {:ok, %SessionPackage{} = package} = Packages.assign_package(attrs)
      assert package.expires_at == expires_at
      assert package.total_sessions == 20
    end

    test "assigns package with notes", %{client: client, admin: admin} do
      attrs = %{
        client_id: client.id,
        package_type: "standard_8",
        assigned_by_id: admin.id,
        notes: "Special promotional package"
      }

      assert {:ok, %SessionPackage{} = package} = Packages.assign_package(attrs)
      assert package.notes == "Special promotional package"
    end

    test "returns error with invalid package type", %{client: client, admin: admin} do
      attrs = %{
        client_id: client.id,
        package_type: "invalid_type",
        assigned_by_id: admin.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Packages.assign_package(attrs)
      assert "is invalid" in errors_on(changeset).package_type
    end

    test "returns error with missing required fields", %{client: client} do
      attrs = %{
        client_id: client.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Packages.assign_package(attrs)
      assert "can't be blank" in errors_on(changeset).package_type
      assert "can't be blank" in errors_on(changeset).assigned_by_id
    end

    test "returns error with non-existent client_id", %{admin: admin} do
      attrs = %{
        client_id: Ecto.UUID.generate(),
        package_type: "standard_8",
        assigned_by_id: admin.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Packages.assign_package(attrs)
      assert "does not exist" in errors_on(changeset).client_id
    end
  end

  describe "get_package!/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "returns the package with given id", %{package: package} do
      retrieved = Packages.get_package!(package.id)

      assert retrieved.id == package.id
      assert retrieved.package_type == package.package_type
      assert retrieved.remaining_sessions == 8
    end

    test "preloads associations", %{package: package, client: client, admin: admin} do
      retrieved = Packages.get_package!(package.id)

      assert retrieved.client.id == client.id
      assert retrieved.assigned_by.id == admin.id
    end

    test "raises error with non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Packages.get_package!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_active_package_for_client/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client: client, admin: admin}
    end

    test "returns active package with available sessions", %{client: client, admin: admin} do
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)

      assert {:ok, retrieved} = Packages.get_active_package_for_client(client.id)
      assert retrieved.id == package.id
      assert retrieved.remaining_sessions == 8
    end

    test "returns package with nearest expiration first", %{client: client, admin: admin} do
      later_expiration =
        DateTime.utc_now() |> DateTime.add(60, :day) |> DateTime.truncate(:second)

      sooner_expiration =
        DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      _later_package =
        package_fixture(
          client_id: client.id,
          assigned_by_id: admin.id,
          expires_at: later_expiration
        )

      sooner_package =
        package_fixture(
          client_id: client.id,
          assigned_by_id: admin.id,
          expires_at: sooner_expiration
        )

      assert {:ok, retrieved} = Packages.get_active_package_for_client(client.id)
      assert retrieved.id == sooner_package.id
    end

    test "ignores inactive packages", %{client: client, admin: admin} do
      inactive_package_fixture(client_id: client.id, assigned_by_id: admin.id)

      assert {:error, :no_active_package} = Packages.get_active_package_for_client(client.id)
    end

    test "ignores expired packages", %{client: client, admin: admin} do
      expired_package_fixture(client_id: client.id, assigned_by_id: admin.id)

      assert {:error, :no_active_package} = Packages.get_active_package_for_client(client.id)
    end

    test "ignores fully used packages", %{client: client, admin: admin} do
      fully_used_package_fixture(client_id: client.id, assigned_by_id: admin.id)

      assert {:error, :no_active_package} = Packages.get_active_package_for_client(client.id)
    end

    test "returns error when no packages exist", %{client: client} do
      assert {:error, :no_active_package} = Packages.get_active_package_for_client(client.id)
    end
  end

  describe "use_session/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "increments used_sessions by 1", %{package: package} do
      assert package.used_sessions == 0

      assert {:ok, updated} = Packages.use_session(package)
      assert updated.used_sessions == 1
      assert updated.remaining_sessions == 7
    end

    test "can use multiple sessions sequentially", %{package: package} do
      assert {:ok, updated1} = Packages.use_session(package)
      assert updated1.used_sessions == 1

      # Reload to get fresh data
      package_reloaded = Packages.get_package_raw!(package.id)
      assert {:ok, updated2} = Packages.use_session(package_reloaded)
      assert updated2.used_sessions == 2
      assert updated2.remaining_sessions == 6
    end

    test "returns error when no sessions remain", %{package: package} do
      # Use all 8 sessions
      final_package =
        Enum.reduce(1..8, package, fn _, acc ->
          reloaded = Packages.get_package_raw!(acc.id)
          {:ok, updated} = Packages.use_session(reloaded)
          updated
        end)

      assert final_package.used_sessions == 8
      assert final_package.remaining_sessions == 0

      # Try to use one more
      reloaded = Packages.get_package_raw!(final_package.id)
      assert {:error, changeset} = Packages.use_session(reloaded)
      assert "no remaining sessions available" in errors_on(changeset).used_sessions
    end
  end

  describe "list_packages_for_client/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client: client, admin: admin}
    end

    test "returns all packages for a client", %{client: client, admin: admin} do
      package1 = package_fixture(client_id: client.id, assigned_by_id: admin.id)

      package2 =
        package_fixture(
          client_id: client.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        )

      packages = Packages.list_packages_for_client(client.id)

      assert length(packages) == 2
      package_ids = Enum.map(packages, & &1.id)
      assert package1.id in package_ids
      assert package2.id in package_ids
    end

    test "returns packages ordered by newest first", %{client: client, admin: admin} do
      older = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      newer = package_fixture(client_id: client.id, assigned_by_id: admin.id)

      packages = Packages.list_packages_for_client(client.id)

      assert length(packages) == 2
      # Verify ordering by comparing timestamps
      [first, second] = packages
      assert DateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]
      # At minimum, verify both IDs are present
      package_ids = Enum.map(packages, & &1.id)
      assert newer.id in package_ids
      assert older.id in package_ids
    end

    test "includes remaining_sessions virtual field", %{client: client, admin: admin} do
      _package = package_fixture(client_id: client.id, assigned_by_id: admin.id)

      [retrieved] = Packages.list_packages_for_client(client.id)

      assert retrieved.remaining_sessions == 8
    end

    test "returns empty list when client has no packages", %{client: client} do
      assert [] = Packages.list_packages_for_client(client.id)
    end

    test "does not return other clients' packages", %{client: client, admin: admin} do
      other_client = user_fixture(role: :client)

      _my_package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      _other_package = package_fixture(client_id: other_client.id, assigned_by_id: admin.id)

      packages = Packages.list_packages_for_client(client.id)

      assert length(packages) == 1
    end
  end

  describe "list_all_packages/1" do
    setup do
      client1 = user_fixture(role: :client)
      client2 = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client1: client1, client2: client2, admin: admin}
    end

    test "returns all packages without filters", %{
      client1: client1,
      client2: client2,
      admin: admin
    } do
      package1 = package_fixture(client_id: client1.id, assigned_by_id: admin.id)
      package2 = package_fixture(client_id: client2.id, assigned_by_id: admin.id)

      packages = Packages.list_all_packages()

      assert length(packages) == 2
      package_ids = Enum.map(packages, & &1.id)
      assert package1.id in package_ids
      assert package2.id in package_ids
    end

    test "filters by active status", %{client1: client1, admin: admin} do
      _active = package_fixture(client_id: client1.id, assigned_by_id: admin.id)
      _inactive = inactive_package_fixture(client_id: client1.id, assigned_by_id: admin.id)

      active_packages = Packages.list_all_packages(active: true)
      assert length(active_packages) == 1

      inactive_packages = Packages.list_all_packages(active: false)
      assert length(inactive_packages) == 1
    end

    test "filters by client_id", %{client1: client1, client2: client2, admin: admin} do
      _package1 = package_fixture(client_id: client1.id, assigned_by_id: admin.id)
      _package2 = package_fixture(client_id: client2.id, assigned_by_id: admin.id)

      client1_packages = Packages.list_all_packages(client_id: client1.id)
      assert length(client1_packages) == 1
    end

    test "filters by package_type", %{client1: client1, admin: admin} do
      _standard8 =
        package_fixture(
          client_id: client1.id,
          assigned_by_id: admin.id,
          package_type: "standard_8"
        )

      _standard12 =
        package_fixture(
          client_id: client1.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        )

      standard8_packages = Packages.list_all_packages(package_type: "standard_8")
      assert length(standard8_packages) == 1
      assert hd(standard8_packages).package_type == "standard_8"
    end

    test "filters by has_available_sessions", %{client1: client1, admin: admin} do
      _with_sessions = package_fixture(client_id: client1.id, assigned_by_id: admin.id)
      _fully_used = fully_used_package_fixture(client_id: client1.id, assigned_by_id: admin.id)

      available = Packages.list_all_packages(has_available_sessions: true)
      assert length(available) == 1
    end

    test "filters by expired status", %{client1: client1, admin: admin} do
      _active = package_fixture(client_id: client1.id, assigned_by_id: admin.id)
      _expired = expired_package_fixture(client_id: client1.id, assigned_by_id: admin.id)

      expired_packages = Packages.list_all_packages(expired: true)
      assert length(expired_packages) == 1

      non_expired_packages = Packages.list_all_packages(expired: false)
      assert length(non_expired_packages) == 1
    end

    test "combines multiple filters", %{client1: client1, client2: client2, admin: admin} do
      _match =
        package_fixture(
          client_id: client1.id,
          assigned_by_id: admin.id,
          package_type: "standard_8"
        )

      _wrong_client =
        package_fixture(
          client_id: client2.id,
          assigned_by_id: admin.id,
          package_type: "standard_8"
        )

      _wrong_type =
        package_fixture(
          client_id: client1.id,
          assigned_by_id: admin.id,
          package_type: "standard_12"
        )

      packages =
        Packages.list_all_packages(
          client_id: client1.id,
          package_type: "standard_8",
          active: true
        )

      assert length(packages) == 1
      assert hd(packages).client_id == client1.id
      assert hd(packages).package_type == "standard_8"
    end
  end

  describe "has_available_sessions?/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "returns true when package has unused sessions", %{package: package} do
      assert Packages.has_available_sessions?(package) == true
    end

    test "returns true when package has partially used sessions", %{package: package} do
      {:ok, updated} = Packages.use_session(package)
      assert Packages.has_available_sessions?(updated) == true
    end

    test "returns false when all sessions are used", %{package: package} do
      # Use all sessions
      final =
        Enum.reduce(1..8, package, fn _, acc ->
          reloaded = Packages.get_package_raw!(acc.id)
          {:ok, updated} = Packages.use_session(reloaded)
          updated
        end)

      assert Packages.has_available_sessions?(final) == false
    end
  end

  describe "expired?/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client: client, admin: admin}
    end

    test "returns false for package without expiration", %{client: client, admin: admin} do
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.expired?(package) == false
    end

    test "returns false for package with future expiration", %{client: client, admin: admin} do
      expires_at = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      package =
        package_fixture(client_id: client.id, assigned_by_id: admin.id, expires_at: expires_at)

      assert Packages.expired?(package) == false
    end

    test "returns true for package with past expiration", %{client: client, admin: admin} do
      package = expired_package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.expired?(package) == true
    end
  end

  describe "usable?/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      %{client: client, admin: admin}
    end

    test "returns true for active package with available sessions", %{
      client: client,
      admin: admin
    } do
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.usable?(package) == true
    end

    test "returns false for inactive package", %{client: client, admin: admin} do
      package = inactive_package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.usable?(package) == false
    end

    test "returns false for fully used package", %{client: client, admin: admin} do
      package = fully_used_package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.usable?(package) == false
    end

    test "returns false for expired package", %{client: client, admin: admin} do
      package = expired_package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert Packages.usable?(package) == false
    end
  end

  describe "remaining_sessions calculation" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "correctly calculates remaining sessions", %{package: package} do
      retrieved = Packages.get_package!(package.id)
      assert retrieved.remaining_sessions == 8

      {:ok, updated1} = Packages.use_session(retrieved)
      assert updated1.remaining_sessions == 7

      reloaded = Packages.get_package_raw!(package.id)
      {:ok, updated2} = Packages.use_session(reloaded)
      assert updated2.remaining_sessions == 6
    end

    test "remaining sessions reaches zero", %{package: package} do
      # Use all sessions
      final =
        Enum.reduce(1..8, package, fn _, acc ->
          reloaded = Packages.get_package_raw!(acc.id)
          {:ok, updated} = Packages.use_session(reloaded)
          updated
        end)

      assert final.remaining_sessions == 0
    end
  end

  describe "update_package/2" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "updates package notes", %{package: package} do
      {:ok, updated} = Packages.update_package(package, %{notes: "Updated notes"})
      assert updated.notes == "Updated notes"
    end

    test "updates package expiration", %{package: package} do
      expires_at = DateTime.utc_now() |> DateTime.add(60, :day) |> DateTime.truncate(:second)
      {:ok, updated} = Packages.update_package(package, %{expires_at: expires_at})
      assert updated.expires_at == expires_at
    end
  end

  describe "deactivate_package/1 and activate_package/1" do
    setup do
      client = user_fixture(role: :client)
      admin = user_fixture(role: :admin)
      package = package_fixture(client_id: client.id, assigned_by_id: admin.id)
      %{client: client, admin: admin, package: package}
    end

    test "deactivates an active package", %{package: package} do
      assert package.active == true

      {:ok, deactivated} = Packages.deactivate_package(package)
      assert deactivated.active == false
    end

    test "activates an inactive package", %{client: client, admin: admin} do
      package = inactive_package_fixture(client_id: client.id, assigned_by_id: admin.id)
      assert package.active == false

      {:ok, activated} = Packages.activate_package(package)
      assert activated.active == true
    end
  end
end
