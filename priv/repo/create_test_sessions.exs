# Create test sessions for trainers to see schedule cards
# Run: mix run priv/repo/create_test_sessions.exs

import Ecto.Query
alias GymStudio.Repo
alias GymStudio.Scheduling.TrainingSession

# IDs from database
john_id = "591d2378-c31a-438d-8ffa-45576ac80e12"   # John Smith (trainer)
sarah_id = "e3bf5d4f-ce47-4ed8-91eb-e7e63fd9aac8"  # Sarah Johnson (trainer)
mike_id = "ebb77ef6-f2ec-4a1d-9aeb-6db622be413e"    # Mike Davis (trainer)

alice_id = "fb235299-7cfb-4a63-8c02-fc42362175ff"   # Alice Cooper (client)
bob_id = "39bd2c3a-b7b7-48dc-9627-3e29c49d9ce9"     # Bob Martinez (client)
carol_id = "50d3498f-7f34-40d1-9acd-4a1deca8e161"   # Carol Williams (client)

alice_pkg = "26c32ae4-87c2-4fd5-9be9-9bbcb13ba49e"  # Alice package (8 remaining)
bob_pkg = "6ff80448-9281-4c62-b8e7-ab1cfa755bfe"    # Bob package (17 remaining)
carol_pkg = "95360eee-cedb-4427-a910-30a73eb62daf"   # Carol package (12 remaining)

branch_id = 1

# Helper to create datetime for a specific date and hour (UTC, assuming local is GMT+3)
defmodule SessionCreator do
  def dt(day_offset, hour_local, minute \\ 0) do
    # Convert local GMT+3 to UTC by subtracting 3 hours
    utc_hour = hour_local - 3
    date = Date.utc_today() |> Date.add(day_offset)
    {:ok, midnight} = NaiveDateTime.new(date, ~T[00:00:00])
    ndt = NaiveDateTime.add(midnight, utc_hour * 3600 + minute * 60)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  def insert!(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %TrainingSession{}
    |> Ecto.Changeset.change(Map.merge(%{inserted_at: now, updated_at: now}, attrs))
    |> Repo.insert!()
  end
end

# Clear existing sessions (except completed ones to keep history)
Repo.delete_all(from s in TrainingSession, where: s.status != "completed")

IO.puts("Creating test sessions...")

# === JOHN SMITH'S SCHEDULE ===

# Today (Sunday)
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(0, 10, 0),   # 10:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: john_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(0, 12, 0),    # 12:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: john_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(0, 17, 0),    # 5:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.add(-2, :hour) |> DateTime.truncate(:second)
})

# Tomorrow (Monday)
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(1, 9, 0),     # 9:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: john_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(1, 11, 0),    # 11:00 AM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(1, 16, 0),    # 4:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Tuesday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: john_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(2, 10, 0),    # 10:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Wednesday
SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: john_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(3, 9, 0),     # 9:00 AM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(3, 14, 0),    # 2:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Thursday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: john_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(4, 11, 0),    # 11:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Friday
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(5, 10, 0),    # 10:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: john_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(5, 15, 0),    # 3:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

# Saturday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: john_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(6, 9, 0),     # 9:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: john_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(6, 11, 0),    # 11:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: john_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})


# === SARAH JOHNSON'S SCHEDULE ===

# Today (Sunday)
SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: sarah_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(0, 9, 0),     # 9:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.add(-3, :hour) |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: sarah_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(0, 14, 0),    # 2:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

# Tomorrow (Monday)
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: sarah_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(1, 10, 0),    # 10:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: sarah_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(1, 15, 0),    # 3:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Wednesday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: sarah_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(3, 11, 0),    # 11:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: sarah_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(3, 16, 0),    # 4:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

# Thursday
SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: sarah_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(4, 9, 0),     # 9:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Friday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: sarah_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(5, 14, 0),    # 2:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Saturday
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: sarah_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(6, 10, 0),    # 10:00 AM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: sarah_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: sarah_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(6, 12, 0),    # 12:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})


# === MIKE DAVIS (fewer sessions — new trainer) ===

# Today
SessionCreator.insert!(%{
  client_id: alice_id,
  trainer_id: mike_id,
  package_id: alice_pkg,
  scheduled_at: SessionCreator.dt(0, 16, 0),    # 4:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

# Tuesday
SessionCreator.insert!(%{
  client_id: carol_id,
  trainer_id: mike_id,
  package_id: carol_pkg,
  scheduled_at: SessionCreator.dt(2, 15, 0),    # 3:00 PM
  duration_minutes: 60,
  status: "confirmed",
  branch_id: branch_id,
  approved_by_id: mike_id,
  approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
})

# Thursday
SessionCreator.insert!(%{
  client_id: bob_id,
  trainer_id: mike_id,
  package_id: bob_pkg,
  scheduled_at: SessionCreator.dt(4, 14, 0),    # 2:00 PM
  duration_minutes: 60,
  status: "pending",
  branch_id: branch_id
})

IO.puts("✅ Created ~30 test sessions across 3 trainers (John, Sarah, Mike)")
IO.puts("   Statuses: confirmed + pending")
IO.puts("   Spread: today through next Saturday")
