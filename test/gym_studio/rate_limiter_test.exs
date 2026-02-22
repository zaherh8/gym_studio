defmodule GymStudio.RateLimiterTest do
  use ExUnit.Case, async: false

  alias GymStudio.RateLimiter

  setup do
    # Enable rate limiter for these tests
    Application.put_env(:gym_studio, :rate_limiter_enabled, true)

    # Clean up any existing state for our test keys
    RateLimiter.reset({:ip, "192.168.1.1"})
    RateLimiter.reset({:ip, "192.168.1.2"})
    RateLimiter.reset({:phone_daily, "+9611234567"})
    RateLimiter.reset({:phone_daily, "+9611234568"})

    on_exit(fn ->
      Application.put_env(:gym_studio, :rate_limiter_enabled, false)
    end)

    :ok
  end

  describe "check_ip_rate/1" do
    test "allows requests under the limit" do
      for _ <- 1..10 do
        assert :ok = RateLimiter.check_ip_rate("192.168.1.1")
      end
    end

    test "blocks requests over the limit" do
      for _ <- 1..10 do
        assert :ok = RateLimiter.check_ip_rate("192.168.1.1")
      end

      assert {:error, :rate_limited} = RateLimiter.check_ip_rate("192.168.1.1")
    end

    test "different IPs have separate limits" do
      for _ <- 1..10 do
        RateLimiter.check_ip_rate("192.168.1.1")
      end

      assert {:error, :rate_limited} = RateLimiter.check_ip_rate("192.168.1.1")
      assert :ok = RateLimiter.check_ip_rate("192.168.1.2")
    end
  end

  describe "check_phone_daily_rate/1" do
    test "allows requests under the limit" do
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_phone_daily_rate("+9611234567")
      end
    end

    test "blocks requests over the daily limit" do
      for _ <- 1..5 do
        assert :ok = RateLimiter.check_phone_daily_rate("+9611234567")
      end

      assert {:error, :rate_limited} = RateLimiter.check_phone_daily_rate("+9611234567")
    end

    test "different phones have separate limits" do
      for _ <- 1..5 do
        RateLimiter.check_phone_daily_rate("+9611234567")
      end

      assert {:error, :rate_limited} = RateLimiter.check_phone_daily_rate("+9611234567")
      assert :ok = RateLimiter.check_phone_daily_rate("+9611234568")
    end
  end

  describe "check_rate/2" do
    test "respects custom limits" do
      key = {:test, "custom"}
      RateLimiter.reset(key)

      for _ <- 1..3 do
        assert :ok = RateLimiter.check_rate(key, limit: 3, window_ms: 60_000)
      end

      assert {:error, :rate_limited} = RateLimiter.check_rate(key, limit: 3, window_ms: 60_000)
    end

    test "expired entries are not counted" do
      key = {:test, "expiry"}
      RateLimiter.reset(key)

      # Use a very short window
      assert :ok = RateLimiter.check_rate(key, limit: 1, window_ms: 1)

      # Wait for expiry
      Process.sleep(5)

      assert :ok = RateLimiter.check_rate(key, limit: 1, window_ms: 1)
    end
  end

  describe "reset/1" do
    test "clears rate limit for a key" do
      for _ <- 1..10 do
        RateLimiter.check_ip_rate("192.168.1.1")
      end

      assert {:error, :rate_limited} = RateLimiter.check_ip_rate("192.168.1.1")

      RateLimiter.reset({:ip, "192.168.1.1"})

      assert :ok = RateLimiter.check_ip_rate("192.168.1.1")
    end
  end
end
