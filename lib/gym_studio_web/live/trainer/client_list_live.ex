defmodule GymStudioWeb.Trainer.ClientListLive do
  @moduledoc """
  Trainer client list page — shows all unique clients the trainer has sessions with.
  Supports search by client name.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    clients = Scheduling.list_trainer_clients(user.id)

    socket =
      socket
      |> assign(page_title: "My Clients")
      |> assign(clients: clients)
      |> assign(search: "")

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    user = socket.assigns.current_scope.user
    clients = Scheduling.list_trainer_clients(user.id, search: search)
    {:noreply, assign(socket, clients: clients, search: search)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 py-8">
      <div class="container mx-auto px-4">
        <div class="mb-6">
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800">My Clients</h1>
          <p class="text-gray-600 mt-1">Clients you've trained with</p>
        </div>

        <%!-- Search --%>
        <div class="mb-6">
          <form phx-change="search">
            <input
              type="text"
              name="search"
              value={@search}
              placeholder="Search by client name..."
              class="input input-bordered w-full max-w-xs"
              phx-debounce="300"
            />
          </form>
        </div>

        <%!-- Client Cards --%>
        <%= if @clients == [] do %>
          <div class="bg-white rounded-2xl shadow-lg p-8 text-center">
            <p class="text-gray-500 text-lg">No clients found.</p>
            <p class="text-gray-400 mt-2">
              <%= if @search != "" do %>
                No clients match your search.
              <% else %>
                You'll see clients here once you have training sessions.
              <% end %>
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for client <- @clients do %>
              <div class="bg-white rounded-2xl shadow-lg p-5">
                <h3 class="font-semibold text-lg text-gray-800 mb-2">
                  {client.name || client.email || "Unknown"}
                </h3>
                <div class="space-y-1 text-sm text-gray-600 mb-4">
                  <p>Total sessions: <span class="font-medium">{client.total_sessions}</span></p>
                  <p>
                    Last session:
                    <span class="font-medium">
                      {Calendar.strftime(client.last_session_date, "%b %d, %Y")}
                    </span>
                  </p>
                </div>
                <.link
                  navigate={~p"/trainer/clients/#{client.user_id}/progress"}
                  class="btn btn-primary btn-sm"
                >
                  View Progress →
                </.link>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
