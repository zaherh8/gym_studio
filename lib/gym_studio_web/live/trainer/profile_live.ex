defmodule GymStudioWeb.Trainer.ProfileLive do
  use GymStudioWeb, :live_view
  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    trainer = Accounts.get_trainer_by_user_id(user.id)

    socket =
      socket
      |> assign(page_title: "My Profile")
      |> assign(trainer: trainer)
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

        <!-- Trainer Profile Card -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Trainer Profile</h2>
            <%= if @trainer do %>
              <div class="space-y-4">
                <div>
                  <label class="text-sm text-base-content/70">Status</label>
                  <p>
                    <span class={"badge #{trainer_status_badge(@trainer.status)}"}>
                      <%= String.capitalize(@trainer.status) %>
                    </span>
                  </p>
                </div>
                <div>
                  <label class="text-sm text-base-content/70">Bio</label>
                  <p class="font-medium"><%= @trainer.bio || "Not set" %></p>
                </div>
                <div>
                  <label class="text-sm text-base-content/70">Specializations</label>
                  <%= if Enum.empty?(@trainer.specializations || []) do %>
                    <p class="text-base-content/70">None specified</p>
                  <% else %>
                    <div class="flex flex-wrap gap-2 mt-1">
                      <%= for spec <- @trainer.specializations do %>
                        <span class="badge badge-outline"><%= spec %></span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <%= if @trainer.approved_at do %>
                  <div>
                    <label class="text-sm text-base-content/70">Approved On</label>
                    <p class="font-medium"><%= Calendar.strftime(@trainer.approved_at, "%B %d, %Y") %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="alert alert-warning">
                <span>Your trainer profile is not set up yet. Please contact an administrator.</span>
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
            <.link navigate={~p"/trainer/sessions"} class="btn btn-outline btn-sm">
              View My Sessions
            </.link>
            <.link navigate={~p"/trainer/schedule"} class="btn btn-outline btn-sm">
              View Schedule
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp trainer_status_badge("approved"), do: "badge-success"
  defp trainer_status_badge("pending"), do: "badge-warning"
  defp trainer_status_badge("suspended"), do: "badge-error"
  defp trainer_status_badge(_), do: "badge-ghost"
end
