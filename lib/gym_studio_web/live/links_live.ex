defmodule GymStudioWeb.LinksLive do
  @moduledoc """
  Link-in-bio page at /links — a lightweight, mobile-first "linktree" style page
  for sharing on Instagram/social media.
  """
  use GymStudioWeb, :live_view

  @branches [
    %{
      name: "Horsh Tabet",
      address: "Clover Park, 4th floor",
      phone: "+961 70 379 764",
      whatsapp_url:
        "https://wa.me/96170379764?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F",
      directions_url: "https://www.google.com/maps/place/33.8709623,35.5343566"
    },
    %{
      name: "Jal El Dib",
      address: "Main Street",
      phone: "+961 71 633 970",
      whatsapp_url:
        "https://wa.me/96171633970?text=Hello%2C%20can%20you%20tell%20me%20more%20about%20the%20service%20you%20provide%20at%20React%3F",
      directions_url: "https://www.google.com/maps/place/33.9069,35.5801"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "React Gym — Links")
      |> assign(:branches, @branches)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full bg-gradient-to-b from-neutral to-base-300 flex flex-col items-center px-6 py-12">
      <%!-- Logo --%>
      <div class="mb-3">
        <img
          src={~p"/images/logo/react-wordmark-white.svg"}
          alt="React"
          class="h-14 w-auto"
        />
      </div>

      <%!-- Slogan --%>
      <p class="text-white/70 text-sm tracking-wide mb-10">
        Where Fitness Meets Personal Attention
      </p>

      <%!-- Link Buttons --%>
      <div class="w-full max-w-sm space-y-4">
        <%!-- Website link --%>
        <a
          href={~p"/"}
          class="flex items-center justify-center gap-2 w-full py-3.5 px-6 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 text-white font-semibold hover:bg-primary hover:border-primary hover:shadow-lg hover:shadow-primary/30 hover:scale-[1.02] transition-all duration-200"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"
            />
          </svg>
          <span>Visit Our Website</span>
        </a>

        <%!-- Location buttons --%>
        <%= for branch <- @branches do %>
          <a
            href={branch.directions_url}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center justify-center gap-2 w-full py-3.5 px-6 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 text-white font-semibold hover:bg-primary hover:border-primary hover:shadow-lg hover:shadow-primary/30 hover:scale-[1.02] transition-all duration-200"
          >
            <span class="text-lg">📍</span>
            <span>{branch.name}</span>
          </a>
        <% end %>

        <%!-- WhatsApp "Chat with us" button --%>
        <button
          onclick="document.getElementById('whatsapp-modal').showModal()"
          class="flex items-center justify-center gap-2 w-full py-3.5 px-6 rounded-full bg-primary text-white font-semibold border border-primary hover:bg-primary-focus hover:shadow-lg hover:shadow-primary/30 hover:scale-[1.02] transition-all duration-200"
        >
          <Layouts.whatsapp_icon class="w-5 h-5" />
          <span>Chat with us</span>
        </button>
      </div>

      <%!-- Instagram section --%>
      <div class="mt-10 flex flex-col items-center gap-2">
        <p class="text-white/50 text-sm">Follow us on</p>
        <a
          href="https://www.instagram.com/react.lb"
          target="_blank"
          rel="noopener noreferrer"
          class="w-12 h-12 rounded-full bg-white/10 flex items-center justify-center hover:bg-primary transition-colors duration-200"
          aria-label="Follow us on Instagram"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            class="fill-current text-white"
          >
            <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z" />
          </svg>
        </a>
      </div>
    </div>

    <%!-- WhatsApp Branch Picker Modal --%>
    <dialog id="whatsapp-modal" class="modal modal-bottom sm:modal-middle">
      <div class="modal-box">
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
        </form>
        <h3 class="text-lg font-bold mb-1">Choose a Branch</h3>
        <p class="text-sm text-gray-500 mb-5">Select which studio to contact on WhatsApp</p>
        <div class="grid gap-4">
          <%= for branch <- @branches do %>
            <a
              href={branch.whatsapp_url}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-4 p-4 rounded-xl border border-gray-200 hover:border-primary/40 hover:shadow-md transition-all group"
            >
              <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:bg-primary/20 transition-colors">
                <Layouts.whatsapp_icon class="w-6 h-6 text-primary" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-gray-900">{branch.name}</p>
                <p class="text-sm text-gray-500 truncate">{branch.phone}</p>
              </div>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-gray-400 group-hover:text-primary transition-colors flex-shrink-0"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </a>
          <% end %>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end
end
