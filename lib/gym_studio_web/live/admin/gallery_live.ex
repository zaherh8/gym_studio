defmodule GymStudioWeb.Admin.GalleryLive do
  use GymStudioWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Manage Gallery")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Gallery</h1>
      <p class="text-base-content/70">Gallery management with Telnyx storage coming soon...</p>
    </div>
    """
  end
end
