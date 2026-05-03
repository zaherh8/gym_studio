defmodule GymStudioWeb.Helpers.SeoHelpers do
  @moduledoc """
  Helpers for generating SEO-related markup (JSON-LD, meta tags).
  """

  alias GymStudioWeb.Endpoint

  @doc """
  Generates JSON-LD structured data for the gym.
  Returns a JSON string (no script wrapper).
  """
  def json_ld do
    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "GymFitness",
      "name" => "React Gym",
      "description" =>
        "Private personal training studio in Horsh Tabet, Lebanon. One-on-one sessions, certified trainers, flexible scheduling.",
      "url" => "#{Endpoint.url()}/",
      "telephone" => "+961 71 104 483",
      "address" => %{
        "@type" => "PostalAddress",
        "streetAddress" => "Clover Park Bldg, 4th Floor, Horsh Tabet",
        "addressLocality" => "Sin El Fil",
        "addressCountry" => "LB"
      },
      "geo" => %{
        "@type" => "GeoCoordinates",
        "latitude" => 33.8773,
        "longitude" => 35.5268
      }
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
