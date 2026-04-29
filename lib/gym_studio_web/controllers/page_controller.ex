defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  # [LANDING-PAGE] Hidden for landing page release - see #92
  # alias GymStudio.Accounts
  alias GymStudio.Branches

  def home(conn, _params) do
    # [LANDING-PAGE] Hidden for landing page release - see #92
    # trainers =
    #   Accounts.list_approved_trainers()
    #   |> GymStudio.Repo.preload(user: [:branch])

    branches = Branches.list_branches(active: true)
    render(conn, :home, branches: branches)
  end
end
