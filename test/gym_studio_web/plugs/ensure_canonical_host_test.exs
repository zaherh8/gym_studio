defmodule GymStudioWeb.Plugs.EnsureCanonicalHostTest do
  use GymStudioWeb.ConnCase, async: true

  alias GymStudioWeb.Plugs.EnsureCanonicalHost

  describe "call/2" do
    test "does not redirect when host is not gym-studio.fly.dev" do
      conn =
        build_conn()
        |> Map.put(:host, "reactgym.com")
        |> EnsureCanonicalHost.call("reactgym.com")

      refute conn.halted
      assert conn.status == nil
    end

    test "redirects with 301 when host is gym-studio.fly.dev" do
      conn =
        build_conn()
        |> Map.put(:host, "gym-studio.fly.dev")
        |> EnsureCanonicalHost.call("reactgym.com")

      assert conn.halted
      assert conn.status == 301
      assert Plug.Conn.get_resp_header(conn, "location") == ["https://reactgym.com/"]
    end

    test "redirects preserves request path" do
      conn =
        build_conn(:get, "/client/sessions")
        |> Map.put(:host, "gym-studio.fly.dev")
        |> EnsureCanonicalHost.call("reactgym.com")

      assert conn.halted
      assert conn.status == 301

      assert Plug.Conn.get_resp_header(conn, "location") == [
               "https://reactgym.com/client/sessions"
             ]
    end

    test "does not redirect when canonical host is the same as fly.dev host" do
      conn =
        build_conn()
        |> Map.put(:host, "gym-studio.fly.dev")
        |> EnsureCanonicalHost.call("gym-studio.fly.dev")

      refute conn.halted
    end

    test "does not redirect on localhost" do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> EnsureCanonicalHost.call("reactgym.com")

      refute conn.halted
    end
  end
end
