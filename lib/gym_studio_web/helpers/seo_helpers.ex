defmodule GymStudioWeb.Helpers.SeoHelpers do
  @moduledoc """
  Helpers for generating SEO-related markup (JSON-LD, meta tags).
  """

  alias GymStudioWeb.Endpoint

  # Both branches, deliberately. This is the text Google shows in results, and
  # it named Horsh Tabet only — so half the local search footprint was missing
  # from the one tag that actually counts.
  @description "Private personal training studio in Jal El Dib and Horsh Tabet, Lebanon. One-on-one sessions, certified trainers, flexible scheduling."

  @doc """
  The site description, used for `<meta name="description">`, Open Graph,
  Twitter cards, and JSON-LD.

  Single source so the branches cannot drift apart across tags again.
  """
  def description, do: @description

  @doc """
  Generates JSON-LD structured data for the gym.
  Returns a JSON string (no script wrapper).
  """
  def json_ld do
    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "GymFitness",
      "name" => "React Gym",
      "description" => @description,
      "url" => "#{Endpoint.url()}/",
      "telephone" => "+961 70 379 764",
      "address" => %{
        "@type" => "PostalAddress",
        "streetAddress" => "Clover Park Bldg, 4th Floor, Horsh Tabet",
        "addressLocality" => "Horsh Tabet",
        "addressCountry" => "LB"
      },
      "geo" => %{
        "@type" => "GeoCoordinates",
        "latitude" => 33.8709623,
        "longitude" => 35.5343566
      },
      # Both studios as separate locations. A single address made Jal El Dib
      # invisible to local search; coordinates match the Get Directions links
      # on the landing page.
      "department" => [
        %{
          "@type" => "GymFitness",
          "name" => "React — Horsh Tabet",
          "telephone" => "+961 70 379 764",
          "address" => %{
            "@type" => "PostalAddress",
            "streetAddress" => "Clover Park, 4th floor",
            "addressLocality" => "Horsh Tabet",
            "addressCountry" => "LB"
          },
          "geo" => %{
            "@type" => "GeoCoordinates",
            "latitude" => 33.8709623,
            "longitude" => 35.5343566
          }
        },
        %{
          "@type" => "GymFitness",
          "name" => "React — Jal El Dib",
          "telephone" => "+961 71 633 970",
          "address" => %{
            "@type" => "PostalAddress",
            "streetAddress" => "Main Street",
            "addressLocality" => "Jal El Dib",
            "addressCountry" => "LB"
          },
          "geo" => %{
            "@type" => "GeoCoordinates",
            "latitude" => 33.9069,
            "longitude" => 35.5801
          }
        }
      ]
    })
  end

  @doc """
  Generates the full JSON-LD `<script>` tag.
  Returns an HTML-safe string with the complete `<script type="application/ld+json">` block.

  This is necessary because HEEx does NOT evaluate Elixir expressions inside
  `<script>` tag content — `{raw(...)}` inside `<script>` is rendered literally.
  Using `<%= raw(...) %>` with the complete tag output bypasses this limitation.
  """
  def json_ld_script do
    ~s(<script type="application/ld+json">#{json_ld()}</script>)
  end
end
