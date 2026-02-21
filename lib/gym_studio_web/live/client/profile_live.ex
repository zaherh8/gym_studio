defmodule GymStudioWeb.Client.ProfileLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = Accounts.get_client_by_user_id(user.id)

    socket =
      socket
      |> assign(page_title: "My Profile")
      |> assign(client: client)
      |> assign(user: user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">My Profile</h1>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- User Info Card -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Account Information</h2>
            <div class="space-y-4">
              <div>
                <label class="text-sm text-base-content/70">Email</label>
                <p class="font-medium"><%= @user.email %></p>
              </div>
              <div>
                <label class="text-sm text-base-content/70">Phone Number</label>
                <p class="font-medium"><%= @user.phone_number || "Not set" %></p>
              </div>
              <div>
                <label class="text-sm text-base-content/70">Account Status</label>
                <p>
                  <span class={"badge #{if @user.active, do: "badge-success", else: "badge-error"}"}>
                    <%= if @user.active, do: "Active", else: "Inactive" %>
                  </span>
                </p>
              </div>
              <div>
                <label class="text-sm text-base-content/70">Member Since</label>
                <p class="font-medium"><%= Calendar.strftime(@user.inserted_at, "%B %d, %Y") %></p>
              </div>
            </div>
            <div class="card-actions justify-end mt-4">
              <.link navigate={~p"/users/settings"} class="btn btn-primary btn-sm">
                Edit Settings
              </.link>
            </div>
          </div>
        </div>

        <!-- Client Profile Card -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Client Profile</h2>
            <%= if @client do %>
              <div class="space-y-4">
                <div>
                  <label class="text-sm text-base-content/70">Emergency Contact</label>
                  <p class="font-medium">
                    <%= if @client.emergency_contact_name do %>
                      <%= @client.emergency_contact_name %> — <%= @client.emergency_contact_phone %>
                    <% else %>
                      Not set
                    <% end %>
                  </p>
                </div>
                <div>
                  <label class="text-sm text-base-content/70">Health Notes</label>
                  <p class="font-medium"><%= @client.health_notes || "None" %></p>
                </div>
                <div>
                  <label class="text-sm text-base-content/70">Goals</label>
                  <p class="font-medium"><%= @client.goals || "Not specified" %></p>
                </div>
              </div>
            <% else %>
              <div class="alert alert-warning">
                <span>Your client profile is not set up yet. Please contact an administrator.</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Quick Links -->
      <div class="card bg-base-100 shadow-xl mt-6">
        <div class="card-body">
          <h2 class="card-title">Quick Links</h2>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/client/packages"} class="btn btn-outline btn-sm">
              View My Packages
            </.link>
            <.link navigate={~p"/client/sessions"} class="btn btn-outline btn-sm">
              View My Sessions
            </.link>
            <.link navigate={~p"/client/notifications"} class="btn btn-outline btn-sm">
              Notifications
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
