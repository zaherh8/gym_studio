defmodule GymStudioWeb.ForgotPasswordLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures

  describe "Forgot password page" do
    test "renders forgot password page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/forgot-password")

      assert html =~ "Reset Password"
      assert html =~ "Send Verification Code"
      assert html =~ "Back to login"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/forgot-password")
        |> follow_redirect(conn)

      assert {:ok, _conn} = result
    end
  end

  describe "Phone step" do
    test "shows error for invalid phone number", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("form", %{local_number: "123"})
        |> render_submit()

      assert result =~ "Please enter a valid phone number"
    end

    test "proceeds to verify step even for non-existing phone (prevents enumeration)", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("form", %{local_number: "71999888"})
        |> render_submit()

      # Should proceed to verify step without revealing if phone exists
      assert result =~ "Verification Code"
      assert result =~ "+961 71999888"
    end

    test "advances to verify step for existing phone", %{conn: conn} do
      local_num =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{local_num}"
      _user = user_fixture(%{phone_number: full_phone})

      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      result =
        lv
        |> form("form", %{local_number: local_num})
        |> render_submit()

      assert result =~ "Verification Code"
      assert result =~ "We sent a code to"
    end
  end

  describe "Verify step" do
    setup %{conn: conn} do
      local_num =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{local_num}"
      user = user_fixture(%{phone_number: full_phone})

      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      # Go to verify step
      lv
      |> form("form", %{local_number: local_num})
      |> render_submit()

      %{lv: lv, user: user, phone: full_phone, local_num: local_num}
    end

    test "rejects invalid OTP code", %{lv: lv} do
      result =
        lv
        |> form("form", %{otp_code: "111111"})
        |> render_submit()

      assert result =~ "Invalid code"
    end

    test "accepts valid OTP code (mock mode)", %{lv: lv} do
      result =
        lv
        |> form("form", %{otp_code: "000000"})
        |> render_submit()

      assert result =~ "New Password"
      assert result =~ "Reset Password"
    end

    test "can go back to change phone number", %{lv: lv} do
      result = render_click(lv, "change_phone")

      assert result =~ "Send Verification Code"
    end
  end

  describe "Password step" do
    setup %{conn: conn} do
      local_num =
        "71#{System.unique_integer([:positive]) |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0")}"

      full_phone = "+961#{local_num}"
      user = user_fixture(%{phone_number: full_phone})

      {:ok, lv, _html} = live(conn, ~p"/users/forgot-password")

      # Go to verify step
      lv
      |> form("form", %{local_number: local_num})
      |> render_submit()

      # Go to password step
      lv
      |> form("form", %{otp_code: "000000"})
      |> render_submit()

      %{lv: lv, user: user, phone: full_phone, conn: conn}
    end

    test "validates password length", %{lv: lv} do
      result =
        lv
        |> form("form", %{user: %{password: "short", password_confirmation: "short"}})
        |> render_change()

      assert result =~ "should be at least 12 character"
    end

    test "resets password successfully", %{lv: lv} do
      lv
      |> form("form", %{
        user: %{password: "new_password_123", password_confirmation: "new_password_123"}
      })
      |> render_submit()

      flash = assert_redirect(lv, ~p"/users/log-in")
      assert flash["info"] == "Password reset successfully"
    end

    test "validates password confirmation mismatch", %{lv: lv} do
      result =
        lv
        |> form("form", %{
          user: %{password: "new_password_123", password_confirmation: "different_password"}
        })
        |> render_submit()

      assert result =~ "does not match password"
    end
  end

  describe "Login page link" do
    test "login page has forgot password link", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      response = html_response(conn, 200)

      assert response =~ "Forgot password?"
      assert response =~ ~p"/users/forgot-password"
    end
  end
end
