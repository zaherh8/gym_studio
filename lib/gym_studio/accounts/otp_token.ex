defmodule GymStudio.Accounts.OtpToken do
  @moduledoc """
  Schema for OTP tokens used in phone verification.

  OTP codes are hashed before storage for security.
  Tokens expire after 5 minutes and allow a maximum of 3 verification attempts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "otp_tokens" do
    field :phone_number, :string
    field :hashed_code, :string
    field :purpose, :string
    field :attempts, :integer, default: 0
    field :expires_at, :utc_datetime
    field :verified_at, :utc_datetime

    # Virtual field for the raw code (not stored)
    field :code, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @purposes ~w(registration password_reset)
  @code_length 6
  @expiration_minutes 5
  @max_attempts 3

  @doc """
  Returns the expiration time in minutes.
  """
  def expiration_minutes, do: @expiration_minutes

  @doc """
  Returns the maximum allowed verification attempts.
  """
  def max_attempts, do: @max_attempts

  @doc """
  Creates a changeset for a new OTP token.
  Generates a random code and hashes it for storage.
  """
  def create_changeset(attrs) do
    code = generate_code()
    hashed_code = hash_code(code)
    expires_at = DateTime.utc_now() |> DateTime.add(@expiration_minutes, :minute) |> DateTime.truncate(:second)

    %__MODULE__{}
    |> cast(attrs, [:phone_number, :purpose])
    |> validate_required([:phone_number, :purpose])
    |> validate_inclusion(:purpose, @purposes)
    |> put_change(:code, code)
    |> put_change(:hashed_code, hashed_code)
    |> put_change(:expires_at, expires_at)
    |> put_change(:attempts, 0)
  end

  @doc """
  Generates a random 6-digit OTP code.
  """
  def generate_code do
    :rand.uniform(trunc(:math.pow(10, @code_length)) - 1)
    |> Integer.to_string()
    |> String.pad_leading(@code_length, "0")
  end

  @doc """
  Hashes an OTP code using SHA256.
  """
  def hash_code(code) when is_binary(code) do
    :crypto.hash(:sha256, code)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies if a code matches the hashed code.
  """
  def verify_code(otp_token, provided_code) do
    cond do
      otp_token.attempts >= @max_attempts ->
        {:error, :max_attempts_exceeded}

      DateTime.compare(DateTime.utc_now(), otp_token.expires_at) == :gt ->
        {:error, :expired}

      otp_token.verified_at != nil ->
        {:error, :already_verified}

      hash_code(provided_code) == otp_token.hashed_code ->
        {:ok, otp_token}

      true ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Returns a changeset to increment the attempt count.
  """
  def increment_attempts_changeset(otp_token) do
    change(otp_token, attempts: otp_token.attempts + 1)
  end

  @doc """
  Returns a changeset to mark the token as verified.
  """
  def verify_changeset(otp_token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(otp_token, verified_at: now)
  end

  @doc """
  Checks if the token is expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if max attempts have been exceeded.
  """
  def max_attempts_exceeded?(%__MODULE__{attempts: attempts}) do
    attempts >= @max_attempts
  end
end
