defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  # [LANDING-PAGE] Static branch data for landing page release - see #92
  # When re-enabling full features, replace @static_branches with DB lookup:
  #   alias GymStudio.Accounts
  #   alias GymStudio.Branches
  #   trainers = Accounts.list_approved_trainers() |> GymStudio.Repo.preload(user: [:branch])
  #   branches = Branches.list_branches(active: true)
  #   render(conn, :home, branches: branches, trainers: trainers)
  @static_branches [
    %{
      name: "Horsh Tabet",
      address: "Clover Park, 4th floor",
      phone: "+961 70 379 764",
      whatsapp_url: "https://wa.me/96170379764",
      directions_url:
        "https://www.google.com/maps/search/?api=1&query=React+Gym+Clover+Park+Horsh+Tabet"
    },
    %{
      name: "Jal El Dib",
      address: "Main Street",
      phone: "+961 71 633 970",
      whatsapp_url: "https://wa.me/96171633970",
      directions_url:
        "https://www.google.com/maps/search/?api=1&query=React+Gym+Jal+El+Dib+Main+Street"
    }
  ]

  def home(conn, _params) do
    render(conn, :home, branches: @static_branches)
  end
end
