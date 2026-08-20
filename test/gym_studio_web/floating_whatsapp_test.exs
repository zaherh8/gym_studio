defmodule GymStudioWeb.FloatingWhatsappTest do
  @moduledoc """
  The floating button is rendered per-page rather than from a layout, so each
  public page is asserted independently — and `/offer` is asserted to NOT have
  it, since a competing floating CTA works against a single-CTA landing page.
  """
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "floating WhatsApp button" do
    test "renders on the landing page", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Contact us on WhatsApp"
      assert html =~ ~s(data-pixel-source="floating_button")
    end

    test "renders on the gallery page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/gallery")

      assert html =~ "Contact us on WhatsApp"
    end

    test "renders on the contact page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/contact")

      assert html =~ "Contact us on WhatsApp"
    end

    test "does not render on the offer campaign page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      refute html =~ "Contact us on WhatsApp"
    end

    test "opens the branch picker rather than linking to one number", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "getElementById(&#39;whatsapp-modal&#39;).showModal()"
    end

    test "is tagged for pixel attribution as a distinct lead source", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      # Distinguishes floating-button leads from hero-CTA leads, so we can tell
      # whether adding the button actually moved anything.
      assert html =~ ~s(data-pixel-event="Lead")
      assert html =~ ~s(data-pixel-source="floating_button")
    end
  end

  describe "branch picker on pages without their own branch data" do
    test "gallery renders both studios", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/gallery")

      assert html =~ "Horsh Tabet"
      assert html =~ "Jal El Dib"
      assert html =~ "wa.me/96170379764"
      assert html =~ "wa.me/96171633970"
    end

    test "contact renders both studios", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/contact")

      assert html =~ "Horsh Tabet"
      assert html =~ "Jal El Dib"
    end
  end

  describe "simplified hero" do
    test "leads with the category and both branch names", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Private Training."
      assert html =~ "Built Around You."
      # Both studios named — the "is it near me?" question, and the only
      # place either branch appears above the fold.
      assert html =~ "Jal El Dib"
      assert html =~ "Horsh Tabet"
    end

    test "offers a single primary action", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Book Your Free First Session"
      # A competing secondary CTA splits attention; packages are one scroll
      # away and the floating button keeps a contact path in reach.
      refute html =~ "Explore Our Packages"
    end

    test "serves the coaching photo to phones and the studio shot to desktop", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      # Phones get the real Jal El Dib session; the subjects form a block
      # taller than it is wide, which only survives a portrait viewport.
      assert html =~ ~S|media="(max-width: 639px)"|
      assert html =~ "hero-training-tall-600w.jpg"
      assert html =~ "hero-training-tall-900w.jpg"

      # Desktop keeps the wide studio shot, which suits a landscape band.
      assert html =~ "hero-gym.jpg"
    end

    test "drops the copy that repeated the headline", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      refute html =~ "Where Fitness Meets"
      refute html =~ "Just you, your trainer, and your goals"
      refute html =~ "Private Studio in Lebanon"
    end
  end

  describe "free first session offer (#139)" do
    test "appears in the landing hero", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Your first session is on us."
      assert html =~ "No commitment, no card required."
    end

    test "matches the promise made on the offer campaign page", %{conn: conn} do
      home = conn |> get(~p"/") |> html_response(200)
      {:ok, _lv, offer} = live(conn, ~p"/offer")

      # Paid and organic visitors should not see two different offers.
      assert home =~ "No commitment, no card"
      assert offer =~ "No commitment, no card"
    end
  end
end
