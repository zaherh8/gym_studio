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
  Renders a mobile bottom navigation bar.

  Shows role-specific tabs with a center FAB button.
  Only visible below the `md` breakpoint.
  """
  attr :current_scope, :map, required: true
  attr :current_path, :string, required: true

  def mobile_bottom_nav(assigns) do
    assigns = assign(assigns, :tabs, tabs_for_role(assigns.current_scope.user.role))

    ~H"""
    <nav class="fixed bottom-0 inset-x-0 z-50 bg-base-100 border-t border-base-300 md:hidden">
      <div class="flex items-end justify-around h-16 px-2">
        <%= for tab <- @tabs do %>
          <%= if tab.fab do %>
            <.link
              href={tab.path}
              class="flex flex-col items-center justify-center -mt-6"
              aria-label={tab.label}
            >
              <span class="flex items-center justify-center w-14 h-14 rounded-full bg-primary text-white shadow-lg transition-transform duration-200 hover:scale-110 active:scale-95">
                <.icon name={tab.icon} class="size-7" />
              </span>
            </.link>
          <% else %>
            <.link
              href={tab.path}
              class={[
                "flex flex-col items-center justify-center gap-0.5 py-2 px-3 rounded-lg transition-colors duration-200 min-w-[4rem]",
                if(tab_active?(@current_path, tab.path),
                  do: "text-primary",
                  else: "text-gray-500 hover:text-gray-700"
                )
              ]}
            >
              <.icon name={tab.icon} class="size-6" />
              <span class="text-[10px] font-medium leading-tight">{tab.label}</span>
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
      %{icon: "hero-home", label: "Home", path: ~p"/client", fab: false},
      %{icon: "hero-calendar", label: "Schedule", path: ~p"/client/sessions", fab: false},
      %{icon: "hero-plus", label: "Book", path: ~p"/client/book", fab: true},
      %{icon: "hero-chart-bar", label: "Progress", path: ~p"/client/progress", fab: false},
      %{icon: "hero-user", label: "Profile", path: ~p"/users/settings", fab: false}
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
      # Exact match for root dashboard paths
      tab_str in ~w(/client /trainer /admin) ->
        current_path == tab_str

      # Settings page exact match
      tab_str == "/users/settings" ->
        current_path == tab_str

      # Prefix match for other paths
      true ->
        String.starts_with?(current_path, tab_str)
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
