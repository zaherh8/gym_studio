defmodule GymStudioWeb.GalleryLive do
  @moduledoc """
  Public photo gallery showcasing the gym's interior and ambience.
  """
  use GymStudioWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Placeholder images - will be replaced with Telnyx storage images
    images = [
      %{id: 1, title: "Training Area", category: "interior", url: nil},
      %{id: 2, title: "Equipment Zone", category: "equipment", url: nil},
      %{id: 3, title: "Reception", category: "interior", url: nil}
    ]

    {:ok, assign(socket, images: images, page_title: "Gallery")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Hero Section --%>
      <section class="py-20 bg-base-200">
        <div class="container mx-auto px-4 text-center">
          <h1 class="text-4xl md:text-5xl font-bold mb-4">
            Our <span class="text-primary">Space</span>
          </h1>
          <p class="text-xl text-base-content/70 max-w-2xl mx-auto">
            Take a virtual tour of our state-of-the-art private training studio.
          </p>
        </div>
      </section>

      <%!-- Gallery Grid --%>
      <section class="py-16">
        <div class="container mx-auto px-4">
          <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for image <- @images do %>
              <div class="card bg-base-200 shadow-xl overflow-hidden">
                <figure class="aspect-video bg-base-300 flex items-center justify-center">
                  <%= if image.url do %>
                    <img src={image.url} alt={image.title} class="w-full h-full object-cover" />
                  <% else %>
                    <div class="text-center p-8">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-base-content/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <p class="text-base-content/50 mt-2">Coming Soon</p>
                    </div>
                  <% end %>
                </figure>
                <div class="card-body">
                  <h2 class="card-title"><%= image.title %></h2>
                  <div class="badge badge-outline"><%= image.category %></div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end
end
