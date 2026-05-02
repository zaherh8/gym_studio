defmodule GymStudioWeb.LinksLiveTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Links page" do
    test "renders the link-in-bio page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      # Logo alt text
      assert html =~ "React"
      # Slogan
      assert html =~ "Where Fitness Meets Personal Attention"
      # Location buttons
      assert html =~ "📍"
      assert html =~ "Horsh Tabet"
      assert html =~ "Jal El Dib"
      # Google Maps links (exact coordinates matching landing page)
      assert html =~ "33.8709623,35.5343566"
      assert html =~ "33.9069,35.5801"
      # WhatsApp "Chat with us" button
      assert html =~ "Chat with us"
      # Instagram section
      assert html =~ "Follow us on"
      assert html =~ "instagram.com/reactgym"
      # Branch picker modal
      assert html =~ "whatsapp-modal"
      assert html =~ "Choose a Branch"
      # WhatsApp numbers in modal
      assert html =~ "+961 70 379 764"
      assert html =~ "+961 71 633 970"
    end

    test "does not include navbar or footer", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      # The links page uses a minimal layout — no sticky header/nav
      refute html =~ "sticky top-0"
      # No footer
      refute html =~ "All rights reserved"
    end

    test "branch picker modal links to WhatsApp", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      assert html =~ "https://wa.me/96170379764"
      assert html =~ "https://wa.me/96171633970"
    end
  end
end
