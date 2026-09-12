defmodule GymStudioWeb.SeoTest do
  use GymStudioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GymStudioWeb.Helpers.SeoHelpers

  describe "json_ld/0" do
    test "returns valid JSON" do
      json = SeoHelpers.json_ld()
      assert {:ok, _decoded} = Jason.decode(json)
    end

    test "contains required schema.org fields" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      assert decoded["@context"] == "https://schema.org"
      assert decoded["@type"] == "GymFitness"
      assert decoded["name"] == "React Gym"
      assert decoded["url"]
      assert decoded["telephone"]
      assert decoded["address"]
      assert decoded["geo"]
    end

    test "address has required schema.org fields" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      address = decoded["address"]
      assert address["@type"] == "PostalAddress"
      assert address["streetAddress"]
      assert address["addressLocality"]
      assert address["addressCountry"] == "LB"
    end

    test "lists both studios as departments" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      names = Enum.map(decoded["department"], & &1["name"])
      assert "React — Horsh Tabet" in names
      assert "React — Jal El Dib" in names
    end

    test "each department carries its own address, phone, and coordinates" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      for dept <- decoded["department"] do
        assert dept["address"]["addressCountry"] == "LB"
        assert dept["address"]["addressLocality"]
        assert dept["telephone"]
        assert is_number(dept["geo"]["latitude"])
        assert is_number(dept["geo"]["longitude"])
      end
    end

    test "phone matches a real branch line" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      # The old value (+961 71 104 483) matched neither branch — it pointed
      # Google at a number that appears nowhere else in the project.
      assert decoded["telephone"] in ["+961 70 379 764", "+961 71 633 970"]
    end

    test "geo has latitude and longitude" do
      json = SeoHelpers.json_ld()
      {:ok, decoded} = Jason.decode(json)

      geo = decoded["geo"]
      assert geo["@type"] == "GeoCoordinates"
      assert is_number(geo["latitude"])
      assert is_number(geo["longitude"])
    end
  end

  describe "json_ld_script/0" do
    test "returns a complete script tag" do
      html = SeoHelpers.json_ld_script()

      assert html =~ ~s(<script type="application/ld+json">)
      assert html =~ "</script>"
    end

    test "contains valid JSON inside the script tag" do
      html = SeoHelpers.json_ld_script()

      # Extract JSON between script tags
      [_, json, _] = Regex.split(~r{</?script[^>]*>}, html)
      assert {:ok, _decoded} = Jason.decode(json)
    end
  end

  describe "root layout SEO meta tags" do
    test "description names both branches" do
      html = build_conn() |> get("/") |> html_response(200)

      assert html =~ ~s(name="description")
      assert html =~ "Jal El Dib and Horsh Tabet"
    end

    test "description is shared across description, og, and twitter tags" do
      html = build_conn() |> get("/") |> html_response(200)

      # One source, so the branches cannot drift apart between tags again:
      # description, og:description, twitter:description, and the JSON-LD.
      occurrences =
        html |> String.split(SeoHelpers.description()) |> length() |> Kernel.-(1)

      assert occurrences == 4
    end

    test "no keywords tag" do
      html = build_conn() |> get("/") |> html_response(200)

      # Google has ignored it since 2009, and ours listed Sin El Fil, which is
      # not a branch. Removed rather than rewritten.
      refute html =~ ~s(name="keywords")
    end

    test "home page has og:image meta tag" do
      conn = build_conn()
      conn = get(conn, "/")
      html = html_response(conn, 200)

      assert html =~ ~s(property="og:image")
      assert html =~ "hero-gym.jpg"
    end

    test "home page has twitter:image meta tag" do
      conn = build_conn()
      conn = get(conn, "/")
      html = html_response(conn, 200)

      assert html =~ ~s(name="twitter:image")
      assert html =~ "hero-gym.jpg"
    end

    test "home page has JSON-LD structured data" do
      conn = build_conn()
      conn = get(conn, "/")
      html = html_response(conn, 200)

      assert html =~ ~s(<script type="application/ld+json">)
      assert html =~ "schema.org"
      assert html =~ "GymFitness"
    end
  end

  describe "offer layout SEO meta tags" do
    test "offer page has og:image meta tag" do
      conn = build_conn()
      {:ok, _view, html} = live(conn, "/offer")

      assert html =~ ~s(property="og:image")
      assert html =~ "hero-gym.jpg"
    end

    test "offer page has twitter:image meta tag" do
      conn = build_conn()
      {:ok, _view, html} = live(conn, "/offer")

      assert html =~ ~s(name="twitter:image")
    end
  end

  describe "links layout SEO meta tags" do
    test "links page has og:image meta tag" do
      conn = build_conn()
      {:ok, _view, html} = live(conn, "/links")

      assert html =~ ~s(property="og:image")
      assert html =~ "hero-gym.jpg"
    end
  end

  describe "sitemap.xml" do
    test "sitemap.xml file exists and is valid XML" do
      sitemap_path =
        Path.join([Application.app_dir(:gym_studio), "priv", "static", "sitemap.xml"])

      # In test, priv may not be in app dir; check the source priv dir instead
      source_path = Path.join([File.cwd!(), "priv", "static", "sitemap.xml"])
      path = if File.exists?(sitemap_path), do: sitemap_path, else: source_path

      assert File.exists?(path), "sitemap.xml not found at #{path}"

      content = File.read!(path)
      assert content =~ ~s(<?xml)
      assert content =~ ~s(<urlset)
      assert content =~ ~s(</urlset>)
    end

    test "sitemap contains all static pages" do
      source_path = Path.join([File.cwd!(), "priv", "static", "sitemap.xml"])
      content = File.read!(source_path)

      assert content =~ "https://reactgym.com/"
      assert content =~ "https://reactgym.com/links"
    end

    test "sitemap entries have lastmod, changefreq, and priority" do
      source_path = Path.join([File.cwd!(), "priv", "static", "sitemap.xml"])
      content = File.read!(source_path)

      assert content =~ "<lastmod>"
      assert content =~ "<changefreq>"
      assert content =~ "<priority>"
    end
  end

  describe "robots.txt" do
    test "robots.txt has proper directives" do
      source_path = Path.join([File.cwd!(), "priv", "static", "robots.txt"])
      content = File.read!(source_path)

      assert content =~ "User-agent: *"
      assert content =~ "Allow: /"
      assert content =~ "Disallow: /users/"
      assert content =~ "Sitemap: https://reactgym.com/sitemap.xml"
    end
  end
end
