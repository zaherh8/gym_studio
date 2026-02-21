defmodule GymStudioWeb.Admin.UsersLive do
  use GymStudioWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Manage Users")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Users</h1>
      <p class="text-base-content/70">User management coming soon...</p>
    </div>
    """
  end
end
