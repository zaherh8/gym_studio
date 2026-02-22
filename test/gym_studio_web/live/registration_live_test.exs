defmodule GymStudioWeb.RegistrationLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures

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

      assert result =~ "Enter the verification code"
      assert result =~ "Verification Code"
    end
  end

  describe "Verify step" do
    setup %{conn: conn} do
      phone =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> form("form", %{country_code: "+961", local_number: phone})
      |> render_submit()

      %{lv: lv, phone: phone, full_phone: "+961#{phone}"}
    end

    test "shows error for invalid code", %{lv: lv} do
      # In mock mode (no TELNYX_API_KEY), only "000000" is accepted
      result =
        lv
        |> form("form", %{otp_code: "999999"})
        |> render_submit()

      assert result =~ "Invalid code"
    end

    test "accepts valid mock code and advances to password step", %{lv: lv} do
      # In mock mode, "000000" is the accepted code
      result =
        lv
        |> form("form", %{otp_code: "000000"})
        |> render_submit()

      assert result =~ "Password"
      assert result =~ "Create Account"
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

      # Step 2: Verify with mock code "000000"
      lv
      |> form("form", %{otp_code: "000000"})
      |> render_submit()

      # Step 3: Set password and name
      lv
      |> form("form", %{
        "user" => %{
          "name" => "Test User",
          "password" => "valid_password123",
          "password_confirmation" => "valid_password123"
        }
      })
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")

      user = GymStudio.Accounts.get_user_by_phone_number(full_phone)
      assert user
      assert user.confirmed_at
      assert user.name == "Test User"
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

      # Step 2: Verify with mock code
      lv
      |> form("form", %{otp_code: "000000"})
      |> render_submit()

      # Step 3: Set password with email and name
      lv
      |> form("form", %{
        "user" => %{
          "name" => "Email User",
          "password" => "valid_password123",
          "password_confirmation" => "valid_password123",
          "email" => "test#{System.unique_integer([:positive])}@example.com"
        }
      })
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")

      user = GymStudio.Accounts.get_user_by_phone_number(full_phone)
      assert user.email
    end
  end
end
