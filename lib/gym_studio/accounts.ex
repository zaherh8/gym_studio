defmodule GymStudio.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias GymStudio.Repo

  alias GymStudio.Accounts.{User, UserToken, UserNotifier, Trainer, Client, OtpToken}
  alias GymStudio.Workers.OtpDeliveryWorker

  @otp_cooldown_seconds 60

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by phone number.

  ## Examples

      iex> get_user_by_phone_number("+1234567890")
      %User{}

      iex> get_user_by_phone_number("+0000000000")
      nil

  """
  def get_user_by_phone_number(phone_number) when is_binary(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by phone number and password.

  ## Examples

      iex> get_user_by_phone_number_and_password("+1234567890", "correct_password")
      %User{}

      iex> get_user_by_phone_number_and_password("+1234567890", "invalid_password")
      nil

  """
  def get_user_by_phone_number_and_password(phone_number, password)
      when is_binary(phone_number) and is_binary(password) do
    user = Repo.get_by(User, phone_number: phone_number)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for user registration.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  @doc """
  Confirms a user's account by setting confirmed_at.
  """
  def confirm_user(%User{} = user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  ## OTP Token Functions

  @doc """
  Creates an OTP token for phone verification.

  Returns `{:error, :cooldown_active}` if a token was created within the cooldown period.

  ## Examples

      iex> create_otp_token("+9611234567", "registration")
      {:ok, %OtpToken{}}

      iex> create_otp_token("+9611234567", "registration") # within 60 seconds
      {:error, :cooldown_active}
  """
  def create_otp_token(phone_number, purpose) do
    # Check for cooldown - prevent spam
    cooldown_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@otp_cooldown_seconds, :second)
      |> DateTime.truncate(:second)

    recent_token =
      from(t in OtpToken,
        where: t.phone_number == ^phone_number,
        where: t.purpose == ^purpose,
        where: t.inserted_at > ^cooldown_cutoff,
        order_by: [desc: t.inserted_at],
        limit: 1
      )
      |> Repo.one()

    if recent_token do
      {:error, :cooldown_active}
    else
      # Invalidate any existing unverified tokens for this phone/purpose
      from(t in OtpToken,
        where: t.phone_number == ^phone_number,
        where: t.purpose == ^purpose,
        where: is_nil(t.verified_at)
      )
      |> Repo.delete_all()

      # Create new token
      %{phone_number: phone_number, purpose: purpose}
      |> OtpToken.create_changeset()
      |> Repo.insert()
    end
  end

  @doc """
  Verifies an OTP code for a phone number and purpose.

  Tracks failed attempts and marks the token as verified on success.

  ## Examples

      iex> verify_otp("+9611234567", "123456", "registration")
      {:ok, %OtpToken{}}

      iex> verify_otp("+9611234567", "wrong", "registration")
      {:error, :invalid_code}
  """
  def verify_otp(phone_number, code, purpose) do
    otp_token =
      from(t in OtpToken,
        where: t.phone_number == ^phone_number,
        where: t.purpose == ^purpose,
        where: is_nil(t.verified_at),
        order_by: [desc: t.inserted_at],
        limit: 1
      )
      |> Repo.one()

    case otp_token do
      nil ->
        {:error, :not_found}

      token ->
        case OtpToken.verify_code(token, code) do
          {:ok, _} ->
            # Mark as verified
            token
            |> OtpToken.verify_changeset()
            |> Repo.update()

          {:error, :invalid_code} ->
            # Increment attempts
            token
            |> OtpToken.increment_attempts_changeset()
            |> Repo.update()

            {:error, :invalid_code}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Checks if a phone number is already registered.

  ## Examples

      iex> phone_number_exists?("+9611234567")
      false
  """
  def phone_number_exists?(phone_number) do
    from(u in User, where: u.phone_number == ^phone_number)
    |> Repo.exists?()
  end

  @doc """
  Delivers an OTP code via the background worker.
  """
  def deliver_otp(phone_number, code, purpose) do
    %{phone_number: phone_number, code: code, purpose: purpose}
    |> OtpDeliveryWorker.new()
    |> Oban.insert()
  end

  @doc """
  Cleans up expired OTP tokens.
  Called periodically by a scheduled job.
  """
  def cleanup_expired_otp_tokens do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(t in OtpToken,
      where: t.expires_at < ^now
    )
    |> Repo.delete_all()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `GymStudio.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `GymStudio.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Trainer Profiles

  @doc """
  Creates a trainer profile for a user.
  """
  def create_trainer_profile(user, attrs \\ %{}) do
    %Trainer{}
    |> Trainer.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Gets a trainer profile by user ID.
  """
  def get_trainer_by_user_id(user_id) do
    Repo.get_by(Trainer, user_id: user_id)
    |> Repo.preload([:user, :approved_by])
  end

  @doc """
  Gets a trainer profile by ID.
  """
  def get_trainer!(id) do
    Repo.get!(Trainer, id)
    |> Repo.preload([:user, :approved_by])
  end

  @doc """
  Approves a trainer profile.
  """
  def approve_trainer(%Trainer{} = trainer, %User{} = approved_by) do
    trainer
    |> Trainer.approval_changeset(approved_by)
    |> Repo.update()
  end

  @doc """
  Suspends a trainer profile.
  """
  def suspend_trainer(%Trainer{} = trainer) do
    trainer
    |> Trainer.status_changeset("suspended")
    |> Repo.update()
  end

  @doc """
  Reactivates a suspended trainer.
  """
  def reactivate_trainer(%Trainer{} = trainer) do
    trainer
    |> Trainer.status_changeset("approved")
    |> Repo.update()
  end

  @doc """
  Lists trainers with optional filters.

  ## Options
    * `:status` - Filter by status (pending, approved, suspended)
  """
  def list_trainers(opts \\ []) do
    Trainer
    |> filter_trainers_by_status(opts[:status])
    |> Repo.all()
    |> Repo.preload([:user])
  end

  @doc """
  Lists all approved trainers.
  """
  def list_approved_trainers do
    list_trainers(status: "approved")
  end

  defp filter_trainers_by_status(query, nil), do: query
  defp filter_trainers_by_status(query, status) do
    from(t in query, where: t.status == ^status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trainer changes.
  """
  def change_trainer(%Trainer{} = trainer, attrs \\ %{}) do
    Trainer.changeset(trainer, attrs)
  end

  ## Client Profiles

  @doc """
  Creates a client profile for a user.
  """
  def create_client_profile(user, attrs \\ %{}) do
    %Client{}
    |> Client.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Gets a client profile by user ID.
  """
  def get_client_by_user_id(user_id) do
    Repo.get_by(Client, user_id: user_id)
    |> Repo.preload([:user])
  end

  @doc """
  Gets a client profile by ID.
  """
  def get_client!(id) do
    Repo.get!(Client, id)
    |> Repo.preload([:user])
  end

  @doc """
  Updates a client profile.
  """
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all clients.
  """
  def list_clients do
    Client
    |> Repo.all()
    |> Repo.preload([:user])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client changes.
  """
  def change_client(%Client{} = client, attrs \\ %{}) do
    Client.changeset(client, attrs)
  end

  ## Admin functions

  @doc """
  Deactivates a user account.
  """
  def deactivate_user(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{active: false})
    |> Repo.update()
  end

  @doc """
  Activates a user account.
  """
  def activate_user(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{active: true})
    |> Repo.update()
  end

  @doc """
  Lists all users with optional filters.

  ## Options
    * `:role` - Filter by role
    * `:active` - Filter by active status
  """
  def list_users(opts \\ []) do
    User
    |> filter_users_by_role(opts[:role])
    |> filter_users_by_active(opts[:active])
    |> Repo.all()
  end

  defp filter_users_by_role(query, nil), do: query
  defp filter_users_by_role(query, role) do
    from(u in query, where: u.role == ^role)
  end

  defp filter_users_by_active(query, nil), do: query
  defp filter_users_by_active(query, active) do
    from(u in query, where: u.active == ^active)
  end
end
