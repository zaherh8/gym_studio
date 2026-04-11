defmodule GymStudioWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard showing overview statistics and quick actions.
  Supports branch filtering via session-persisted branch selector.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Branches, Packages, Scheduling}
  alias GymStudioWeb.Admin.BranchSelectorComponent

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches(active: true)
    selected_branch_id = "all"

    socket =
      socket
      |> assign(:branches, branches)
      |> assign(:selected_branch_id, selected_branch_id)
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_branch", %{"branch_id" => branch_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_branch_id, branch_id)
     |> load_dashboard_data()}
  end

  defp load_dashboard_data(socket) do
    branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)

    user_counts = Accounts.count_users_by_role(branch_id: branch_id)
    pending_trainers = length(Accounts.list_trainers(status: "pending", branch_id: branch_id))
    pending_sessions = length(Scheduling.list_pending_sessions(branch_id: branch_id))

    active_packages =
      length(
        Packages.list_all_packages(
          active: true,
          has_available_sessions: true,
          branch_id: branch_id
        )
      )

    sessions_today = Scheduling.count_sessions_today(branch_id: branch_id)
    sessions_this_week = Scheduling.count_all_sessions_this_week(branch_id: branch_id)

    assign(socket,
      page_title: "Admin Dashboard",
      user_counts: user_counts,
      pending_trainers: pending_trainers,
      pending_sessions: pending_sessions,
      active_packages: active_packages,
      sessions_today: sessions_today,
      sessions_this_week: sessions_this_week
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
        <h1 class="text-3xl font-bold">Admin Dashboard</h1>
        <BranchSelectorComponent.branch_selector
          branches={@branches}
          selected_branch_id={@selected_branch_id}
        />
      </div>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
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

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
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
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
          navigate={~p"/admin/branches"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">🏢 Manage Branches</h2>
            <p class="text-base-content/70">Add, edit, and configure gym locations</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
