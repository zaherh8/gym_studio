defmodule GymStudioWeb.UserSessionHTML do
  use GymStudioWeb, :html

  embed_templates "user_session_html/*"

  @doc """
  Strips the +961 prefix from phone numbers for the login form display.
  The form shows +961 as a static prefix, so we only need the local part.
  """
  def format_login_phone(nil), do: ""
  def format_login_phone(""), do: ""

  def format_login_phone(phone) when is_binary(phone) do
    if String.starts_with?(phone, "+961") do
      String.replace_prefix(phone, "+961", "")
    else
      phone
    end
  end

  def format_login_phone(phone), do: phone
end
