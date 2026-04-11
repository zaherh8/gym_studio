defmodule GymStudioWeb.Admin.UsersLive do
  use GymStudioWeb, :live_view

  alias GymStudio.{Accounts, Branches}
  alias GymStudioWeb.Admin.BranchSelectorComponent

  @impl true
  def mount(_params, _session, socket) do
    branches = Branches.list_branches(active: true)
    selected_branch_id = "all"
    branch_id = BranchSelectorComponent.effective_branch_id(selected_branch_id)

    {:ok,
     assign(socket,
       page_title: "Manage Users",
       branches: branches,
       selected_branch_id: selected_branch_id,
       users: Accounts.list_users(branch_id: branch_id),
       search: "",
       role_filter: "",
       confirm_action: nil,
       confirm_user_id: nil,
       show_create_user: false
     )}
  end

  @impl true
  def handle_params(%{"id" => _id}, _uri, socket) do
    # Show action handled in render
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_branch", %{"branch_id" => branch_id}, socket) do
    effective_id = BranchSelectorComponent.effective_branch_id(branch_id)

    users =
      filter_users(socket.assigns.search, socket.assigns.role_filter, effective_id)

    {:noreply, assign(socket, selected_branch_id: branch_id, users: users)}
  end

  def handle_event("search", %{"search" => search, "role" => role}, socket) do
    branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)
    users = filter_users(search, role, branch_id)
    {:noreply, assign(socket, users: users, search: search, role_filter: role)}
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    if user.active do
      {:ok, _} = Accounts.deactivate_user(user)
    else
      {:ok, _} = Accounts.activate_user(user)
    end

    branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)
    users = filter_users(socket.assigns.search, socket.assigns.role_filter, branch_id)

    {:noreply, assign(socket, users: users)}
  end

  def handle_event("show_role_change", %{"id" => id, "role" => role}, socket) do
    {:noreply,
     assign(socket,
       confirm_action: :change_role,
       confirm_user_id: id,
       confirm_role: String.to_existing_atom(role)
     )}
  end

  def handle_event("confirm_role_change", _params, socket) do
    user = Accounts.get_user!(socket.assigns.confirm_user_id)
    {:ok, _} = Accounts.change_user_role(user, socket.assigns.confirm_role)

    branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)
    users = filter_users(socket.assigns.search, socket.assigns.role_filter, branch_id)

    {:noreply, assign(socket, users: users, confirm_action: nil, confirm_user_id: nil)}
  end

  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, confirm_action: nil, confirm_user_id: nil)}
  end

  def handle_event("show_create_user", _params, socket) do
    {:noreply, assign(socket, show_create_user: true)}
  end

  def handle_event("hide_create_user", _params, socket) do
    {:noreply, assign(socket, show_create_user: false)}
  end

  def handle_event("create_user", params, socket) do
    role = String.to_existing_atom(params["role"] || "client")

    attrs = %{
      name: params["name"],
      phone_number: params["phone_number"],
      email: if(params["email"] != "", do: params["email"], else: nil),
      password: params["password"],
      password_confirmation: params["password"],
      role: role,
      branch_id: String.to_integer(params["branch_id"])
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        # Auto-confirm the user
        Accounts.confirm_user(user)

        # Create profile if client or trainer
        case role do
          :client ->
            Accounts.create_client_profile(user)

          :trainer ->
            Accounts.create_trainer_profile(user, %{
              bio: "Professional fitness trainer",
              specializations: ["General Fitness"]
            })

          _ ->
            :ok
        end

        branch_id = BranchSelectorComponent.effective_branch_id(socket.assigns.selected_branch_id)
        users = filter_users(socket.assigns.search, socket.assigns.role_filter, branch_id)

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> assign(users: users, show_create_user: false)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create user. Check the form and try again.")}
    end
  end

  defp filter_users("", "", nil), do: Accounts.list_users(branch_id: nil)

  defp filter_users("", "", branch_id), do: Accounts.list_users(branch_id: branch_id)

  defp filter_users("", role, branch_id),
    do: Accounts.list_users(role: String.to_existing_atom(role), branch_id: branch_id)

  defp filter_users(search, "", branch_id),
    do: Accounts.search_users(search, branch_id: branch_id)

  defp filter_users(search, role, branch_id),
    do: Accounts.search_users(search, role: String.to_existing_atom(role), branch_id: branch_id)

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(%{phone_number: phone}), do: phone

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
        <h1 class="text-3xl font-bold">Manage Users</h1>
        <div class="flex items-center gap-3 flex-wrap">
          <button phx-click="show_create_user" class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> Add User
          </button>
          <BranchSelectorComponent.branch_selector
            branches={@branches}
            selected_branch_id={@selected_branch_id}
          />
        </div>
      </div>

      <%!-- Search & Filter --%>
      <form phx-change="search" class="flex flex-col sm:flex-row gap-4 mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search by name, email, or phone..."
          class="input input-bordered flex-1"
          phx-debounce="300"
        />
        <select name="role" class="select select-bordered">
          <option value="">All Roles</option>
          <option value="client" selected={@role_filter == "client"}>Client</option>
          <option value="trainer" selected={@role_filter == "trainer"}>Trainer</option>
          <option value="admin" selected={@role_filter == "admin"}>Admin</option>
        </select>
      </form>

      <%!-- Create User modal --%>
      <div :if={@show_create_user} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Create New User</h3>
          <form phx-submit="create_user" class="space-y-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Name</span></label>
              <input
                type="text"
                name="name"
                class="input input-bordered"
                required
                placeholder="Full name"
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Phone Number</span></label>
              <input
                type="tel"
                name="phone_number"
                class="input input-bordered"
                required
                placeholder="+961..."
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Email (optional)</span></label>
              <input
                type="email"
                name="email"
                class="input input-bordered"
                placeholder="user@example.com"
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Role</span></label>
              <select name="role" class="select select-bordered" required>
                <option value="client">Client</option>
                <option value="trainer">Trainer</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Branch</span></label>
              <select name="branch_id" class="select select-bordered" required>
                <option value="">Select Branch</option>
                <%= for branch <- @branches do %>
                  <option value={branch.id}>{branch.name}</option>
                <% end %>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Password</span></label>
              <input
                type="password"
                name="password"
                class="input input-bordered"
                required
                minlength="8"
                placeholder="Min 8 characters"
              />
            </div>
            <div class="modal-action">
              <button type="button" phx-click="hide_create_user" class="btn">Cancel</button>
              <button type="submit" class="btn btn-primary">Create User</button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Confirm modal --%>
      <div :if={@confirm_action == :change_role} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Confirm Role Change</h3>
          <p class="py-4">
            Are you sure you want to change this user's role to <span class="font-semibold">{@confirm_role}</span>?
          </p>
          <div class="modal-action">
            <button phx-click="cancel_confirm" class="btn">Cancel</button>
            <button phx-click="confirm_role_change" class="btn btn-primary">Confirm</button>
          </div>
        </div>
      </div>

      <%!-- Users Table --%>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Role</th>
              <th>Branch</th>
              <th>Status</th>
              <th class="hidden sm:table-cell">Registered</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={user <- @users} class="hover">
              <td>
                <div class="font-medium">{display_name(user)}</div>
                <div :if={user.email} class="text-sm text-base-content/60">{user.email}</div>
              </td>
              <td>{user.phone_number}</td>
              <td>
                <span class={"badge #{role_badge_class(user.role)}"}>{user.role}</span>
              </td>
              <td>
                <span :if={user.branch_id} class="badge badge-outline badge-sm">
                  {branch_name(user.branch_id, @branches)}
                </span>
                <span :if={is_nil(user.branch_id)} class="text-base-content/40 text-sm">—</span>
              </td>
              <td>
                <span class={"badge #{if user.active, do: "badge-success", else: "badge-error"}"}>
                  {if user.active, do: "Active", else: "Inactive"}
                </span>
              </td>
              <td class="hidden sm:table-cell text-sm">
                {Calendar.strftime(user.inserted_at, "%Y-%m-%d")}
              </td>
              <td>
                <div class="flex gap-2">
                  <button
                    phx-click="toggle_active"
                    phx-value-id={user.id}
                    class={"btn btn-xs #{if user.active, do: "btn-warning", else: "btn-success"}"}
                  >
                    {if user.active, do: "Deactivate", else: "Activate"}
                  </button>
                  <div class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-xs btn-ghost">Role ▾</div>
                    <ul
                      tabindex="0"
                      class="dropdown-content z-[1] menu p-2 shadow bg-base-200 rounded-box w-32"
                    >
                      <li :for={role <- [:client, :trainer, :admin]}>
                        <button
                          :if={role != user.role}
                          phx-click="show_role_change"
                          phx-value-id={user.id}
                          phx-value-role={role}
                        >
                          {role}
                        </button>
                      </li>
                    </ul>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p :if={@users == []} class="text-base-content/60 text-center py-8">No users found.</p>
    </div>
    """
  end

  defp role_badge_class(:admin), do: "badge-accent"
  defp role_badge_class(:trainer), do: "badge-secondary"
  defp role_badge_class(:client), do: "badge-primary"
  defp role_badge_class(_), do: "badge-ghost"

  defp branch_name(branch_id, branches) do
    case Enum.find(branches, fn b -> b.id == branch_id end) do
      nil -> "Unknown"
      branch -> branch.name
    end
  end
end
