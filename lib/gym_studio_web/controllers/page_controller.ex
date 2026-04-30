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
      whatsapp_url:
        "https://wa.me/96170379764?text=Hi%2C%20I%27m%20interested%20in%20training%20at%20React%20Gym",
      directions_url:
        "https://www.google.com/maps/search/?api=1&query=React+Gym+Clover+Park+Horsh+Tabet"
    },
    %{
      name: "Jal El Dib",
      address: "Main Street",
      phone: "+961 71 633 970",
      whatsapp_url:
        "https://wa.me/96171633970?text=Hi%2C%20I%27m%20interested%20in%20training%20at%20React%20Gym",
      directions_url:
        "https://www.google.com/maps/search/?api=1&query=React+Gym+Jal+El+Dib+Main+Street"
    }
  ]

  @static_testimonials [
    %{
      author: "Arline Atamian",
      text:
        "The best staff ever highly recommended. As a 60 year old person i feel my body is improving and if you are my age or even over it is never too late to start again!"
    },
    %{
      author: "Joseph Rehayem",
      text:
        "If you're looking for a gym with an amazing atmosphere, a team of friendly and supportive staff, and highly skilled trainers, then this is the perfect spot to achieve your fitness goals."
    },
    %{
      author: "Christelle Fawaz",
      text:
        "Friendliest staff, most caring and professional. As a pregnant woman i feel safe training with them."
    },
    %{
      author: "Youssef Khouzami",
      text: "A very friendly place with professional trainers…love it."
    },
    %{
      author: "Nader Abou Nader",
      text: "Amazing place with professional trainers!!"
    }
  ]

  def home(conn, _params) do
    render(conn, :home, branches: @static_branches, testimonials: @static_testimonials)
  end
end
