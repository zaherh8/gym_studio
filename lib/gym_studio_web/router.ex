defmodule GymStudioWeb.Router do
  use GymStudioWeb, :router

  import GymStudioWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GymStudioWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public pages - accessible to everyone
  scope "/", GymStudioWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :public, on_mount: {GymStudioWeb.UserAuth, :mount_current_scope} do
      live "/trainers", TrainersLive, :index
      live "/gallery", GalleryLive, :index
      live "/contact", ContactLive, :index
    end
  end

  # Client portal - requires authenticated client
  scope "/client", GymStudioWeb.Client, as: :client do
    pipe_through [:browser, :require_authenticated_user, :require_active_user, :require_client]

    live_session :client_portal, on_mount: {GymStudioWeb.UserAuth, :ensure_authenticated} do
      live "/", DashboardLive, :index
      live "/book", BookSessionLive, :index
      live "/sessions", SessionsLive, :index
      live "/sessions/:id", SessionsLive, :show
      live "/packages", PackagesLive, :index
      live "/profile", ProfileLive, :index
      live "/notifications", NotificationsLive, :index
    end
  end

  # Trainer portal - requires authenticated trainer
  scope "/trainer", GymStudioWeb.Trainer, as: :trainer do
    pipe_through [:browser, :require_authenticated_user, :require_active_user, :require_trainer]

    live_session :trainer_portal, on_mount: {GymStudioWeb.UserAuth, :ensure_authenticated} do
      live "/", DashboardLive, :index
      live "/sessions", SessionsLive, :index
      live "/sessions/:id", SessionsLive, :show
      live "/schedule", ScheduleLive, :index
      live "/profile", ProfileLive, :index
    end
  end

  # Admin dashboard - requires authenticated admin
  scope "/admin", GymStudioWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user, :require_active_user, :require_admin]

    live_session :admin_portal, on_mount: {GymStudioWeb.UserAuth, :ensure_authenticated} do
      live "/", DashboardLive, :index
      live "/users", UsersLive, :index
      live "/users/:id", UsersLive, :show
      live "/trainers", TrainersLive, :index
      live "/trainers/:id", TrainersLive, :show
      live "/clients", ClientsLive, :index
      live "/clients/:id", ClientsLive, :show
      live "/packages", PackagesLive, :index
      live "/packages/new", PackagesLive, :new
      live "/sessions", SessionsLive, :index
      live "/sessions/:id", SessionsLive, :show
      live "/gallery", GalleryLive, :index
      live "/analytics", AnalyticsLive, :index
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:gym_studio, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GymStudioWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GymStudioWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :registration,
      on_mount: [{GymStudioWeb.UserAuth, :redirect_if_authenticated}] do
      live "/users/register", RegistrationLive, :index
    end
  end

  scope "/", GymStudioWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GymStudioWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/log-in", UserSessionController, :new
    post "/users/log-in", UserSessionController, :create
  end

  scope "/", GymStudioWeb do
    pipe_through [:browser]

    delete "/users/log-out", UserSessionController, :delete
  end
end
