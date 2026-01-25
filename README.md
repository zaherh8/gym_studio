# React Gym - Gym Studio Management System

A modern gym and personal training management system built with Phoenix LiveView and Elixir. This application manages trainers, clients, session packages, and training schedules with real-time updates and role-based access control.

## Table of Contents

- [Overview](#overview)
- [Business Requirements](#business-requirements)
- [System Architecture](#system-architecture)
- [Design Decisions](#design-decisions)
- [Database Structure](#database-structure)
- [Getting Started](#getting-started)
- [Authentication](#authentication)
- [Testing](#testing)
- [Deployment](#deployment)

## Overview

React Gym is a comprehensive gym management platform that facilitates:

- **Client Management**: Track clients, their fitness goals, health notes, and emergency contacts
- **Trainer Management**: Manage trainer profiles with specializations and approval workflows
- **Session Packages**: Flexible session packages (8, 12, or 20 sessions) with expiration tracking
- **Booking System**: Three-stage booking workflow (pending → confirmed → completed)
- **Real-time Notifications**: In-app notifications with PubSub integration
- **Role-based Access**: Separate portals for admins, trainers, and clients

## Business Requirements

### User Roles

**Admin**
- Full system access
- Approve/reject trainer applications
- Assign session packages to clients
- View analytics and manage all users
- Override any operations

**Trainer**
- View assigned sessions
- Confirm/complete sessions
- Add session notes
- View client list
- Manage availability (time slots)
- Requires admin approval before active

**Client**
- Book training sessions
- View session history
- Track package usage
- Receive notifications
- Manage profile and goals

### Core Workflows

#### 1. Trainer Onboarding
1. User registers with phone number + password
2. Creates trainer profile (bio, specializations)
3. Profile status: "pending"
4. Admin reviews and approves
5. Status changes to "approved"
6. Trainer can now receive session assignments

#### 2. Session Booking Flow
1. **Client books session** → Status: "pending"
   - Client selects date/time from available slots
   - Can include notes about session goals

2. **Admin/Trainer confirms** → Status: "confirmed"
   - Trainer is assigned to the session
   - Confirmation notification sent

3. **After session completion** → Status: "completed"
   - Trainer adds session notes
   - Session marked complete
   - Package session count decremented

#### 3. Package Management
- Admin assigns packages to clients
- Package types: "standard_8", "standard_12", "premium_20"
- Packages track: total_sessions, used_sessions, expires_at
- System prevents booking when:
  - No active package
  - Package expired
  - No remaining sessions

## System Architecture

### Technology Stack

- **Backend**: Elixir 1.18.4 + Phoenix 1.8.3
- **Frontend**: Phoenix LiveView 1.1.20 + TailwindCSS + DaisyUI
- **Database**: PostgreSQL with Ecto
- **Background Jobs**: Oban 2.18
- **Real-time**: Phoenix PubSub
- **Authentication**: Bcrypt with session tokens
- **Testing**: ExUnit with 195 tests

### Key Libraries

```elixir
{:phoenix_live_view, "~> 1.1.0"}  # Real-time UI
{:oban, "~> 2.18"}                # Background jobs
{:bcrypt_elixir, "~> 3.0"}        # Password hashing
{:swoosh, "~> 1.17"}              # Email delivery
{:req, "~> 0.5"}                  # HTTP client
```

## Design Decisions

### 1. Phone-Based Authentication
- **Decision**: Use phone number + password instead of email-based magic links
- **Rationale**:
  - More accessible for gym clients
  - Faster registration flow
  - Aligns with SMS notification strategy
  - Phone numbers are required anyway for emergency contacts

### 2. LiveView for Real-Time Updates
- **Decision**: Use Phoenix LiveView instead of traditional templates
- **Rationale**:
  - Real-time notifications without JavaScript frameworks
  - Reduced frontend complexity
  - Better developer experience
  - Built-in WebSocket management

### 3. Three-Stage Booking Workflow
- **Decision**: pending → confirmed → completed (vs direct booking)
- **Rationale**:
  - Gives trainers control over their schedule
  - Prevents double-booking conflicts
  - Allows for trainer availability validation
  - Creates approval trail for accountability

### 4. Profile Separation (User + Trainer/Client)
- **Decision**: Separate User table from Trainer/Client profiles
- **Rationale**:
  - Single source of truth for authentication
  - Users can potentially have multiple roles
  - Cleaner data model and queries
  - Easier to add new profile types

### 5. User ID References in Sessions/Packages
- **Decision**: TrainingSession.trainer_id and TrainingSession.client_id reference User.id (not Trainer.id/Client.id)
- **Rationale**:
  - Simplified queries and joins
  - Consistent foreign key structure
  - Prevents orphaned sessions if profiles deleted
  - User is the primary entity

### 6. Package Types as Strings
- **Decision**: Store package types as strings ("standard_8", "standard_12", "premium_20")
- **Rationale**:
  - Easy to add new package types without migrations
  - Self-documenting in database
  - Flexible for future pricing tiers
  - Human-readable in queries

### 7. Oban for Background Jobs
- **Decision**: Use Oban for scheduled tasks and async operations
- **Rationale**:
  - Built-in retry logic
  - Job scheduling and cron support
  - Perfect for session reminders
  - Observability and monitoring

## Database Structure

### Core Tables

#### users
Primary authentication and user management table.

```sql
- id (uuid, PK)
- email (citext, nullable, unique)
- phone_number (string, unique, required)
- hashed_password (string)
- role (enum: admin, trainer, client) - default: client
- active (boolean) - default: true
- confirmed_at (timestamp)
- inserted_at, updated_at
```

#### trainers
Trainer-specific profile information.

```sql
- id (uuid, PK)
- user_id (uuid, FK -> users.id)
- bio (text)
- specializations (array of strings)
- status (string) - pending, approved, rejected
- approved_by_id (uuid, FK -> users.id)
- approved_at (timestamp)
- inserted_at, updated_at
```

#### clients
Client-specific profile information.

```sql
- id (uuid, PK)
- user_id (uuid, FK -> users.id)
- emergency_contact (string)
- health_notes (text)
- goals (text)
- inserted_at, updated_at
```

#### session_packages
Session package assignments and tracking.

```sql
- id (uuid, PK)
- client_id (uuid, FK -> users.id)
- assigned_by_id (uuid, FK -> users.id)
- package_type (string) - "standard_8", "standard_12", "premium_20"
- total_sessions (integer)
- used_sessions (integer) - default: 0
- active (boolean) - default: true
- expires_at (timestamp, nullable)
- notes (text)
- inserted_at, updated_at
```

#### training_sessions
Training session bookings and tracking.

```sql
- id (uuid, PK)
- client_id (uuid, FK -> users.id)
- trainer_id (uuid, FK -> users.id, nullable)
- package_id (uuid, FK -> session_packages.id, nullable)
- approved_by_id (uuid, FK -> users.id, nullable)
- cancelled_by_id (uuid, FK -> users.id, nullable)
- scheduled_at (timestamp)
- duration_minutes (integer) - default: 60
- status (string) - pending, confirmed, completed, cancelled, no_show
- notes (text) - client notes
- trainer_notes (text)
- approved_at (timestamp, nullable)
- cancelled_at (timestamp, nullable)
- cancellation_reason (text)
- inserted_at, updated_at
```

#### time_slots
Available time slots for booking.

```sql
- id (uuid, PK)
- day_of_week (integer) - 1=Monday, 7=Sunday
- start_time (time)
- end_time (time)
- active (boolean) - default: true
- inserted_at, updated_at
```

#### otp_tokens
OTP verification tokens for phone registration.

```sql
- id (uuid, PK)
- phone_number (string)
- hashed_code (string) - SHA256 hashed 6-digit code
- purpose (string) - "registration", "password_reset"
- attempts (integer) - max 3
- expires_at (timestamp) - 5 minutes
- verified_at (timestamp, nullable)
- inserted_at, updated_at
```

#### notifications
In-app notification system.

```sql
- id (uuid, PK)
- user_id (uuid, FK -> users.id)
- title (string)
- message (text)
- type (string) - booking_confirmed, booking_cancelled, etc.
- read_at (timestamp, nullable)
- action_url (string, nullable)
- metadata (jsonb)
- inserted_at, updated_at
```

### Key Relationships

```
users
  ├─ has_one: trainer
  ├─ has_one: client
  ├─ has_many: notifications
  ├─ has_many: session_packages (as client)
  ├─ has_many: assigned_packages (as admin)
  ├─ has_many: client_sessions (as client)
  └─ has_many: trainer_sessions (as trainer)

trainer
  └─ belongs_to: user

client
  └─ belongs_to: user

session_packages
  ├─ belongs_to: client (user)
  ├─ belongs_to: assigned_by (user)
  └─ has_many: training_sessions

training_sessions
  ├─ belongs_to: client (user)
  ├─ belongs_to: trainer (user)
  ├─ belongs_to: package (session_package)
  ├─ belongs_to: approved_by (user)
  └─ belongs_to: cancelled_by (user)
```

## Getting Started

### Prerequisites

- Elixir 1.15+ and Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Installation

1. **Clone and install dependencies**
```bash
git clone <repository>
cd gym_studio
mix setup
```

2. **Configure environment variables**
```bash
# Create .env file
cat > .env << EOF
DATABASE_URL=ecto://postgres:postgres@localhost/gym_studio_dev
SECRET_KEY_BASE=$(mix phx.gen.secret)
PHX_HOST=localhost
PORT=4000
EOF
```

3. **Create and migrate database**
```bash
mix ecto.create
mix ecto.migrate
```

4. **Seed the database** (optional - for testing)
```bash
mix run priv/repo/seeds.exs
```

This creates test users:
- **Admin**: +1111111111 / password123456
- **Trainers**: +2222222222, +3333333333 / password123456
- **Clients**: +5555555555, +6666666666, +7777777777 / password123456

5. **Start the server**
```bash
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

## Authentication

### Phone Number + OTP Registration Flow

Registration is a 3-step process with OTP verification:

1. **Step 1: Phone Entry** (`/users/register`)
   - User selects country code (Lebanon 🇱🇧 default) and enters local number
   - Phone normalized to E.164 format (e.g., +9611234567)
   - OTP code (6 digits) sent to phone (logged to console in dev)

2. **Step 2: OTP Verification**
   - User enters 6-digit code
   - Codes expire after 5 minutes
   - Max 3 attempts per code
   - 60-second cooldown between resend requests

3. **Step 3: Password Setup**
   - User sets password (12+ characters)
   - Optional email for account recovery
   - User created with `confirmed_at` set (phone verified)
   - Default role: client

2. **Login** (`POST /users/log-in`)
   - User provides phone_number + password
   - Session token generated and stored in session
   - Redirects based on role:
     - Admin → `/admin`
     - Trainer → `/trainer`
     - Client → `/client`

3. **Session Management**
   - Sessions stored in encrypted cookies
   - Tokens auto-renewed every 7 days
   - Remember me option available
   - Sessions expire after 14 days of inactivity

### Role-Based Access Control

Each route requires specific plugs:

```elixir
# Require authentication
plug :require_authenticated_user

# Require active account
plug :require_active_user

# Require specific role
plug :require_admin
plug :require_trainer
plug :require_client
```

LiveView routes use `on_mount` hooks:
```elixir
live_session :client_portal,
  on_mount: {GymStudioWeb.UserAuth, :ensure_authenticated} do
  # Protected LiveView routes
end
```

## Testing

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/gym_studio/accounts_test.exs

# Run specific test
mix test test/gym_studio/accounts_test.exs:42
```

### Test Structure

- **195 total tests** covering:
  - Context layer (Accounts, Packages, Scheduling, Notifications)
  - Controller tests (Registration, Session, Settings)
  - LiveView tests (Client Dashboard, Trainer Dashboard)
  - Schema validations

### Test Fixtures

Located in `test/support/fixtures/`:
- `accounts_fixtures.ex` - Users, trainers, clients
- `packages_fixtures.ex` - Session packages
- `scheduling_fixtures.ex` - Sessions, time slots
- `notifications_fixtures.ex` - Notifications

### Testing Patterns

```elixir
# Create test user
user = user_fixture(%{role: :client})

# Create trainer with profile
trainer_user = user_fixture(%{role: :trainer})
trainer = trainer_fixture(%{user_id: trainer_user.id})

# Create session package
package = package_fixture(%{
  client_id: client_user.id,
  assigned_by_id: admin.id,
  package_type: "standard_12"
})

# Test LiveView
{:ok, view, html} = live(conn, ~p"/client")
assert html =~ "Welcome back!"
```

## Key Features

### Real-Time Notifications
- In-app notifications with PubSub
- Subscribe in LiveView: `Notifications.subscribe(user_id)`
- Automatic updates without page refresh

### Background Jobs
- Session reminders (1 hour before)
- Package expiration checks
- Notification delivery
- Data cleanup tasks

### Session Management
- Visual calendar/schedule views
- Drag-and-drop booking (future enhancement)
- Recurring session support
- Multi-trainer support

### Analytics (Admin)
- Total sessions by status
- Revenue tracking
- Popular time slots
- Trainer performance metrics

## Development

### Code Quality Tools

```bash
# Format code
mix format

# Run linter
mix credo

# Type checking
mix dialyzer

# Pre-commit checks
mix precommit
```

### Project Structure

```
lib/
├── gym_studio/              # Business logic contexts
│   ├── accounts/            # User, Trainer, Client
│   ├── packages/            # Session packages
│   ├── scheduling/          # Sessions, time slots
│   └── notifications/       # Notification system
├── gym_studio_web/          # Web layer
│   ├── controllers/         # Traditional controllers
│   ├── live/                # LiveView modules
│   │   ├── admin/          # Admin dashboard
│   │   ├── client/         # Client portal
│   │   └── trainer/        # Trainer portal
│   └── components/          # Reusable components
priv/
├── repo/migrations/         # Database migrations
└── static/                  # Assets
test/
├── gym_studio/              # Context tests
├── gym_studio_web/          # Web tests
└── support/                 # Test helpers
```

## Deployment

### Production Checklist

1. **Environment Variables**
```bash
DATABASE_URL=<production_db_url>
SECRET_KEY_BASE=<generate_with_mix_phx_gen_secret>
PHX_HOST=<your_domain.com>
PORT=4000
```

2. **Database**
```bash
mix ecto.create
mix ecto.migrate
```

3. **Assets**
```bash
mix assets.deploy
```

4. **Release**
```bash
MIX_ENV=prod mix release
_build/prod/rel/gym_studio/bin/gym_studio start
```

### Fly.io Deployment

This project is configured for Fly.io deployment.

1. **Install Fly CLI**
```bash
curl -L https://fly.io/install.sh | sh
fly auth login
```

2. **Create the app (first time)**
```bash
fly launch --no-deploy
fly postgres create --name gym-studio-db
fly postgres attach gym-studio-db
```

3. **Set secrets**
```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
```

4. **Deploy**
```bash
fly deploy
```

### CI/CD with GitHub Actions

The project includes GitHub Actions workflows:
- **CI** (`.github/workflows/ci.yml`): Runs on all PRs and pushes to main
  - Compiles with warnings as errors
  - Checks formatting
  - Runs all tests
  - Builds Docker image

- **Deploy** (`.github/workflows/deploy.yml`): Deploys to Fly.io on push to main
  - Requires `FLY_API_TOKEN` secret in GitHub repository settings

### Infrastructure

- **Hosting**: Fly.io (configured)
- **Database**: PostgreSQL (Fly Postgres or external)
- **CDN**: Cloudflare or CloudFront for static assets
- **Monitoring**: AppSignal, New Relic, or Honeybadger

## Contributing

1. Create a feature branch
2. Write tests for new functionality
3. Ensure all tests pass: `mix test`
4. Run code quality checks: `mix precommit`
5. Submit a pull request

## License

Copyright © 2026 React Gym. All rights reserved.

## Support

For questions or issues:
- GitHub Issues: [Create an issue]
- Email: support@reactgym.com
- Documentation: [Wiki]

## Roadmap

### Phase 1 (Current)
- ✅ Core authentication and authorization
- ✅ Trainer and client management
- ✅ Session booking workflow
- ✅ Package management
- ✅ In-app notifications

### Phase 2 (Planned)
- [ ] SMS notifications via Telnyx
- [ ] Email notifications
- [ ] Payment processing integration
- [ ] Recurring session bookings
- [ ] Mobile app (React Native)

### Phase 3 (Future)
- [ ] Nutrition tracking
- [ ] Workout plan builder
- [ ] Progress photos and measurements
- [ ] Video session support
- [ ] Multi-location support

---

Built with ❤️ using Phoenix + Elixir
