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

      assert html =~ "Home"
      assert html =~ "Schedule"
      assert html =~ "Progress"
      assert html =~ "Profile"
      assert html =~ ~s(href="/client/book")
      assert html =~ ~s(href="/client/sessions")
      assert html =~ ~s(href="/client/progress")
      assert html =~ ~s(href="/users/settings")
      # FAB button for book
      assert html =~ "bg-primary"
      assert html =~ "hero-plus"
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

      # Home tab should be active (text-primary)
      # The active indicator dot should be present
      assert html =~ "text-primary"
    end

    test "highlights active tab for client on sessions" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/sessions"
        )

      # Sessions prefix should match Schedule tab
      assert html =~ "text-primary"
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
      assert html =~ "text-primary"
    end

    test "does not highlight home tab when on sub-path" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client/progress"
        )

      # Parse the HTML to check that the Home link doesn't have text-primary
      # while the Progress link does
      # We check by splitting on the href to isolate each tab's classes
      [before_progress, _after] = String.split(html, ~s(href="/client/progress"), parts: 2)
      [_before_home, home_section] = String.split(before_progress, ~s(href="/client"), parts: 2)

      # Home tab section should have text-gray-500 (inactive)
      assert home_section =~ "text-gray-500"
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
      assert html =~ "bg-primary"
      assert html =~ "shadow-lg"
      assert html =~ "-mt-6"
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

      # No tab should be primary — exact root paths won't match
      # and /client/sessions-archive doesn't start with /client/sessions/
      [before_book, _after] = String.split(html, ~s(href="/client/book"), parts: 2)

      [_before_schedule, schedule_section] =
        String.split(before_book, ~s(href="/client/sessions"), parts: 2)

      # Schedule tab should NOT be active (no text-primary in its section)
      assert schedule_section =~ "text-gray-500"
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
