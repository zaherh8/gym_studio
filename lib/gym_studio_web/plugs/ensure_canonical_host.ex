defmodule GymStudioWeb.Plugs.EnsureCanonicalHost do
  @moduledoc """
  Redirects requests to non-canonical hosts (e.g. gym-studio.fly.dev)
  to the configured canonical host with a 301 permanent redirect.

  Only active in production. In dev/test, the host is already localhost
  and no redirect is needed.
  """
  import Plug.Conn

  @fly_dev_host "gym-studio.fly.dev"

  def init(opts), do: Keyword.get(opts, :canonical_host, canonical_host_from_endpoint())

  def call(conn, canonical_host) do
    if conn.host == @fly_dev_host and canonical_host != @fly_dev_host do
      conn
      |> redirect_to_canonical(canonical_host)
      |> halt()
    else
      conn
    end
  end

  defp redirect_to_canonical(conn, canonical_host) do
    path =
      if conn.query_string == "",
        do: conn.request_path,
        else: "#{conn.request_path}?#{conn.query_string}"

    url = "https://#{canonical_host}#{path}"

    conn
    |> put_resp_header("location", url)
    |> resp(301, "Redirecting to #{url}")
  end

  defp canonical_host_from_endpoint do
    :gym_studio
    |> Application.fetch_env!(GymStudioWeb.Endpoint)
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:host)
  end
end
