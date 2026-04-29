defmodule GymStudioWeb.PageControllerTest do
  use GymStudioWeb.ConnCase

  import GymStudio.AccountsFixtures

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "react-wordmark"
    assert response =~ "Where Fitness Meets"
  end

  # [LANDING-PAGE] Trainers section hidden for landing page release - see #92
  test "GET / does not show trainers section", %{conn: conn} do
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer_fixture(%{
        bio: "Expert in strength training",
        specializations: ["Strength", "HIIT"]
      })

    GymStudio.Accounts.approve_trainer(trainer, admin)

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    refute response =~ "Meet Your"
    refute response =~ "Expert in strength training"
  end

  describe "static branches" do
    test "GET / displays static branch data in Our Locations section", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Horsh Tabet branch
      assert response =~ "Horsh Tabet"
      assert response =~ "Clover Park, 4th floor"
      assert response =~ "+961 70 379 764"
      assert response =~ "https://wa.me/96170379764"

      # Jal El Dib branch
      assert response =~ "Jal El Dib"
      assert response =~ "Main Street"
      assert response =~ "+961 71 633 970"
      assert response =~ "https://wa.me/96171633970"
    end

    test "GET / shows Get Directions links for each branch", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Get Directions"
      assert response =~ "React+Gym+Clover+Park+Horsh+Tabet"
      assert response =~ "React+Gym+Jal+El+Dib+Main+Street"
    end

    test "GET / does not display operating hours", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Operating hours should not be shown for static branches
      refute response =~ "Mon:"
      refute response =~ "operating_hours"
    end

    test "GET / phone numbers are WhatsApp links", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Phone numbers in locations section should link to WhatsApp
      assert response =~ ~s(href="https://wa.me/96170379764")
      assert response =~ ~s(href="https://wa.me/96171633970")
    end
  end

  describe "WhatsApp CTA modal" do
    test "GET / includes the branch selector modal", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "whatsapp-modal"
      assert response =~ "Choose a Branch"
    end

    test "GET / CTA buttons trigger modal instead of anchor links", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # CTAs should use onclick to open modal, not href="#contact" or href="#packages"
      assert response =~ "document.getElementById('whatsapp-modal').showModal()"

      # Should not have anchor links to #contact
      refute response =~ ~s(href="#contact")
    end
  end
end
