defmodule GymStudioWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard showing overview statistics and quick actions.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Packages, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    # Get statistics
    pending_trainers = length(Accounts.list_trainers(status: "pending"))
    pending_sessions = length(Scheduling.list_pending_sessions())
    total_clients = length(Accounts.list_users(role: :client))

    active_packages =
      length(Packages.list_all_packages(active: true, has_available_sessions: true))

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       pending_trainers: pending_trainers,
       pending_sessions: pending_sessions,
       total_clients: total_clients,
       active_packages: active_packages
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Admin Dashboard</h1>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-figure text-warning">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <div class="stat-title">Pending Sessions</div>
          <div class="stat-value text-warning">{@pending_sessions}</div>
          <div class="stat-desc">Awaiting approval</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-figure text-info">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
          </div>
          <div class="stat-title">Pending Trainers</div>
          <div class="stat-value text-info">{@pending_trainers}</div>
          <div class="stat-desc">Awaiting approval</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-figure text-primary">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
              />
            </svg>
          </div>
          <div class="stat-title">Total Clients</div>
          <div class="stat-value text-primary">{@total_clients}</div>
          <div class="stat-desc">Registered clients</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-figure text-success">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <div class="stat-title">Active Packages</div>
          <div class="stat-value text-success">{@active_packages}</div>
          <div class="stat-desc">With available sessions</div>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link
          navigate={~p"/admin/sessions"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              Manage Sessions
            </h2>
            <p class="text-base-content/70">Approve, assign, or cancel training sessions</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/trainers"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                />
              </svg>
              Manage Trainers
            </h2>
            <p class="text-base-content/70">Approve or suspend trainer profiles</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/packages/new"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                />
              </svg>
              Assign Package
            </h2>
            <p class="text-base-content/70">Assign a session package to a client</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/clients"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                />
              </svg>
              Manage Clients
            </h2>
            <p class="text-base-content/70">View and manage client accounts</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/analytics"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                />
              </svg>
              Analytics
            </h2>
            <p class="text-base-content/70">View reports and statistics</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/gallery"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              Manage Gallery
            </h2>
            <p class="text-base-content/70">Upload and manage gym photos</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
