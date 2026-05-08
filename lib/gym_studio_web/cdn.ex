defmodule GymStudioWeb.CDN do
  @moduledoc """
  CDN URL helper for static assets stored on Telnyx Cloud Storage.

  Set CDN_BASE_URL environment variable to override the default.
  Falls back to local static paths when not configured.
  """

  @default_base_url "https://us-central-1.telnyxcloudstorage.com/react-gym-studio-cdn"

  @doc """
  Returns the full CDN URL for a given asset path.

  ## Examples

      iex> GymStudioWeb.CDN.url("/images/hero-gym.jpg")
      "https://us-central-1.telnyxcloudstorage.com/react-gym-studio-cdn/images/hero-gym.jpg"
  """
  def url(path) do
    base = System.get_env("CDN_BASE_URL") || @default_base_url
    "#{base}#{path}"
  end
end
