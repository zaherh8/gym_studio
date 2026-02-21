defmodule GymStudioWeb.RegistrationLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures
  import Ecto.Query

  alias GymStudio.Accounts.OtpToken

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create your account"
      assert html =~ "Phone"
      assert html =~ "Send Verification Code"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn)

      # Default role is :client, so redirects to client dashboard
      assert {:ok, _conn} = result
    end
  end

  describe "Phone step" do
    test "shows error for invalid phone number", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> form("form", %{country_code: "+961", local_number: "123"})
        |> render_submit()

      assert result =~ "Please enter a valid phone number"
    end

    test "shows error for existing phone number", %{conn: conn} do
      # Create a user with a Lebanon phone number
      phone =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{phone}"
      _user = user_fixture(%{phone_number: full_phone})

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> form("form", %{country_code: "+961", local_number: phone})
        |> render_submit()

      assert result =~ "Unable to send verification code"
    end

    test "advances to verify step when code is sent", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> form("form", %{country_code: "+961", local_number: "71123456"})
        |> render_submit()

      # Should now show the verify step
      assert result =~ "Enter the verification code"
      assert result =~ "Verification Code"
    end
  end

  describe "Verify step" do
    setup %{conn: conn} do
      phone =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{phone}"

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Submit phone to get to verify step
      lv
      |> form("form", %{country_code: "+961", local_number: phone})
      |> render_submit()

      # Get the OTP from the database
      otp_token =
        GymStudio.Repo.one(
          from t in OtpToken,
            where: t.phone_number == ^full_phone,
            where: t.purpose == "registration",
            order_by: [desc: t.inserted_at],
            limit: 1
        )

      %{lv: lv, otp_token: otp_token, phone: phone, full_phone: full_phone}
    end

    test "shows error for invalid code", %{lv: lv} do
      result =
        lv
        |> form("form", %{otp_code: "000000"})
        |> render_submit()

      assert result =~ "Invalid code"
    end

    test "allows changing phone number", %{lv: lv} do
      result =
        lv
        |> element("button", "Change phone number")
        |> render_click()

      assert result =~ "Send Verification Code"
    end
  end

  describe "Full registration flow" do
    test "completes registration with valid data", %{conn: conn} do
      phone =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{phone}"

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Step 1: Submit phone
      lv
      |> form("form", %{country_code: "+961", local_number: phone})
      |> render_submit()

      # Delete the auto-created token and create one with known code
      GymStudio.Repo.delete_all(
        from t in OtpToken,
          where: t.phone_number == ^full_phone
      )

      # Insert token with known code
      known_code = "123456"
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_at = DateTime.add(now, 5, :minute)

      GymStudio.Repo.insert!(%OtpToken{
        phone_number: full_phone,
        hashed_code: OtpToken.hash_code(known_code),
        purpose: "registration",
        attempts: 0,
        expires_at: expires_at
      })

      # Step 2: Verify OTP with known code
      lv
      |> form("form", %{otp_code: known_code})
      |> render_submit()

      # Step 3: Set password
      lv
      |> form("form", %{
        "user" => %{
          "password" => "valid_password123",
          "password_confirmation" => "valid_password123"
        }
      })
      |> render_submit()

      # Should redirect to login
      assert_redirect(lv, ~p"/users/log-in")

      # Verify user was created and confirmed
      user = GymStudio.Accounts.get_user_by_phone_number(full_phone)
      assert user
      assert user.confirmed_at
    end

    test "creates account with optional email", %{conn: conn} do
      phone =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{phone}"

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Step 1: Submit phone
      lv
      |> form("form", %{country_code: "+961", local_number: phone})
      |> render_submit()

      # Delete the auto-created token and create one with known code
      GymStudio.Repo.delete_all(
        from t in OtpToken,
          where: t.phone_number == ^full_phone
      )

      # Insert token with known code
      known_code = "654321"
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires_at = DateTime.add(now, 5, :minute)

      GymStudio.Repo.insert!(%OtpToken{
        phone_number: full_phone,
        hashed_code: OtpToken.hash_code(known_code),
        purpose: "registration",
        attempts: 0,
        expires_at: expires_at
      })

      # Step 2: Verify OTP
      lv
      |> form("form", %{otp_code: known_code})
      |> render_submit()

      # Step 3: Set password with email
      lv
      |> form("form", %{
        "user" => %{
          "password" => "valid_password123",
          "password_confirmation" => "valid_password123",
          "email" => "test@example.com"
        }
      })
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")

      user = GymStudio.Accounts.get_user_by_phone_number(full_phone)
      assert user.email == "test@example.com"
    end
  end
end
