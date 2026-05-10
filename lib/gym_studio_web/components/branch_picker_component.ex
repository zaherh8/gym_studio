defmodule GymStudioWeb.BranchPickerComponent do
  @moduledoc """
  Reusable WhatsApp branch picker modal.

  Renders a `<dialog>` with branch cards that link to WhatsApp.
  Uses DaisyUI semantic color classes for proper dark mode support.
  """
  use Phoenix.Component

  alias GymStudioWeb.Layouts

  @doc """
  Renders a WhatsApp branch picker modal.

  ## Assigns

    * `branches` - list of maps with `:name`, `:whatsapp_url`, and optionally
      `:phone` and `:address`. Displays `phone` if present, otherwise `address`.
  """
  attr :branches, :list, required: true
  attr :id, :string, default: "whatsapp-modal"

  def branch_picker_modal(assigns) do
    ~H"""
    <dialog id={@id} class="modal modal-bottom sm:modal-middle" aria-labelledby={"#{@id}-title"}>
      <div class="modal-box">
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
        </form>
        <h3 id={"#{@id}-title"} class="text-lg font-bold mb-1">Choose a Branch</h3>
        <p class="text-sm text-base-content/60 mb-5">Select which studio to contact on WhatsApp</p>
        <div class="grid gap-4">
          <a
            :for={branch <- @branches}
            href={branch.whatsapp_url}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-4 p-4 rounded-xl border border-base-300 hover:border-primary/40 hover:shadow-md transition-all group"
          >
            <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:bg-primary/20 transition-colors">
              <Layouts.whatsapp_icon class="w-6 h-6 text-primary" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-semibold text-base-content">{branch.name}</p>
              <p class="text-sm text-base-content/60 truncate">
                {branch[:phone] || branch[:address]}
              </p>
            </div>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-base-content/40 group-hover:text-primary transition-colors flex-shrink-0"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            </svg>
          </a>
          <p :if={Enum.empty?(@branches)} class="text-center text-base-content/60 py-4">
            No branches available
          </p>
        </div>
      </div>
      <form id={"#{@id}-backdrop"} method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end
end
