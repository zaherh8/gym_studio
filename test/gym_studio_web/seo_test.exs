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
      assert content =~ "https://reactgym.com/offer"
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
