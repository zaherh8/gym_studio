defmodule GymStudio.Packages.SessionPackage do
  @moduledoc """
  Schema for session packages purchased by clients.

  A session package represents a bundle of training sessions that a client can use.
  Packages are assigned by administrators and track:
  - Total sessions included in the package
  - Used sessions count
  - Remaining sessions (virtual field calculated as total - used)
  - Expiration date
  - Active status

  Package types:
  - `standard_8`: 8 sessions
  - `standard_12`: 12 sessions
  - `premium_20`: 20 sessions
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GymStudio.Accounts.User

  @package_types %{
    "standard_8" => 8,
    "standard_12" => 12,
    "premium_20" => 20
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "session_packages" do
    field :package_type, :string
    field :total_sessions, :integer
    field :used_sessions, :integer, default: 0
    field :expires_at, :utc_datetime
    field :active, :boolean, default: true
    field :notes, :string
    field :remaining_sessions, :integer, virtual: true

    belongs_to :client, User
    belongs_to :assigned_by, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the map of available package types and their session counts.
  """
  def package_types, do: @package_types

  @doc """
  Returns a list of valid package type keys.
  """
  def valid_package_types, do: Map.keys(@package_types)

  @doc """
  Changeset for creating a new session package.

  Required fields:
  - `client_id`: The user ID of the client receiving the package
  - `package_type`: One of the valid package types
  - `assigned_by_id`: The user ID of the admin assigning the package

  Optional fields:
  - `expires_at`: When the package expires
  - `notes`: Additional notes about the package
  - `active`: Whether the package is active (defaults to true)

  The `total_sessions` field is automatically set based on the `package_type`.
  """
  def changeset(session_package, attrs) do
    session_package
    |> cast(attrs, [:client_id, :package_type, :assigned_by_id, :expires_at, :notes, :active])
    |> validate_required([:client_id, :package_type, :assigned_by_id])
    |> validate_inclusion(:package_type, valid_package_types())
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:assigned_by_id)
    |> set_total_sessions()
    |> validate_number(:total_sessions, greater_than: 0)
  end

  @doc """
  Changeset for using a session from the package.

  Increments the `used_sessions` field by 1.
  Validates that there are remaining sessions available.
  """
  def use_session_changeset(session_package) do
    session_package
    |> change()
    |> increment_used_sessions()
    |> validate_has_remaining_sessions()
  end

  @doc """
  Calculates the remaining sessions for a package.

  Returns the difference between `total_sessions` and `used_sessions`.
  """
  def calculate_remaining_sessions(%__MODULE__{total_sessions: total, used_sessions: used}) do
    total - used
  end

  @doc """
  Checks if the package has any available sessions.

  Returns `true` if `remaining_sessions > 0`, otherwise `false`.
  """
  def has_available_sessions?(%__MODULE__{} = package) do
    calculate_remaining_sessions(package) > 0
  end

  @doc """
  Checks if the package is expired.

  Returns `true` if `expires_at` is in the past, otherwise `false`.
  If `expires_at` is `nil`, the package never expires.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Checks if the package is usable.

  A package is usable if:
  - It is active
  - It has available sessions
  - It is not expired
  """
  def usable?(%__MODULE__{active: false}), do: false

  def usable?(%__MODULE__{} = package) do
    has_available_sessions?(package) && !expired?(package)
  end

  # Private functions

  defp set_total_sessions(changeset) do
    case get_change(changeset, :package_type) do
      nil ->
        changeset

      package_type ->
        case Map.get(@package_types, package_type) do
          nil -> changeset
          total -> put_change(changeset, :total_sessions, total)
        end
    end
  end

  defp increment_used_sessions(changeset) do
    used_sessions = get_field(changeset, :used_sessions, 0)
    put_change(changeset, :used_sessions, used_sessions + 1)
  end

  defp validate_has_remaining_sessions(changeset) do
    total = get_field(changeset, :total_sessions)
    used = get_field(changeset, :used_sessions)

    if used > total do
      add_error(changeset, :used_sessions, "no remaining sessions available")
    else
      changeset
    end
  end
end
