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
      assert response =~ "place/33.8709"
      assert response =~ "place/33.9069"
    end

    test "GET / displays opening hours section", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Opening hours section
      assert response =~ "Opening Hours"
      assert response =~ "When We're"
      assert response =~ "Monday – Friday"
      assert response =~ "6:00 AM – 10:00 PM"
      assert response =~ "Saturday"
      assert response =~ "6:00 AM – 2:00 PM"
      assert response =~ "Sunday"
      assert response =~ "Closed"
      # Both branches note
      assert response =~ "Both Horsh Tabet &amp; Jal El Dib branches"
    end

    test "GET / does not display DB-driven operating_hours", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # The old DB-driven operating_hours field should not be rendered
      refute response =~ "operating_hours"
    end

    test "GET / phone numbers are WhatsApp links", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Phone numbers in locations section should link to WhatsApp with pre-filled message
      assert response =~
               ~s(href="https://wa.me/96170379764?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F")

      assert response =~
               ~s(href="https://wa.me/96171633970?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F")
    end
  end

  describe "branch photos" do
    test "GET / renders branch photos with responsive srcset", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Horsh Tabet photo
      assert response =~ "horsh-tabet-kettlebell-400w.webp 400w"
      assert response =~ "horsh-tabet-kettlebell-800w.webp 800w"
      assert response =~ "horsh-tabet-kettlebell-1200w.webp 1200w"

      # Jal El Dib photo
      assert response =~ "jal-el-dib-stretching-400w.webp 400w"
      assert response =~ "jal-el-dib-stretching-800w.webp 800w"
      assert response =~ "jal-el-dib-stretching-1200w.webp 1200w"
    end

    test "GET / branch photos have lazy loading and async decoding", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ ~s(loading="lazy")
      assert response =~ ~s(decoding="async")
    end

    test "GET / branch photos have descriptive alt text", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "React Gym Horsh Tabet member performing kettlebell press"
      assert response =~ "React Gym Jal El Dib smiling client"
    end

    test "GET / branch photos use plain img tags without picture wrapper", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      refute response =~ "<picture>"
      refute response =~ ~s(type="image/webp")
      assert response =~ "sizes=\"(max-width: 640px) 400px, 800px\""
    end
  end

  describe "testimonials" do
    test "GET / renders all testimonial authors", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Arline Atamian"
      assert response =~ "Joseph Rehayem"
      assert response =~ "Christelle Fawaz"
      assert response =~ "Youssef Khouzami"
      assert response =~ "Nader Abou Nader"
    end

    test "GET / includes carousel container with data attribute", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "data-testimonial-carousel"
    end

    test "GET / renders correct number of slides", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # 5 slides with data-slide attribute
      slide_count = response |> String.split("data-slide") |> length() |> Kernel.-(1)
      assert slide_count == 5
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
