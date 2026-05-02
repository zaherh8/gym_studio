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
    plug GymStudioWeb.Plugs.EnsureCanonicalHost
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # TODO(#92): Remove this pipeline when registration/login should be public again
  pipeline :landing_page_redirect do
    plug :redirect_to_home
  end

  # Public pages - accessible to everyone
  scope "/", GymStudioWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/offline", OfflineController, :index

    live_session :public, on_mount: {GymStudioWeb.UserAuth, :mount_current_scope} do
      # [LANDING-PAGE] Hidden for landing page release - see #92
      # live "/trainers", TrainersLive, :index
      live "/gallery", GalleryLive, :index
      live "/contact", ContactLive, :index
    end
  end

  # [LANDING-PAGE] All portal and auth routes below are hidden from the UI for
  # the landing page release (see #92). The route definitions are kept so that
  # ~p sigils in existing modules compile without warnings. The navbar, landing
  # page CTAs, and mobile nav no longer link to any of these routes.

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
      live "/progress", ProgressLive, :index
      live "/progress/exercises/:exercise_id", ExerciseDetailLive, :show
      live "/progress/metrics", BodyMetricsLive, :index
      live "/progress/goals", GoalsLive, :index
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
      live "/exercises", ExercisesLive, :index
      live "/sessions/:id/log", SessionLogLive, :index
      live "/sessions/:id/exercises", SessionLogLive, :index
      live "/clients", ClientListLive, :index
      live "/clients/:client_id/progress", ClientProgressLive, :index
      live "/clients/:client_id/progress/metrics", ClientMetricsLive, :index
      live "/clients/:client_id/progress/goals", ClientGoalsLive, :index
      live "/availability", AvailabilityLive, :index
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
      live "/calendar", CalendarLive, :index
      live "/exercises", ExercisesLive, :index
      live "/availability", AvailabilityLive, :index
      live "/branches", BranchesLive, :index
      live "/branches/new", BranchesLive, :new
      live "/branches/:id", BranchesLive, :show
      live "/branches/:id/edit", BranchesLive, :edit
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
  # [LANDING-PAGE] Auth routes redirect to / for landing page release - see #92
  # Routes are kept so ~p sigils compile, but ALL visitors are redirected to /
  # until we're ready to launch registration. Log-out remains accessible.

  scope "/", GymStudioWeb do
    pipe_through [:browser, :landing_page_redirect]

    live_session :registration,
      on_mount: [{GymStudioWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", RegistrationLive, :index
      live "/users/forgot-password", ForgotPasswordLive, :index
    end

    get "/users/log-in", UserSessionController, :new
    post "/users/log-in", UserSessionController, :create
  end

  scope "/", GymStudioWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GymStudioWeb do
    pipe_through [:browser]

    delete "/users/log-out", UserSessionController, :delete
  end

  # TODO(#92): Remove this plug when registration/login should be public again
  defp redirect_to_home(conn, _opts) do
    conn
    |> Phoenix.Controller.redirect(to: "/")
    |> Plug.Conn.halt()
  end
end
