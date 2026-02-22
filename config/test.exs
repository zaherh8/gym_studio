import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :gym_studio, GymStudio.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "gym_studio_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gym_studio, GymStudioWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "iveubam4j6O3bvSXihxW6BfWwiUSqTvyy3KlR4JEEFoJkcFu+9lwj5ei+WcoK8qV",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Disable Swoosh API client in tests
config :swoosh, :api_client, false

# Configure Oban for testing (inline mode)
config :gym_studio, Oban, testing: :inline

# Disable rate limiter in tests to avoid cross-test interference
config :gym_studio, :rate_limiter_enabled, false
