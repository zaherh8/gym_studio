defmodule GymStudioWeb.PageControllerTest do
  use GymStudioWeb.ConnCase

  import GymStudio.AccountsFixtures

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "react-wordmark"
    assert response =~ "Private Training."
    assert response =~ "Built Around You."
  end

  # The section now renders from static data in PageController, so an approved
  # DB trainer must NOT leak onto the public page while the portal is still
  # gated behind #92.
  test "GET / trainers section ignores database records", %{conn: conn} do
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer_fixture(%{
        bio: "Expert in strength training",
        specializations: ["Strength", "HIIT"]
      })

    GymStudio.Accounts.approve_trainer(trainer, admin)

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Meet Your"
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
      # All branches schedule
      assert response =~ "All branches follow the same schedule"
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

      # Scoped to the branch photos themselves. The page-wide assertion this
      # used to make broke once the hero adopted <picture> to serve a
      # different photo to phones — that is the hero's concern, not this one.
      branch_photos =
        response
        |> String.split("horsh-tabet-kettlebell")
        |> Enum.drop(1)
        |> Enum.join()

      refute branch_photos =~ "<picture>"
      refute response =~ ~s(type="image/webp")
      assert response =~ "sizes=\"(max-width: 640px) 400px, 800px\""
    end
  end

  describe "stats section" do
    test "GET / renders the counters with their targets", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ ~s(data-count-up)
      assert response =~ ~s(data-count-to="100")
      assert response =~ ~s(data-count-suffix="+")
      assert response =~ ~s(data-count-to="9")
      assert response =~ "Happy Members"
      assert response =~ "Expert Trainers"
    end

    test "GET / counters read as zero before JS runs", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # The server-rendered value is the pre-animation state, so the section is
      # still coherent without JS, behind an ad blocker, or before the bundle
      # loads — rather than rendering empty and popping in.
      [_, after_members | _] = String.split(response, ~s(data-count-to="100"))
      assert after_members =~ ~r/\A[^<]*>\s*0\+/s

      [_, after_trainers | _] = String.split(response, ~s(data-count-to="9"))
      assert after_trainers =~ ~r/\A[^<]*>\s*0\s*</s
    end

    test "GET / stats stay out of the hero", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # #140 cut the hero stats row to keep one promise and one CTA. The
      # counters live below the fold; this guards against them creeping back.
      [hero | _] = String.split(response, "Why React Gym?")
      refute hero =~ "data-count-up"
      refute hero =~ "Happy Members"
    end
  end

  describe "trainers section" do
    test "GET / renders every trainer with a photo", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      for slug <- ~w(mario lynn maroun elio sandy) do
        assert response =~ "/images/trainers/#{slug}-400w.jpg 400w"
        assert response =~ "/images/trainers/#{slug}-800w.jpg 800w"
      end

      for name <- ~w(Mario Lynn Maroun Elio Sandy) do
        assert response =~ name
      end
    end

    test "GET / renders the bios that exist", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ "HYROX Certified Coach"
      assert response =~ "four years of experience in personal training"
      assert response =~ "Sports Science at UA University"
    end

    test "GET / omits the bio paragraph for trainers without one", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # Elio and Sandy have photos but no copy yet. Their cards should render
      # name, photo, and specializations rather than an empty paragraph.
      refute response =~ ~s(<p class="text-gray-600 text-sm leading-relaxed"></p>)
    end

    test "GET / trainer cards carry no branch badge", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # Trainers move between studios, so a branch on the card dates quickly.
      [_, rest | _] = String.split(response, ~s(id="trainers"))
      [section | _] = String.split(rest, ~s(id="packages"))

      refute section =~ "badge-primary"
      refute section =~ "Horsh Tabet"
      refute section =~ "Jal El Dib"
    end

    test "GET / trainers render as a scroll-snap carousel", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # Traffic is almost entirely mobile, where a grid stacks into a long
      # column. The swipe is native CSS so it works before the bundle loads.
      assert response =~ "data-trainer-carousel"
      assert response =~ "data-trainer-track"
      assert response =~ "snap-x"
      assert response =~ "snap-mandatory"

      slides = response |> String.split("data-trainer-slide") |> length() |> Kernel.-(1)
      assert slides == 5

      dots = response |> String.split("data-trainer-dot") |> length() |> Kernel.-(1)
      assert dots == 5
    end

    test "GET / carousel slides are narrower than the viewport on mobile", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      # A partial next card is what signals the row is swipeable at all.
      assert response =~ "w-[78%]"
    end

    test "GET / trainer photos are lazy loaded with explicit dimensions", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      [_, rest | _] = String.split(response, ~s(id="trainers"))
      [section | _] = String.split(rest, ~s(id="packages"))

      # Width/height prevent layout shift as the images load in.
      assert section =~ ~s(loading="lazy")
      assert section =~ ~s(width="800")
      assert section =~ ~s(height="1066")
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
