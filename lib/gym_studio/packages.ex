defmodule GymStudio.Packages do
  @moduledoc """
  The Packages context handles session packages for gym clients.

  Session packages are bundles of training sessions that clients purchase.
  Administrators assign packages to clients, and the system tracks session
  usage throughout the package lifecycle.

  ## Package Types

  - `standard_8`: 8 sessions
  - `standard_12`: 12 sessions
  - `premium_20`: 20 sessions

  ## Key Features

  - Package assignment by administrators
  - Session usage tracking
  - Expiration date management
  - Active/inactive status
  - Remaining sessions calculation

  ## Example Usage

      # Assign a package to a client
      {:ok, package} = Packages.assign_package(%{
        client_id: client_id,
        package_type: "standard_12",
        assigned_by_id: admin_id,
        expires_at: ~U[2026-12-31 23:59:59Z]
      })

      # Use a session
      {:ok, updated_package} = Packages.use_session(package)

      # Check remaining sessions
      Packages.has_available_sessions?(package)
      #=> true
  """

  import Ecto.Query, warn: false
  alias GymStudio.Repo
  alias GymStudio.Packages.SessionPackage

  @doc """
  Returns the list of available package types and their session counts.

  ## Examples

      iex> package_types()
      %{"standard_8" => 8, "standard_12" => 12, "premium_20" => 20}
  """
  def package_types do
    SessionPackage.package_types()
  end

  @doc """
  Assigns a new session package to a client.

  Requires admin privileges to assign packages.

  ## Parameters

    - `attrs`: Map with the following keys:
      - `client_id` (required): The user ID of the client
      - `package_type` (required): One of "standard_8", "standard_12", or "premium_20"
      - `assigned_by_id` (required): The user ID of the admin assigning the package
      - `expires_at` (optional): DateTime when the package expires
      - `notes` (optional): Additional notes about the package
      - `active` (optional): Whether the package is active (defaults to true)

  ## Examples

      iex> assign_package(%{
      ...>   client_id: "client-uuid",
      ...>   package_type: "standard_12",
      ...>   assigned_by_id: "admin-uuid"
      ...> })
      {:ok, %SessionPackage{}}

      iex> assign_package(%{client_id: nil})
      {:error, %Ecto.Changeset{}}
  """
  def assign_package(attrs) do
    %SessionPackage{}
    |> SessionPackage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single session package.

  Raises `Ecto.NoResultsError` if the package does not exist.

  ## Examples

      iex> get_package!("existing-uuid")
      %SessionPackage{}

      iex> get_package!("non-existent-uuid")
      ** (Ecto.NoResultsError)
  """
  def get_package!(id) do
    SessionPackage
    |> preload([:client, :assigned_by])
    |> Repo.get!(id)
    |> put_remaining_sessions()
  end

  @doc """
  Gets a single session package without preloading associations.

  Raises `Ecto.NoResultsError` if the package does not exist.

  ## Examples

      iex> get_package_raw!("existing-uuid")
      %SessionPackage{}
  """
  def get_package_raw!(id) do
    Repo.get!(SessionPackage, id)
  end

  @doc """
  Gets the active package for a client.

  Returns the first active, unexpired package with available sessions for the client.
  Prefers packages that expire sooner (to encourage using older packages first).

  ## Examples

      iex> get_active_package_for_client("client-uuid")
      {:ok, %SessionPackage{}}

      iex> get_active_package_for_client("client-with-no-packages")
      {:error, :no_active_package}
  """
  def get_active_package_for_client(client_id) do
    now = DateTime.utc_now()

    package =
      SessionPackage
      |> where([p], p.client_id == ^client_id)
      |> where([p], p.active == true)
      |> where([p], fragment("? - ? > 0", p.total_sessions, p.used_sessions))
      |> where(
        [p],
        is_nil(p.expires_at) or p.expires_at > ^now
      )
      |> order_by([p], asc_nulls_last: p.expires_at)
      |> limit(1)
      |> preload([:client, :assigned_by])
      |> Repo.one()

    case package do
      nil -> {:error, :no_active_package}
      package -> {:ok, put_remaining_sessions(package)}
    end
  end

  @doc """
  Uses a session from the package.

  Increments the `used_sessions` count by 1.
  Validates that the package has remaining sessions available.

  ## Examples

      iex> use_session(package)
      {:ok, %SessionPackage{}}

      iex> use_session(fully_used_package)
      {:error, %Ecto.Changeset{}}
  """
  def use_session(%SessionPackage{} = package) do
    package
    |> SessionPackage.use_session_changeset()
    |> Repo.update()
    |> case do
      {:ok, updated_package} -> {:ok, put_remaining_sessions(updated_package)}
      error -> error
    end
  end

  @doc """
  Lists all packages for a specific client.

  Returns packages ordered by creation date (newest first).
  Includes the virtual `remaining_sessions` field.

  ## Examples

      iex> list_packages_for_client("client-uuid")
      [%SessionPackage{}, ...]

      iex> list_packages_for_client("client-with-no-packages")
      []
  """
  def list_packages_for_client(client_id) do
    SessionPackage
    |> where([p], p.client_id == ^client_id)
    |> order_by([p], desc: p.inserted_at)
    |> preload([:client, :assigned_by])
    |> Repo.all()
    |> Enum.map(&put_remaining_sessions/1)
  end

  @doc """
  Lists all session packages with optional filters.

  ## Options

    - `:active` - Filter by active status (true/false)
    - `:client_id` - Filter by client ID
    - `:package_type` - Filter by package type
    - `:has_available_sessions` - Filter packages with remaining sessions (true/false)
    - `:expired` - Filter by expiration status (true/false)
    - `:preload` - List of associations to preload (default: [:client, :assigned_by])

  ## Examples

      iex> list_all_packages()
      [%SessionPackage{}, ...]

      iex> list_all_packages(active: true, has_available_sessions: true)
      [%SessionPackage{}, ...]
  """
  def list_all_packages(opts \\ []) do
    query = SessionPackage

    query =
      if Keyword.has_key?(opts, :active) do
        where(query, [p], p.active == ^opts[:active])
      else
        query
      end

    query =
      if client_id = opts[:client_id] do
        where(query, [p], p.client_id == ^client_id)
      else
        query
      end

    query =
      if package_type = opts[:package_type] do
        where(query, [p], p.package_type == ^package_type)
      else
        query
      end

    query =
      if opts[:has_available_sessions] == true do
        where(query, [p], fragment("? - ? > 0", p.total_sessions, p.used_sessions))
      else
        query
      end

    query =
      case opts[:expired] do
        true ->
          now = DateTime.utc_now()
          where(query, [p], not is_nil(p.expires_at) and p.expires_at <= ^now)

        false ->
          now = DateTime.utc_now()
          where(query, [p], is_nil(p.expires_at) or p.expires_at > ^now)

        nil ->
          query
      end

    preloads = Keyword.get(opts, :preload, [:client, :assigned_by])

    query
    |> order_by([p], desc: p.inserted_at)
    |> preload(^preloads)
    |> Repo.all()
    |> Enum.map(&put_remaining_sessions/1)
  end

  @doc """
  Checks if a package has available sessions.

  Returns `true` if the package has at least one unused session.

  ## Examples

      iex> has_available_sessions?(package)
      true

      iex> has_available_sessions?(fully_used_package)
      false
  """
  def has_available_sessions?(%SessionPackage{} = package) do
    SessionPackage.has_available_sessions?(package)
  end

  @doc """
  Checks if a package is expired.

  Returns `true` if the package's `expires_at` is in the past.
  Returns `false` if `expires_at` is `nil` (never expires).

  ## Examples

      iex> expired?(package)
      false

      iex> expired?(expired_package)
      true
  """
  def expired?(%SessionPackage{} = package) do
    SessionPackage.expired?(package)
  end

  @doc """
  Checks if a package is usable.

  A package is usable if it is active, has available sessions, and is not expired.

  ## Examples

      iex> usable?(package)
      true

      iex> usable?(inactive_package)
      false
  """
  def usable?(%SessionPackage{} = package) do
    SessionPackage.usable?(package)
  end

  @doc """
  Updates a session package.

  ## Examples

      iex> update_package(package, %{notes: "Updated notes"})
      {:ok, %SessionPackage{}}

      iex> update_package(package, %{package_type: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def update_package(%SessionPackage{} = package, attrs) do
    package
    |> SessionPackage.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_package} -> {:ok, put_remaining_sessions(updated_package)}
      error -> error
    end
  end

  @doc """
  Deactivates a session package.

  Sets the `active` field to `false`.

  ## Examples

      iex> deactivate_package(package)
      {:ok, %SessionPackage{}}
  """
  def deactivate_package(%SessionPackage{} = package) do
    package
    |> Ecto.Changeset.change(active: false)
    |> Repo.update()
    |> case do
      {:ok, updated_package} -> {:ok, put_remaining_sessions(updated_package)}
      error -> error
    end
  end

  @doc """
  Activates a session package.

  Sets the `active` field to `true`.

  ## Examples

      iex> activate_package(package)
      {:ok, %SessionPackage{}}
  """
  def activate_package(%SessionPackage{} = package) do
    package
    |> Ecto.Changeset.change(active: true)
    |> Repo.update()
    |> case do
      {:ok, updated_package} -> {:ok, put_remaining_sessions(updated_package)}
      error -> error
    end
  end

  # Private functions

  defp put_remaining_sessions(%SessionPackage{} = package) do
    remaining = SessionPackage.calculate_remaining_sessions(package)
    %{package | remaining_sessions: remaining}
  end
end
