defmodule GymStudio.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GymStudio.Accounts` context.
  """

  import Ecto.Query

  alias GymStudio.Accounts
  alias GymStudio.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer([:positive, :monotonic])}@example.com"

  def unique_phone_number,
    do: "+1555#{:rand.uniform(9_999_999) |> Integer.to_string() |> String.pad_leading(7, "0")}"

  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test User #{System.unique_integer([:positive])}",
      email: unique_user_email(),
      phone_number: unique_phone_number(),
      password: valid_user_password(),
      password_confirmation: valid_user_password()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    # Confirm the user
    user
    |> Accounts.User.confirm_changeset()
    |> GymStudio.Repo.update!()
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    GymStudio.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    GymStudio.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    GymStudio.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  def trainer_fixture(attrs \\ %{}) do
    user =
      if attrs[:user_id] do
        Accounts.get_user!(attrs[:user_id])
      else
        user_fixture(%{role: :trainer})
      end

    {:ok, trainer} =
      Accounts.create_trainer_profile(user, %{
        bio: attrs[:bio] || "Professional fitness trainer",
        specializations: attrs[:specializations] || ["General Fitness"]
      })

    trainer
  end

  def client_fixture(attrs \\ %{}) do
    user =
      if attrs[:user_id] do
        Accounts.get_user!(attrs[:user_id])
      else
        user_fixture(%{role: :client})
      end

    {:ok, client} =
      Accounts.create_client_profile(user, %{
        emergency_contact: attrs[:emergency_contact] || "+15551234567",
        health_notes: attrs[:health_notes] || "None",
        goals: attrs[:goals] || "General fitness"
      })

    client
  end
end
