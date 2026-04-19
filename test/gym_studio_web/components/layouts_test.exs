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

      # Home tab should be active — uses solid icon and base-content color
      assert html =~ "hero-home-solid"
      assert html =~ "text-base-content"
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

      # Home tab section should have inactive color
      assert home_section =~ "text-base-content/40"
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
      assert html =~ "fab-button"
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
      # (activeIcon may appear in data-tabs JSON; check the actual <span> class instead)
      assert html =~ ~s(<span class="hero-calendar size-6">)
      refute html =~ ~s(hero-calendar-days-solid size-6)
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

    test "nav landmark element is present" do
      for role <- [:client, :trainer, :admin] do
        user = user_fixture(%{role: role})
        scope = user_scope_fixture(user)

        html =
          render_component(&Layouts.mobile_bottom_nav/1,
            current_scope: scope,
            current_path: "/"
          )

        assert html =~ ~s(<nav)
      end
    end

    test "aria-label attributes exist on all tab links for client" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      for label <- ["Home", "Progress", "Book", "Schedule", "Profile"] do
        assert html =~ ~s(aria-label="#{label}")
      end
    end

    test "aria-label attributes exist on all tab links for trainer" do
      user = user_fixture(%{role: :trainer})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/trainer"
        )

      for label <- ["Home", "Clients", "Session", "Schedule", "Profile"] do
        assert html =~ ~s(aria-label="#{label}")
      end
    end

    test "client nav uses SPA-style navigation (data-phx-link)" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      # navigate links render with data-phx-link="redirect"
      assert html =~ ~s(data-phx-link="redirect")
    end

    test "trainer nav uses SPA-style navigation (data-phx-link)" do
      user = user_fixture(%{role: :trainer})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/trainer"
        )

      assert html =~ ~s(data-phx-link="redirect")
    end

    test "FAB icon has aria-hidden" do
      user = user_fixture(%{role: :client})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/client"
        )

      # The hero-plus icon inside the FAB should be aria-hidden
      assert html =~ ~s(aria-hidden="true")
    end

    test "trainer nav has centered items and safe area" do
      user = user_fixture(%{role: :trainer})
      scope = user_scope_fixture(user)

      html =
        render_component(&Layouts.mobile_bottom_nav/1,
          current_scope: scope,
          current_path: "/trainer"
        )

      # Items should be centered vertically, not bottom-aligned
      assert html =~ "items-center"
      refute html =~ "items-end"
      # Safe area padding via style attribute
      assert html =~ "safe-area-inset-bottom"
    end
  end
end
