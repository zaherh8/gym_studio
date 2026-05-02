defmodule GymStudioWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GymStudioWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the WhatsApp SVG icon.

  ## Examples

      <Layouts.whatsapp_icon class="w-5 h-5" />
      <Layouts.whatsapp_icon class="w-6 h-6 text-primary" />
  """
  attr :class, :string, default: "w-5 h-5"

  def whatsapp_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
    </svg>
    """
  end

  @doc """
  Renders a mobile bottom navigation bar.

  Shows role-specific tabs with a center FAB button.
  Only visible below the `md` breakpoint.
  """
  attr :current_scope, :map, required: true
  attr :current_path, :string, required: true

  def mobile_bottom_nav(%{current_scope: %{user: %{role: :client}}} = assigns) do
    assigns = assign(assigns, :tabs, tabs_for_role(:client))

    ~H"""
    <nav
      id="mobile-bottom-nav-client"
      phx-hook="MobileBottomNav"
      data-tabs={
        Jason.encode!(
          Enum.map(
            @tabs,
            &%{
              path: to_string(&1.path),
              icon: &1[:icon],
              activeIcon: &1[:active_icon],
              label: &1.label,
              fab: &1[:fab] || false
            }
          )
        )
      }
      class="fixed bottom-0 inset-x-0 z-50 md:hidden pb-safe-bottom"
      style="backdrop-filter: blur(22px) saturate(180%); -webkit-backdrop-filter: blur(22px) saturate(180%); background: rgba(255, 255, 255, 0.75);"
    >
      <div class="border-t border-gray-200/50" style="border-top-width: 0.5px;"></div>
      <div class="flex items-center justify-around h-16 px-2 relative">
        <%= for tab <- @tabs do %>
          <%= if tab.fab do %>
            <.link
              navigate={tab.path}
              class="flex items-center justify-center fab-button"
              aria-label={tab.label}
            >
              <span
                class="flex items-center justify-center w-[62px] h-[62px] rounded-full text-white animate-booking-pulse transition-transform duration-200 hover:scale-110 active:scale-95"
                style="background: linear-gradient(135deg, #E63946, #C72F3C); box-shadow: 0 4px 16px rgba(230, 57, 70, 0.35);"
              >
                <span aria-hidden="true"><.icon name="hero-plus" class="size-7" /></span>
              </span>
            </.link>
          <% else %>
            <.link
              navigate={tab.path}
              aria-label={tab.label}
              class={[
                "flex items-center justify-center p-3 transition-all duration-200",
                if(tab_active?(@current_path, tab.path),
                  do: "text-base-content",
                  else: "text-base-content/40"
                )
              ]}
              style={
                if(tab_active?(@current_path, tab.path), do: "transform: scale(1.08);", else: "")
              }
            >
              <.icon
                name={if(tab_active?(@current_path, tab.path), do: tab.active_icon, else: tab.icon)}
                class="size-6"
              />
            </.link>
          <% end %>
        <% end %>
      </div>
    </nav>
    """
  end

  def mobile_bottom_nav(assigns) do
    assigns = assign(assigns, :tabs, tabs_for_role(assigns.current_scope.user.role))

    ~H"""
    <nav
      id="mobile-bottom-nav-trainer"
      phx-hook="MobileBottomNav"
      data-tabs={
        Jason.encode!(
          Enum.map(
            @tabs,
            &%{
              path: to_string(&1.path),
              icon: &1[:icon],
              activeIcon: &1[:active_icon],
              label: &1.label,
              fab: &1[:fab] || false
            }
          )
        )
      }
      class="fixed bottom-0 inset-x-0 z-50 bg-base-100 border-t border-base-300 md:hidden pb-safe-bottom"
    >
      <div class="flex items-center justify-around h-18 px-2">
        <%= for tab <- @tabs do %>
          <%= if tab.fab do %>
            <.link
              navigate={tab.path}
              class="flex flex-col items-center justify-center -mt-6"
              aria-label={tab.label}
            >
              <span class="flex items-center justify-center w-14 h-14 rounded-full bg-primary text-white shadow-lg transition-transform duration-200 hover:scale-110 active:scale-95 focus-within:ring-2 focus-within:ring-primary/50 focus-within:ring-offset-2">
                <.icon name={tab.icon} class="size-7" />
              </span>
            </.link>
          <% else %>
            <.link
              navigate={tab.path}
              aria-label={tab.label}
              class={[
                "flex flex-col items-center justify-center gap-1 py-2 px-3 rounded-lg transition-colors duration-200 min-w-[4rem]",
                if(tab_active?(@current_path, tab.path),
                  do: "text-primary",
                  else: "text-gray-500 hover:text-gray-700"
                )
              ]}
            >
              <.icon name={tab.icon} class="size-6" />
              <span class="text-[11px] font-medium leading-tight">{tab.label}</span>
              <%= if tab_active?(@current_path, tab.path) do %>
                <span class="w-1 h-1 rounded-full bg-primary mt-0.5"></span>
              <% end %>
            </.link>
          <% end %>
        <% end %>
      </div>
    </nav>
    """
  end

  defp tabs_for_role(:client) do
    [
      %{
        icon: "hero-home",
        active_icon: "hero-home-solid",
        label: "Home",
        path: ~p"/client",
        fab: false
      },
      %{
        icon: "hero-chart-bar",
        active_icon: "hero-chart-bar-solid",
        label: "Progress",
        path: ~p"/client/progress",
        fab: false
      },
      %{
        icon: "hero-plus",
        label: "Book",
        path: ~p"/client/book",
        fab: true
      },
      %{
        icon: "hero-calendar",
        active_icon: "hero-calendar-days-solid",
        label: "Schedule",
        path: ~p"/client/sessions",
        fab: false
      },
      %{
        icon: "hero-user",
        active_icon: "hero-user-solid",
        label: "Profile",
        path: ~p"/users/settings",
        fab: false
      }
    ]
  end

  defp tabs_for_role(:trainer) do
    [
      %{icon: "hero-home", label: "Home", path: ~p"/trainer", fab: false},
      %{icon: "hero-user-group", label: "Clients", path: ~p"/trainer/clients", fab: false},
      %{icon: "hero-plus", label: "Session", path: ~p"/trainer/sessions", fab: true},
      %{icon: "hero-calendar", label: "Schedule", path: ~p"/trainer/schedule", fab: false},
      %{icon: "hero-user", label: "Profile", path: ~p"/users/settings", fab: false}
    ]
  end

  defp tabs_for_role(:admin) do
    [
      %{icon: "hero-home", label: "Home", path: ~p"/admin", fab: false},
      %{icon: "hero-academic-cap", label: "Trainers", path: ~p"/admin/trainers", fab: false},
      %{icon: "hero-plus", label: "Session", path: ~p"/admin/sessions", fab: true},
      %{icon: "hero-map-pin", label: "Branches", path: ~p"/admin/branches", fab: false},
      %{icon: "hero-user", label: "Profile", path: ~p"/users/settings", fab: false}
    ]
  end

  defp tabs_for_role(_), do: tabs_for_role(:client)

  defp tab_active?(current_path, tab_path) do
    tab_str = to_string(tab_path)

    cond do
      # Exact match for root dashboard paths and settings
      tab_str in ~w(/client /trainer /admin /users/settings) ->
        current_path == tab_str

      # Prefix match for other paths — must match /path or /path/...
      true ->
        current_path == tab_str or String.starts_with?(current_path, tab_str <> "/")
    end
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
