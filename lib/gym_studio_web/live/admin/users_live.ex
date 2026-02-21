defmodule GymStudioWeb.Admin.UsersLive do
  use GymStudioWeb, :live_view

  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Manage Users",
       users: Accounts.list_users(),
       search: "",
       role_filter: "",
       confirm_action: nil,
       confirm_user_id: nil
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
  def handle_event("search", %{"search" => search, "role" => role}, socket) do
    users = filter_users(search, role)
    {:noreply, assign(socket, users: users, search: search, role_filter: role)}
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    if user.active do
      {:ok, _} = Accounts.deactivate_user(user)
    else
      {:ok, _} = Accounts.activate_user(user)
    end

    users = filter_users(socket.assigns.search, socket.assigns.role_filter)
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

    users = filter_users(socket.assigns.search, socket.assigns.role_filter)
    {:noreply, assign(socket, users: users, confirm_action: nil, confirm_user_id: nil)}
  end

  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, confirm_action: nil, confirm_user_id: nil)}
  end

  defp filter_users("", ""), do: Accounts.list_users()
  defp filter_users("", role), do: Accounts.list_users(role: String.to_existing_atom(role))
  defp filter_users(search, ""), do: Accounts.search_users(search)

  defp filter_users(search, role),
    do: Accounts.search_users(search, role: String.to_existing_atom(role))

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(%{phone_number: phone}), do: phone

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Manage Users</h1>

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
              <th>Status</th>
              <th>Registered</th>
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
                <span class={"badge #{if user.active, do: "badge-success", else: "badge-error"}"}>
                  {if user.active, do: "Active", else: "Inactive"}
                </span>
              </td>
              <td class="text-sm">{Calendar.strftime(user.inserted_at, "%Y-%m-%d")}</td>
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
end
