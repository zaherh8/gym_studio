defmodule GymStudioWeb.Helpers.SeoHelpers do
  @moduledoc """
  Helpers for generating SEO-related markup (JSON-LD, meta tags).
  """

  alias GymStudioWeb.Endpoint

  @doc """
  Generates JSON-LD structured data for the gym.
  Returns an HTML-safe string ready for injection into a <script> tag.
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
end
