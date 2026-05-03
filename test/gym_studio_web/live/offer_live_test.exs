defmodule GymStudioWeb.OfferLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Offer landing page" do
    test "renders the campaign landing page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # Headline
      assert html =~ "YOUR FIRST SESSION"
      assert html =~ "IS ON US"
      # Benefits
      assert html =~ "1 free private training session"
      assert html =~ "No commitment, no card"
      assert html =~ "Sin El Fil"
      assert html =~ "Horch Tabet roundabout"
      # CTA button text
      assert html =~ "CLAIM YOUR FREE SESSION"
      # Location
      assert html =~ "Clover Park, 4th floor"
      assert html =~ "Sin El Fil"
    end

    test "does not include navbar or footer", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # The offer page uses a standalone layout — no sticky header/nav
      refute html =~ "sticky top-0"
      # No footer
      refute html =~ "All rights reserved"
    end

    test "WhatsApp CTA links to correct number with pre-filled message", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # WhatsApp URL with the Horsh Tabet number
      assert html =~ "https://wa.me/96170379764"
      # Pre-filled message (URL-encoded)
      assert html =~ "Hi%21"
      assert html =~ "free+session"
      assert html =~ "React"
    end

    test "includes noindex meta tag", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      assert html =~ ~s(name="robots" content="noindex, nofollow")
    end

    test "includes correct SEO meta tags", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      assert html =~ ~s(property="og:title" content="React — Claim Your Free Session")
      assert html =~ ~s(rel="canonical")
      assert html =~ "/offer"
    end

    test "preserves UTM parameters in WhatsApp URL", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/offer?utm_source=flyer&utm_campaign=lift_off&utm_content=dumbbell_v1")

      assert html =~ "utm_source=flyer"
      assert html =~ "utm_campaign=lift_off"
      assert html =~ "utm_content=dumbbell_v1"
    end

    test "works without UTM parameters", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # Should still have the WhatsApp URL with just the message
      assert html =~ "https://wa.me/96170379764"
      assert html =~ "text="
      # Should not have utm params appended
      refute html =~ "utm_source="
    end

    test "preserves partial UTM parameters", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer?utm_source=instagram")

      assert html =~ "utm_source=instagram"
      # Other UTM params should not be present
      refute html =~ "utm_campaign="
      refute html =~ "utm_content="
    end

    test "shows checkmark icons for benefits", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # Checkmark SVG paths (3 benefits)
      assert html =~ "M5 13l4 4L19 7"
    end

    test "shows location pin icon", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      # Location pin SVG path
      assert html =~ "M17.657 16.657"
    end
  end
end
