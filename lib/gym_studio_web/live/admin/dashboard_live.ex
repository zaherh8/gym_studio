defmodule GymStudioWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard showing overview statistics and quick actions.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Packages, Scheduling}

  @impl true
  def mount(_params, _session, socket) do
    user_counts = Accounts.count_users_by_role()
    pending_trainers = length(Accounts.list_trainers(status: "pending"))
    pending_sessions = length(Scheduling.list_pending_sessions())

    active_packages =
      length(Packages.list_all_packages(active: true, has_available_sessions: true))

    sessions_today = Scheduling.count_sessions_today()
    sessions_this_week = Scheduling.count_all_sessions_this_week()

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       user_counts: user_counts,
       pending_trainers: pending_trainers,
       pending_sessions: pending_sessions,
       active_packages: active_packages,
       sessions_today: sessions_today,
       sessions_this_week: sessions_this_week
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
          <div class="stat-title">Total Clients</div>
          <div class="stat-value text-primary">{Map.get(@user_counts, :client, 0)}</div>
          <div class="stat-desc">Registered clients</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title">Total Trainers</div>
          <div class="stat-value text-secondary">{Map.get(@user_counts, :trainer, 0)}</div>
          <div class="stat-desc">{@pending_trainers} pending approval</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title">Active Packages</div>
          <div class="stat-value text-success">{@active_packages}</div>
          <div class="stat-desc">With available sessions</div>
        </div>

        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title">Admins</div>
          <div class="stat-value text-accent">{Map.get(@user_counts, :admin, 0)}</div>
          <div class="stat-desc">System administrators</div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="stat bg-warning/10 rounded-box">
          <div class="stat-title">Pending Sessions</div>
          <div class="stat-value text-warning">{@pending_sessions}</div>
          <div class="stat-desc">Awaiting approval</div>
        </div>

        <div class="stat bg-info/10 rounded-box">
          <div class="stat-title">Sessions Today</div>
          <div class="stat-value text-info">{@sessions_today}</div>
          <div class="stat-desc">Scheduled for today</div>
        </div>

        <div class="stat bg-primary/10 rounded-box">
          <div class="stat-title">Sessions This Week</div>
          <div class="stat-value text-primary">{@sessions_this_week}</div>
          <div class="stat-desc">Mon–Sun</div>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <h2 class="text-xl font-semibold mb-4">Quick Actions</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link
          navigate={~p"/admin/sessions"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">📅 Manage Sessions</h2>
            <p class="text-base-content/70">Approve, assign, or cancel training sessions</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/trainers"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">🏋️ Manage Trainers</h2>
            <p class="text-base-content/70">Approve or suspend trainer profiles</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/packages/new"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">➕ Assign Package</h2>
            <p class="text-base-content/70">Assign a session package to a client</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/clients"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">👥 Manage Clients</h2>
            <p class="text-base-content/70">View and manage client accounts</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/users"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">👤 Manage Users</h2>
            <p class="text-base-content/70">Search, filter, activate/deactivate users</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/analytics"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">📊 Analytics</h2>
            <p class="text-base-content/70">View reports and statistics</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/packages"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">📦 Manage Packages</h2>
            <p class="text-base-content/70">View all packages and usage</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/gallery"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">🖼️ Manage Gallery</h2>
            <p class="text-base-content/70">Upload and manage gym photos</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
