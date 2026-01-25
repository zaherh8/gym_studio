defmodule GymStudioWeb.Admin.AnalyticsLive do
  use GymStudioWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Analytics")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Analytics</h1>
      <p class="text-base-content/70">Analytics dashboard coming soon...</p>
    </div>
    """
  end
end
