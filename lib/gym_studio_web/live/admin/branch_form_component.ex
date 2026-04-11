defmodule GymStudioWeb.Admin.BranchFormComponent do
  @moduledoc """
  LiveComponent for creating and editing gym branches.

  Handles form validation and submission for both :new and :edit actions.
  """
  use GymStudioWeb, :live_component

  import Phoenix.Component
  alias GymStudio.Branches

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-4 mb-8">
        <.link navigate={~p"/admin/branches"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.link>
        <h1 class="text-3xl font-bold">
          {if @action == :new, do: "New Branch", else: "Edit Branch"}
        </h1>
      </div>

      <.form
        for={@form}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="max-w-lg space-y-4"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Name"
          placeholder="e.g. React — Sin El Fil"
          required
        />

        <.input
          :if={@action == :new}
          field={@form[:slug]}
          type="text"
          label="Slug"
          placeholder="e.g. sin-el-fil"
          required
        />

        <.input field={@form[:address]} type="text" label="Address" placeholder="Branch address" />

        <.input
          field={@form[:capacity]}
          type="number"
          label="Capacity"
          placeholder="Max concurrent clients"
          required
          min="1"
        />

        <.input
          field={@form[:phone]}
          type="text"
          label="Phone"
          placeholder="+961 1 234 567"
        />

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:latitude]}
            type="number"
            label="Latitude"
            step="0.0001"
            placeholder="33.8713"
          />
          <.input
            field={@form[:longitude]}
            type="number"
            label="Longitude"
            step="0.0001"
            placeholder="35.5297"
          />
        </div>

        <div class="fieldset">
          <label class="label"><span class="label-text">Operating Hours</span></label>
          <p class="text-sm text-base-content/60 mb-2">Leave blank for days the branch is closed.</p>
          <div class="space-y-2">
            <div :for={day <- ~w(mon tue wed thu fri sat sun)} class="flex items-center gap-3">
              <span class="w-20 text-sm text-base-content/60">{day_label(day)}</span>
              <input
                type="text"
                name={"branch[operating_hours][#{day}]"}
                value={operating_hour_value(@form, day)}
                placeholder="e.g. 06:00-22:00"
                class="input input-bordered input-sm flex-1"
              />
            </div>
          </div>
        </div>

        <.input field={@form[:active]} type="checkbox" label="Active" />

        <div class="flex gap-4 pt-4">
          <button type="submit" class="btn btn-primary">
            {if @action == :new, do: "Create Branch", else: "Save Changes"}
          </button>
          <.link navigate={~p"/admin/branches"} class="btn btn-ghost">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset =
      case assigns.action do
        :new -> Branches.change_branch(%GymStudio.Branches.Branch{})
        :edit -> Branches.change_branch(assigns.branch)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"branch" => branch_params}, socket) do
    branch_params = process_operating_hours(branch_params)

    changeset =
      case socket.assigns.action do
        :new -> Branches.change_branch(%GymStudio.Branches.Branch{}, branch_params)
        :edit -> Branches.change_branch(socket.assigns.branch, branch_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"branch" => branch_params}, socket) do
    branch_params = process_operating_hours(branch_params)

    case socket.assigns.action do
      :new ->
        case Branches.create_branch(branch_params) do
          {:ok, _branch} ->
            {:noreply,
             socket
             |> put_flash(:info, "Branch created successfully")
             |> push_navigate(to: ~p"/admin/branches")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      :edit ->
        case Branches.update_branch(socket.assigns.branch, branch_params) do
          {:ok, _branch} ->
            {:noreply,
             socket
             |> put_flash(:info, "Branch updated successfully")
             |> push_navigate(to: ~p"/admin/branches")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  defp process_operating_hours(params) do
    {hours, rest} = Map.pop(params, "operating_hours", %{})

    hours =
      hours
      |> Enum.filter(fn {_day, val} -> val != "" end)
      |> Map.new()

    Map.put(rest, "operating_hours", hours)
  end

  defp operating_hour_value(form, day) do
    case Phoenix.HTML.Form.input_value(form, :operating_hours) do
      nil -> ""
      hours when is_map(hours) -> Map.get(hours, day, "")
      _ -> ""
    end
  end

  defp day_label("mon"), do: "Monday"
  defp day_label("tue"), do: "Tuesday"
  defp day_label("wed"), do: "Wednesday"
  defp day_label("thu"), do: "Thursday"
  defp day_label("fri"), do: "Friday"
  defp day_label("sat"), do: "Saturday"
  defp day_label("sun"), do: "Sunday"
  defp day_label(other), do: other
end
