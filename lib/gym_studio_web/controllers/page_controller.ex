defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  alias GymStudio.Accounts
  alias GymStudio.Branches

  def home(conn, _params) do
    trainers =
      Accounts.list_approved_trainers()
      |> GymStudio.Repo.preload(user: [:branch])

    branches = Branches.list_branches(active: true)
    render(conn, :home, trainers: trainers, branches: branches)
  end
end
