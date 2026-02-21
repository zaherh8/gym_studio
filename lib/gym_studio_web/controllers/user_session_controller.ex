defmodule GymStudioWeb.UserSessionController do
  use GymStudioWeb, :controller

  alias GymStudio.Accounts
  alias GymStudioWeb.UserAuth

  def new(conn, _params) do
    phone_number =
      get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:phone_number)])

    form = Phoenix.Component.to_form(%{"phone_number" => phone_number}, as: "user")

    render(conn, :new, form: form)
  end

  # phone_number + password login
  def create(conn, %{
        "user" => %{"phone_number" => phone_number, "password" => password} = user_params
      }) do
    if user = Accounts.get_user_by_phone_number_and_password(phone_number, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      # In order to prevent user enumeration attacks, don't disclose whether the phone is registered.
      conn
      |> put_flash(:error, "Invalid phone number or password")
      |> render(:new, form: form)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
