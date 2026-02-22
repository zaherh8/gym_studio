defmodule GymStudioWeb.Client.PackagesLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Accounts, Packages}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = Accounts.get_client_by_user_id(user.id)

    packages = Packages.list_packages_for_client(user.id)

    socket =
      socket
      |> assign(page_title: "My Packages")
      |> assign(client: client)
      |> assign(packages: packages)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">My Packages</h1>

      <%= if @client == nil do %>
        <div class="alert alert-warning">
          <span>Your client profile is not set up yet. Please contact an administrator.</span>
        </div>
      <% else %>
        <%= if Enum.empty?(@packages) do %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center">
              <p class="text-base-content/70">You don't have any packages yet.</p>
              <p class="text-sm">Contact your trainer or admin to get started!</p>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for package <- @packages do %>
              <div class={"card bg-base-100 shadow-xl #{if package.active, do: "border-2 border-primary"}"}>
                <div class="card-body">
                  <div class="flex justify-between items-start">
                    <h2 class="card-title">{format_package_type(package.package_type)}</h2>
                    <span class={"badge #{if package.active, do: "badge-success", else: "badge-ghost"}"}>
                      {if package.active, do: "Active", else: "Inactive"}
                    </span>
                  </div>

                  <div class="stat p-0 my-4">
                    <div class="stat-value text-primary">
                      {package.remaining_sessions}
                    </div>
                    <div class="stat-desc">of {package.total_sessions} sessions remaining</div>
                  </div>
                  
    <!-- Progress bar -->
                  <div class="w-full bg-base-300 rounded-full h-2.5">
                    <div
                      class="bg-primary h-2.5 rounded-full"
                      style={"width: #{package.remaining_sessions / package.total_sessions * 100}%"}
                    >
                    </div>
                  </div>

                  <div class="mt-4 text-sm text-base-content/70">
                    <p>Purchased: {Calendar.strftime(package.inserted_at, "%B %d, %Y")}</p>
                    <%= if package.expires_at do %>
                      <p>Expires: {Calendar.strftime(package.expires_at, "%B %d, %Y")}</p>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
      
    <!-- Package Info -->
      <div class="card bg-base-100 shadow-xl mt-8">
        <div class="card-body">
          <h2 class="card-title">Available Packages</h2>
          <p class="text-base-content/70">
            We offer three package options to fit your training needs:
          </p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
            <div class="text-center p-4 border rounded-lg">
              <div class="text-2xl font-bold text-primary">8</div>
              <div class="text-sm">Sessions</div>
            </div>
            <div class="text-center p-4 border rounded-lg">
              <div class="text-2xl font-bold text-primary">12</div>
              <div class="text-sm">Sessions</div>
            </div>
            <div class="text-center p-4 border rounded-lg">
              <div class="text-2xl font-bold text-primary">20</div>
              <div class="text-sm">Sessions</div>
            </div>
          </div>
          <p class="text-sm text-base-content/70 mt-4">
            Contact your trainer or visit us at the gym to purchase a package.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp format_package_type("standard_8"), do: "Starter (8 Sessions)"
  defp format_package_type("standard_12"), do: "Standard (12 Sessions)"
  defp format_package_type("premium_20"), do: "Premium (20 Sessions)"
  defp format_package_type(type), do: type
end
