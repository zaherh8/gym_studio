defmodule GymStudio.PackagesFixtures do
  @moduledoc """
  Test fixtures for the Packages context.
  """

  alias GymStudio.Packages

  @doc """
  Generate a session package.

  Requires a client user and an admin user to be provided.

  ## Options

    - `:client_id` - The ID of the client user (required)
    - `:assigned_by_id` - The ID of the admin user (required)
    - `:package_type` - Package type (default: "standard_8")
    - `:expires_at` - Expiration datetime (default: nil)
    - `:notes` - Package notes (default: nil)
    - `:active` - Active status (default: true)
    - `:branch_id` - The branch ID (required)

  ## Examples

      iex> package_fixture(client_id: client.id, assigned_by_id: admin.id, branch_id: branch.id)
      %SessionPackage{}

      iex> package_fixture(
      ...>   client_id: client.id,
      ...>   assigned_by_id: admin.id,
      ...>   package_type: "premium_20",
      ...>   branch_id: branch.id
      ...> )
      %SessionPackage{}
  """
  def package_fixture(attrs \\ %{}) do
    # Auto-fill branch_id from client or assigned_by user if not provided
    branch_id =
      attrs[:branch_id] ||
        if attrs[:client_id] do
          client = GymStudio.Accounts.get_user!(attrs[:client_id])
          client.branch_id
        else
          if attrs[:assigned_by_id] do
            admin = GymStudio.Accounts.get_user!(attrs[:assigned_by_id])
            admin.branch_id
          else
            nil
          end
        end

    attrs =
      attrs
      |> Enum.into(%{
        package_type: "standard_8",
        active: true
      })
      |> then(fn a ->
        if branch_id && !Map.has_key?(a, :branch_id),
          do: Map.put(a, :branch_id, branch_id),
          else: a
      end)

    {:ok, package} = Packages.assign_package(attrs)
    package
  end

  @doc """
  Generate a session package with some sessions already used.

  ## Options

    - `:client_id` - The ID of the client user (required)
    - `:assigned_by_id` - The ID of the admin user (required)
    - `:package_type` - Package type (default: "standard_8")
    - `:used_sessions` - Number of sessions to mark as used (default: 3)
    - `:branch_id` - The branch ID (required)
    - Additional options from `package_fixture/1`

  ## Examples

      iex> used_package_fixture(
      ...>   client_id: client.id,
      ...>   assigned_by_id: admin.id,
      ...>   used_sessions: 5,
      ...>   branch_id: branch.id
      ...> )
      %SessionPackage{used_sessions: 5}
  """
  def used_package_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {used_sessions, attrs} = Map.pop(attrs, :used_sessions, 3)
    package = package_fixture(attrs)

    # Use sessions
    Enum.reduce(1..used_sessions, package, fn _, acc ->
      {:ok, updated} = Packages.use_session(acc)
      updated
    end)
  end

  @doc """
  Generate an expired session package.

  ## Options

    - `:client_id` - The ID of the client user (required)
    - `:assigned_by_id` - The ID of the admin user (required)
    - `:package_type` - Package type (default: "standard_8")
    - `:branch_id` - The branch ID (required)
    - Additional options from `package_fixture/1`

  ## Examples

      iex> expired_package_fixture(client_id: client.id, assigned_by_id: admin.id, branch_id: branch.id)
      %SessionPackage{expires_at: ~U[...]}
  """
  def expired_package_fixture(attrs \\ %{}) do
    # Set expiration to yesterday
    expires_at = DateTime.utc_now() |> DateTime.add(-1, :day)

    attrs
    |> Enum.into(%{})
    |> Map.put(:expires_at, expires_at)
    |> package_fixture()
  end

  @doc """
  Generate a fully used session package.

  ## Options

    - `:client_id` - The ID of the client user (required)
    - `:assigned_by_id` - The ID of the admin user (required)
    - `:package_type` - Package type (default: "standard_8")
    - `:branch_id` - The branch ID (required)
    - Additional options from `package_fixture/1`

  ## Examples

      iex> fully_used_package_fixture(client_id: client.id, assigned_by_id: admin.id, branch_id: branch.id)
      %SessionPackage{used_sessions: 8, total_sessions: 8}
  """
  def fully_used_package_fixture(attrs \\ %{}) do
    package = package_fixture(attrs)

    # Use all sessions
    Enum.reduce(1..package.total_sessions, package, fn _, acc ->
      {:ok, updated} = Packages.use_session(acc)
      updated
    end)
  end

  @doc """
  Generate an inactive session package.

  ## Options

    - `:client_id` - The ID of the client user (required)
    - `:assigned_by_id` - The ID of the admin user (required)
    - `:package_type` - Package type (default: "standard_8")
    - `:branch_id` - The branch ID (required)
    - Additional options from `package_fixture/1`

  ## Examples

      iex> inactive_package_fixture(client_id: client.id, assigned_by_id: admin.id, branch_id: branch.id)
      %SessionPackage{active: false}
  """
  def inactive_package_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{})
    |> Map.put(:active, false)
    |> package_fixture()
  end
end
