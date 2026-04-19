defmodule GymStudioWeb.LayoutsTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymStudio.AccountsFixtures

  alias GymStudioWeb.Layouts

  describe "mobile_bottom_nav/1" do
    test "renders correct tabs for client role" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      # Client glass nav is icon-only (no labels), verify routes exist
      assert html =~ ~s(href="/client/book")
      assert html =~ ~s(href="/client/sessions")
      assert html =~ ~s(href="/client/progress")
      assert html =~ ~s(href="/users/settings")
      # FAB button with gradient background
      assert html =~ "hero-plus"
      assert html =~ "animate-booking-pulse"
      # Glass effect
      assert html =~ "backdrop-filter"
    end

    test "renders correct tabs for trainer role" do
      user = user_fixture(%{role: :trainer})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/trainer"
        )

      assert html =~ "Home"
      assert html =~ "Clients"
      assert html =~ "Schedule"
      assert html =~ "Profile"
      assert html =~ ~s(href="/trainer/clients")
      assert html =~ ~s(href="/trainer/schedule")
      assert html =~ ~s(href="/trainer/sessions")
      assert html =~ "hero-user-group"
    end

    test "renders correct tabs for admin role" do
      user = user_fixture(%{role: :admin})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/admin"
        )

      assert html =~ "Home"
      assert html =~ "Trainers"
      assert html =~ "Branches"
      assert html =~ "Profile"
      assert html =~ ~s(href="/admin/trainers")
      assert html =~ ~s(href="/admin/branches")
      assert html =~ ~s(href="/admin/sessions")
      assert html =~ "hero-academic-cap"
      assert html =~ "hero-map-pin"
    end

    test "highlights active tab for client on home" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      # Home tab should be active — uses solid icon and near-black color
      assert html =~ "hero-home-solid"
      assert html =~ "text-[#1a1a1a]"
    end

    test "highlights active tab for client on sessions" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/sessions"
        )

      # Sessions prefix should match Schedule tab — uses solid icon
      assert html =~ "hero-calendar-days-solid"
    end

    test "highlights active tab for nested path" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/sessions/123"
        )

      # Nested session path should still match Schedule tab
      assert html =~ "hero-calendar-days-solid"
    end

    test "does not highlight home tab when on sub-path" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/progress"
        )

      # Parse the HTML to check that the Home link uses outline icon (inactive)
      # while the Progress link uses solid icon (active)
      [before_progress, _after] = String.split(html, ~s(href="/client/progress"), parts: 2)
      [_before_home, home_section] = String.split(before_progress, ~s(href="/client"), parts: 2)

      # Home tab section should have inactive gray color
      assert home_section =~ "text-[#9ca3af]"
    end

    test "nav is hidden on md breakpoint and above" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      assert html =~ "md:hidden"
    end

    test "FAB button has correct styling" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      assert html =~ "rounded-full"
      assert html =~ "w-[62px]"
      assert html =~ "h-[62px]"
      assert html =~ "translateY(-28px)"
      assert html =~ "linear-gradient"
    end

    test "prefix match does not false-positive on similar paths" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      # /client/sessions-archive should NOT highlight /client/sessions tab
      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/sessions-archive"
        )

      # Schedule tab should NOT be active — uses outline icon, not solid
      assert html =~ "hero-calendar"
      refute html =~ "hero-calendar-days-solid"
    end

    test "iOS safe area padding is applied" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      assert html =~ "safe-area-inset-bottom"
    end
  end
end
