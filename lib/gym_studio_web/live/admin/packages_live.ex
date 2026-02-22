defmodule GymStudioWeb.Admin.PackagesLive do
  use GymStudioWeb, :live_view
  alias GymStudio.{Packages, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    packages = Packages.list_all_packages()
    clients = Accounts.list_users(role: :client)
    package_types = Packages.package_types()

    {:ok,
     assign(socket,
       page_title: "Manage Packages",
       packages: packages,
       clients: clients,
       package_types: package_types
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    assign(socket, page_title: "Assign New Package")
  end

  defp apply_action(socket, _action) do
    assign(socket, page_title: "Manage Packages")
  end

  @impl true
  def handle_event("create_package", params, socket) do
    attrs = %{
      client_id: params["client_id"],
      package_type: params["package_type"],
      assigned_by_id: socket.assigns.current_scope.user.id,
      expires_at: parse_expires_at(params["expires_at"])
    }

    case Packages.assign_package(attrs) do
      {:ok, _package} ->
        {:noreply,
         socket
         |> put_flash(:info, "Package assigned successfully")
         |> push_navigate(to: ~p"/admin/packages")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign package")}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    package = Packages.get_package!(id)
    {:ok, _} = Packages.deactivate_package(package)
    {:noreply, assign(socket, packages: Packages.list_all_packages())}
  end

  defp parse_expires_at(nil), do: nil
  defp parse_expires_at(""), do: nil

  defp parse_expires_at(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <%= if @live_action == :new do %>
        <h1 class="text-3xl font-bold mb-8">Assign New Package</h1>
        <form phx-submit="create_package" class="max-w-md space-y-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Client</span></label>
            <select name="client_id" class="select select-bordered" required>
              <option value="">Select Client</option>
              <%= for client <- @clients do %>
                <option value={client.id}>
                  {client.name || client.email || client.phone_number}
                </option>
              <% end %>
            </select>
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">Package Type</span></label>
            <select name="package_type" class="select select-bordered" required>
              <%= for {type, sessions} <- @package_types do %>
                <option value={type}>
                  {type |> String.replace("_", " ") |> String.capitalize()} ({sessions} sessions)
                </option>
              <% end %>
            </select>
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">Expires At (optional)</span></label>
            <input type="date" name="expires_at" class="input input-bordered" />
          </div>
          <div class="flex gap-4">
            <button type="submit" class="btn btn-primary">Assign Package</button>
            <.link navigate={~p"/admin/packages"} class="btn btn-ghost">Cancel</.link>
          </div>
        </form>
      <% else %>
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Manage Packages</h1>
          <.link navigate={~p"/admin/packages/new"} class="btn btn-primary">Assign Package</.link>
        </div>
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Client</th>
                <th>Type</th>
                <th>Usage</th>
                <th>Expires</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={package <- @packages} class="hover">
                <td>{package.client.name || package.client.email || package.client.phone_number}</td>
                <td>
                  <span class="badge badge-outline">{format_package_type(package.package_type)}</span>
                </td>
                <td>
                  <div class="flex items-center gap-2">
                    <progress
                      class={"progress w-24 #{usage_color(package)}"}
                      value={package.used_sessions}
                      max={package.total_sessions}
                    >
                    </progress>
                    <span class="text-sm">
                      {package.remaining_sessions}/{package.total_sessions}
                    </span>
                  </div>
                </td>
                <td class="text-sm">
                  <%= if package.expires_at do %>
                    {Calendar.strftime(package.expires_at, "%Y-%m-%d")}
                  <% else %>
                    <span class="text-base-content/40">Never</span>
                  <% end %>
                </td>
                <td>
                  <span class={"badge #{if package.active, do: "badge-success", else: "badge-ghost"}"}>
                    {if package.active, do: "Active", else: "Inactive"}
                  </span>
                </td>
                <td>
                  <button
                    :if={package.active}
                    phx-click="deactivate"
                    phx-value-id={package.id}
                    class="btn btn-xs btn-warning"
                  >
                    Deactivate
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p :if={@packages == []} class="text-base-content/60 text-center py-8">No packages found.</p>
      <% end %>
    </div>
    """
  end

  defp usage_color(package) do
    pct = package.used_sessions / max(package.total_sessions, 1) * 100

    cond do
      pct >= 90 -> "progress-error"
      pct >= 60 -> "progress-warning"
      true -> "progress-success"
    end
  end

  defp format_package_type("standard_8"), do: "Starter (8 Sessions)"
  defp format_package_type("standard_12"), do: "Standard (12 Sessions)"
  defp format_package_type("premium_20"), do: "Premium (20 Sessions)"
  defp format_package_type(type), do: type
end
