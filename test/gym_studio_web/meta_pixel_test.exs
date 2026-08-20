defmodule GymStudioWeb.MetaPixelTest do
  @moduledoc """
  The pixel snippet is rendered from three separate layouts that share no
  `<head>` partial, so each one is asserted independently — a new public
  layout that forgets the pixel should fail here.
  """
  # Not async: these tests mutate the :meta_pixel_id application env.
  use GymStudioWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @pixel_id "1234567890"

  defp put_pixel_id(id) do
    previous = Application.get_env(:gym_studio, :meta_pixel_id)
    Application.put_env(:gym_studio, :meta_pixel_id, id)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:gym_studio, :meta_pixel_id)
        value -> Application.put_env(:gym_studio, :meta_pixel_id, value)
      end
    end)
  end

  describe "when META_PIXEL_ID is configured" do
    setup do
      put_pixel_id(@pixel_id)
    end

    test "renders on the offer campaign page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      assert html =~ "connect.facebook.net/en_US/fbevents.js"
      assert html =~ "fbq('init', '#{@pixel_id}')"
      assert html =~ "fbq('track', 'PageView')"
    end

    test "renders on the links page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      assert html =~ "connect.facebook.net/en_US/fbevents.js"
      assert html =~ "fbq('init', '#{@pixel_id}')"
    end

    test "renders on the main site", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "connect.facebook.net/en_US/fbevents.js"
      assert html =~ "fbq('init', '#{@pixel_id}')"
    end

    test "includes a noscript tracking fallback", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "https://www.facebook.com/tr?id=#{@pixel_id}&amp;ev=PageView&amp;noscript=1"
    end
  end

  describe "when META_PIXEL_ID is not configured" do
    setup do
      put_pixel_id(nil)
    end

    test "renders nothing on the offer page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      refute html =~ "connect.facebook.net"
      refute html =~ "fbq("
    end

    test "renders nothing on the links page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      refute html =~ "connect.facebook.net"
      refute html =~ "fbq("
    end

    test "renders nothing on the main site", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      refute html =~ "connect.facebook.net"
      refute html =~ "fbq("
    end
  end

  describe "when META_PIXEL_ID is malformed" do
    test "renders nothing rather than injecting into the script body", %{conn: conn} do
      put_pixel_id("123'); alert('xss')//")

      html = conn |> get(~p"/") |> html_response(200)

      refute html =~ "connect.facebook.net"
      refute html =~ "alert("
    end
  end

  describe "conversion event attributes" do
    test "offer CTA is tagged as a Lead with branch and utm context", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer?utm_source=flyer&utm_campaign=liftoff")

      assert html =~ ~s(data-pixel-event="Lead")
      assert html =~ ~s(data-pixel-branch="Horsh Tabet")
      assert html =~ ~s(data-pixel-source="flyer")
      assert html =~ ~s(data-pixel-campaign="liftoff")
    end

    test "offer CTA omits utm attributes when no params are present", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/offer")

      assert html =~ ~s(data-pixel-event="Lead")
      refute html =~ "data-pixel-source"
      refute html =~ "data-pixel-campaign"
    end

    test "links page location buttons are tagged as FindLocation", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      assert html =~ ~s(data-pixel-event="FindLocation")
    end

    test "whatsapp branch picker links are tagged as Leads", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/links")

      assert html =~ ~s(data-pixel-event="Lead")
    end
  end
end
