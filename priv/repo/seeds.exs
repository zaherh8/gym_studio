# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     GymStudio.Repo.insert!(%GymStudio.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias GymStudio.Repo
alias GymStudio.Accounts
alias GymStudio.Accounts.{User, Trainer, Client}
alias GymStudio.Packages
alias GymStudio.Packages.SessionPackage
alias GymStudio.Scheduling
alias GymStudio.Scheduling.TrainingSession

IO.puts("Seeding database...")

# Helper function to create user with password
defmodule SeedHelpers do
  def create_user!(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> User.confirm_changeset()
    |> Repo.insert!()
  end
end

# =============================================================================
# ADMIN USER
# =============================================================================
IO.puts("Creating admin user...")

admin =
  SeedHelpers.create_user!(%{
    name: "Admin",
    phone_number: "+96170000001",
    email: "admin@reactgym.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :admin
  })

IO.puts("  Admin created: #{admin.phone_number}")

# =============================================================================
# TRAINERS
# =============================================================================
IO.puts("Creating trainers...")

trainer1_user =
  SeedHelpers.create_user!(%{
    name: "John Smith",
    phone_number: "+96170000002",
    email: "john.trainer@reactgym.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :trainer
  })

trainer1 =
  %Trainer{}
  |> Trainer.changeset(%{
    user_id: trainer1_user.id,
    bio: "Certified personal trainer with 10+ years of experience in strength training and HIIT.",
    specializations: ["Strength Training", "HIIT", "Weight Loss"],
    photo_url:
      "https://us-central-1.telnyxcloudstorage.com/react-gym-studio-cdn/images/trainer1.jpg"
  })
  |> Trainer.approval_changeset(admin)
  |> Repo.insert!()

IO.puts("  Trainer 1 created: #{trainer1_user.phone_number} (John - Approved)")

trainer2_user =
  SeedHelpers.create_user!(%{
    name: "Sarah Johnson",
    phone_number: "+96170000003",
    email: "sarah.trainer@reactgym.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :trainer
  })

trainer2 =
  %Trainer{}
  |> Trainer.changeset(%{
    user_id: trainer2_user.id,
    bio: "Yoga instructor and wellness coach specializing in flexibility and mindfulness.",
    specializations: ["Yoga", "Pilates", "Flexibility"],
    photo_url:
      "https://us-central-1.telnyxcloudstorage.com/react-gym-studio-cdn/images/trainer2.jpg"
  })
  |> Trainer.approval_changeset(admin)
  |> Repo.insert!()

IO.puts("  Trainer 2 created: #{trainer2_user.phone_number} (Sarah - Approved)")

trainer3_user =
  SeedHelpers.create_user!(%{
    name: "Mike Davis",
    phone_number: "+96170000004",
    email: "mike.trainer@reactgym.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :trainer
  })

trainer3 =
  %Trainer{}
  |> Trainer.changeset(%{
    user_id: trainer3_user.id,
    bio: "Sports performance specialist focusing on athletic conditioning.",
    specializations: ["Sports Performance", "Conditioning", "Rehabilitation"]
  })
  |> Repo.insert!()

IO.puts("  Trainer 3 created: #{trainer3_user.phone_number} (Mike - Pending Approval)")

# =============================================================================
# CLIENTS
# =============================================================================
IO.puts("Creating clients...")

client1_user =
  SeedHelpers.create_user!(%{
    name: "Alice Cooper",
    phone_number: "+96171000001",
    email: "alice@example.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :client
  })

client1 =
  %Client{}
  |> Client.changeset(%{
    user_id: client1_user.id,
    emergency_contact: "+96171000011",
    health_notes: "No known allergies. Mild knee discomfort from old sports injury.",
    goals: "Build muscle and improve overall fitness"
  })
  |> Repo.insert!()

IO.puts("  Client 1 created: #{client1_user.phone_number} (Alice)")

client2_user =
  SeedHelpers.create_user!(%{
    name: "Bob Martinez",
    phone_number: "+96171000002",
    email: "bob@example.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :client
  })

client2 =
  %Client{}
  |> Client.changeset(%{
    user_id: client2_user.id,
    emergency_contact: "+96171000022",
    health_notes: "Type 2 diabetes - managed with medication.",
    goals: "Weight loss and improved cardiovascular health"
  })
  |> Repo.insert!()

IO.puts("  Client 2 created: #{client2_user.phone_number} (Bob)")

client3_user =
  SeedHelpers.create_user!(%{
    name: "Carol Williams",
    phone_number: "+96171000003",
    email: "carol@example.com",
    password: "password123456",
    password_confirmation: "password123456",
    role: :client
  })

client3 =
  %Client{}
  |> Client.changeset(%{
    user_id: client3_user.id,
    emergency_contact: "+96171000033",
    health_notes: "None",
    goals: "Train for upcoming marathon"
  })
  |> Repo.insert!()

IO.puts("  Client 3 created: #{client3_user.phone_number} (Carol)")

# =============================================================================
# SESSION PACKAGES
# =============================================================================
IO.puts("Creating session packages...")

# Active package for client1 (Alice) - 12 sessions, 4 used
package1 =
  %SessionPackage{}
  |> SessionPackage.changeset(%{
    client_id: client1_user.id,
    assigned_by_id: admin.id,
    package_type: "standard_12",
    expires_at: DateTime.utc_now() |> DateTime.add(60, :day)
  })
  |> Repo.insert!()
  |> then(fn pkg ->
    # Simulate 4 used sessions
    pkg
    |> Ecto.Changeset.change(%{used_sessions: 4})
    |> Repo.update!()
  end)

IO.puts("  Package for Alice: 12 sessions (8 remaining)")

# Active package for client2 (Bob) - 20 sessions, 3 used
package2 =
  %SessionPackage{}
  |> SessionPackage.changeset(%{
    client_id: client2_user.id,
    assigned_by_id: admin.id,
    package_type: "premium_20",
    expires_at: DateTime.utc_now() |> DateTime.add(90, :day)
  })
  |> Repo.insert!()
  |> then(fn pkg ->
    # Simulate 3 used sessions
    pkg
    |> Ecto.Changeset.change(%{used_sessions: 3})
    |> Repo.update!()
  end)

IO.puts("  Package for Bob: 20 sessions (17 remaining)")

# Expired package for client3 (Carol) - 8 sessions, all used
_package3 =
  %SessionPackage{}
  |> SessionPackage.changeset(%{
    client_id: client3_user.id,
    assigned_by_id: admin.id,
    package_type: "standard_8",
    expires_at: DateTime.utc_now() |> DateTime.add(-30, :day),
    active: false
  })
  |> Repo.insert!()
  |> then(fn pkg ->
    pkg
    |> Ecto.Changeset.change(%{used_sessions: 8})
    |> Repo.update!()
  end)

IO.puts("  Package for Carol: 8 sessions (expired)")

# New active package for client3 (Carol) - 12 sessions, 0 used
package4 =
  %SessionPackage{}
  |> SessionPackage.changeset(%{
    client_id: client3_user.id,
    assigned_by_id: admin.id,
    package_type: "standard_12",
    expires_at: DateTime.utc_now() |> DateTime.add(90, :day)
  })
  |> Repo.insert!()

IO.puts("  Package for Carol: 12 sessions (new)")

# =============================================================================
# TIME SLOTS
# =============================================================================
IO.puts("Creating time slots...")

# Create time slots for weekdays (Monday=1 to Friday=5)
for day <- 1..5 do
  day_name = Enum.at(~w(Monday Tuesday Wednesday Thursday Friday), day - 1)

  # Morning slots: 6am, 7am, 8am, 9am, 10am, 11am
  for hour <- 6..11 do
    Scheduling.create_time_slot(%{
      day_of_week: day,
      start_time: Time.new!(hour, 0, 0),
      end_time: Time.new!(hour + 1, 0, 0),
      active: true
    })
  end

  # Afternoon slots: 2pm, 3pm, 4pm, 5pm, 6pm, 7pm
  for hour <- 14..19 do
    Scheduling.create_time_slot(%{
      day_of_week: day,
      start_time: Time.new!(hour, 0, 0),
      end_time: Time.new!(hour + 1, 0, 0),
      active: true
    })
  end

  IO.puts("  Time slots created for #{day_name}")
end

# Saturday slots (limited)
for hour <- [8, 9, 10, 11] do
  Scheduling.create_time_slot(%{
    day_of_week: 6,
    start_time: Time.new!(hour, 0, 0),
    end_time: Time.new!(hour + 1, 0, 0),
    active: true
  })
end

IO.puts("  Time slots created for Saturday (morning only)")

# =============================================================================
# TRAINING SESSIONS
# =============================================================================
IO.puts("Creating sample training sessions...")

# Helper to insert training sessions directly (bypasses future-date validation for seeds)
defmodule SessionHelpers do
  def insert_session!(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %TrainingSession{}
    |> Ecto.Changeset.change(Map.merge(%{inserted_at: now, updated_at: now}, attrs))
    |> Repo.insert!()
  end
end

# Completed session for Alice with John (in the past)
_session1 =
  SessionHelpers.insert_session!(%{
    client_id: client1_user.id,
    trainer_id: trainer1_user.id,
    package_id: package1.id,
    scheduled_at: DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second),
    duration_minutes: 60,
    status: "completed",
    trainer_notes: "Great progress on deadlifts. Increased weight by 10lbs.",
    approved_by_id: admin.id,
    approved_at: DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.truncate(:second)
  })

IO.puts("  Session 1: Alice with John (completed)")

# Confirmed session for Alice with John (tomorrow)
tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)

_session2 =
  SessionHelpers.insert_session!(%{
    client_id: client1_user.id,
    trainer_id: trainer1_user.id,
    package_id: package1.id,
    scheduled_at: tomorrow,
    duration_minutes: 60,
    status: "confirmed",
    approved_by_id: admin.id,
    approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })

IO.puts("  Session 2: Alice with John (confirmed - tomorrow)")

# Pending session for Bob with Sarah (in 3 days)
in_3_days = DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)

_session3 =
  SessionHelpers.insert_session!(%{
    client_id: client2_user.id,
    package_id: package2.id,
    scheduled_at: in_3_days,
    duration_minutes: 60,
    status: "pending"
  })

IO.puts("  Session 3: Bob (pending - in 3 days)")

# Confirmed session for Bob with Sarah (next week)
next_week = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)

_session4 =
  SessionHelpers.insert_session!(%{
    client_id: client2_user.id,
    trainer_id: trainer2_user.id,
    package_id: package2.id,
    scheduled_at: next_week,
    duration_minutes: 60,
    status: "confirmed",
    approved_by_id: admin.id,
    approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })

IO.puts("  Session 4: Bob with Sarah (confirmed - next week)")

# Pending session for Carol with John (in 2 days)
in_2_days = DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second)

_session5 =
  SessionHelpers.insert_session!(%{
    client_id: client3_user.id,
    package_id: package4.id,
    scheduled_at: in_2_days,
    duration_minutes: 60,
    status: "pending"
  })

IO.puts("  Session 5: Carol (pending - in 2 days)")

# =============================================================================
# TRAINER AVAILABILITY
# =============================================================================
IO.puts("")
IO.puts("Creating trainer availability...")

alias GymStudio.Scheduling.TrainerAvailability

for trainer_user <- [trainer1_user, trainer2_user] do
  # Mon-Fri: 7 AM - 10 PM
  for day <- 1..5 do
    Repo.insert!(%TrainerAvailability{
      trainer_id: trainer_user.id,
      day_of_week: day,
      start_time: ~T[07:00:00],
      end_time: ~T[22:00:00],
      active: true
    })
  end

  # Saturday: 8 AM - 1 PM
  Repo.insert!(%TrainerAvailability{
    trainer_id: trainer_user.id,
    day_of_week: 6,
    start_time: ~T[08:00:00],
    end_time: ~T[13:00:00],
    active: true
  })

  # Sunday: no entry (day off)
  IO.puts("  Availability set for #{trainer_user.name}")
end

# =============================================================================
# SUMMARY
# =============================================================================
IO.puts("")
# =============================================================================
# EXERCISES
# =============================================================================
Code.eval_file("priv/repo/exercise_seeds.exs")

IO.puts("=" |> String.duplicate(60))
IO.puts("SEED DATA CREATED SUCCESSFULLY!")
IO.puts("=" |> String.duplicate(60))
IO.puts("")
IO.puts("Login credentials (all passwords: password123456):")
IO.puts("")
IO.puts("  ADMIN:")
IO.puts("    Phone: +961 70000001")
IO.puts("")
IO.puts("  TRAINERS:")
IO.puts("    John (Approved):  +961 70000002")
IO.puts("    Sarah (Approved): +961 70000003")
IO.puts("    Mike (Pending):   +961 70000004")
IO.puts("")
IO.puts("  CLIENTS:")
IO.puts("    Alice: +961 71000001")
IO.puts("    Bob:   +961 71000002")
IO.puts("    Carol: +961 71000003")
IO.puts("")
IO.puts("=" |> String.duplicate(60))
