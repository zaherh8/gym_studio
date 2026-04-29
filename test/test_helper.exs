# [LANDING-PAGE] Skip auth tests while registration is hidden - see #92
ExUnit.start(exclude: [:landing_page_auth])
Ecto.Adapters.SQL.Sandbox.mode(GymStudio.Repo, :manual)
