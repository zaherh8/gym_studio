defmodule GymStudio.RateLimiter do
  @moduledoc """
  ETS-based rate limiter for OTP requests.

  Tracks requests by key (IP address or phone number) with configurable
  limits and time windows. Periodically cleans up expired entries.
  """
  use GenServer

  @table :rate_limiter
  @cleanup_interval :timer.minutes(10)

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check and increment the rate limit for a given key.

  Returns `:ok` if under limit, `{:error, :rate_limited}` if over.

  ## Options
    * `:limit` - max number of requests allowed (required)
    * `:window_ms` - time window in milliseconds (required)
  """
  def check_rate(key, opts) do
    limit = Keyword.fetch!(opts, :limit)
    window_ms = Keyword.fetch!(opts, :window_ms)
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    # Get existing entries, filter expired
    entries =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] -> Enum.filter(timestamps, &(&1 > cutoff))
        [] -> []
      end

    if length(entries) >= limit do
      {:error, :rate_limited}
    else
      :ets.insert(@table, {key, [now | entries]})
      :ok
    end
  end

  @doc """
  Check rate limit for an IP address on OTP requests.
  Max 10 per hour.
  """
  def check_ip_rate("unknown"), do: :ok

  def check_ip_rate(ip_string) do
    if enabled?() do
      check_rate({:ip, ip_string}, limit: 10, window_ms: :timer.hours(1))
    else
      :ok
    end
  end

  @doc """
  Check daily rate limit for a phone number on OTP requests.
  Max 5 per 24 hours.
  """
  def check_phone_daily_rate(phone_number) do
    if enabled?() do
      check_rate({:phone_daily, phone_number}, limit: 5, window_ms: :timer.hours(24))
    else
      :ok
    end
  end

  defp enabled? do
    Application.get_env(:gym_studio, :rate_limiter_enabled, true)
  end

  @doc """
  Reset rate limit for a key. Useful for testing.
  """
  def reset(key) do
    :ets.delete(@table, key)
    :ok
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    # Remove entries older than 24 hours (the max window we use)
    now = System.monotonic_time(:millisecond)
    cutoff = now - :timer.hours(24)

    :ets.foldl(
      fn {key, timestamps}, _acc ->
        filtered = Enum.filter(timestamps, &(&1 > cutoff))

        if filtered == [] do
          :ets.delete(@table, key)
        else
          :ets.insert(@table, {key, filtered})
        end

        :ok
      end,
      :ok,
      @table
    )
  end
end
