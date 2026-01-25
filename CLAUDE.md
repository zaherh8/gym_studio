# CLAUDE.md - AI Assistant Context

## Project Overview

**React Gym** is a gym management platform built with Phoenix 1.8 + LiveView for a private training studio in Lebanon. It handles trainers, clients, session packages, and bookings with real-time updates.

## Tech Stack

- **Backend**: Elixir 1.18 + Phoenix 1.8.3 + LiveView 1.1
- **Database**: PostgreSQL with Ecto
- **Styling**: TailwindCSS 4 + DaisyUI
- **Background Jobs**: Oban
- **Deployment**: Fly.io

## Key Architecture Decisions

1. **Phone-based auth with OTP**: Users register with phone number + country code (Lebanon default). 6-digit OTP verification, then password setup. Codes are hashed (SHA256), expire in 5 mins, max 3 attempts.

2. **User → Profile separation**: Single `users` table for auth, separate `trainers`/`clients` profile tables. Sessions reference `user_id` directly.

3. **Three-stage booking**: pending → confirmed → completed workflow with trainer assignment.

4. **E.164 phone format**: All phone numbers stored as `+[country][number]` (e.g., `+9611234567`).

## Code Quality Standards

- Run `mix precommit` before commits (compile warnings, format, tests)
- Use `mix test --failed` to rerun failed tests
- Always use LiveView streams for collections
- Never use `@current_user` - use `@current_scope.user` instead
- Forms must use `to_form/2` - never pass changesets to templates

## Project Structure

```
lib/gym_studio/           # Business logic
  accounts/               # Users, Trainers, Clients, OtpToken
  packages/               # SessionPackage
  scheduling/             # TrainingSession, TimeSlot
  notifications/          # Notification, PubSub
  phone_utils.ex          # Country codes, E.164 normalization
  workers/                # Oban workers (OtpDeliveryWorker)

lib/gym_studio_web/       # Web layer
  live/
    admin/                # Admin dashboard
    client/               # Client portal
    trainer/              # Trainer portal
    registration_live.ex  # Phone OTP registration flow
  components/
    core_components.ex    # Includes phone_input component
```

## Authentication Flow

1. **Registration** (`/users/register` - RegistrationLive):
   - Step 1: Phone + country selector → sends OTP
   - Step 2: 6-digit OTP verification
   - Step 3: Password + optional email → creates confirmed user

2. **Login** (`/users/log-in`): Phone + password

3. **Role-based redirects**: Admin→`/admin`, Trainer→`/trainer`, Client→`/client`

## Database Tables

- `users` - Auth (phone_number, hashed_password, role, confirmed_at)
- `trainers` - Profile (user_id, bio, specializations, status)
- `clients` - Profile (user_id, emergency_contact, goals)
- `session_packages` - (client_id, package_type, total/used_sessions)
- `training_sessions` - (client_id, trainer_id, status, scheduled_at)
- `otp_tokens` - (phone_number, hashed_code, purpose, attempts, expires_at)
- `notifications` - (user_id, title, message, type, read_at)

## Common Tasks

### Add a new feature
1. Create migration if needed: `mix ecto.gen.migration name`
2. Add schema in `lib/gym_studio/context/`
3. Add context functions
4. Create LiveView in appropriate portal
5. Add route in `router.ex`
6. Write tests

### Fix a bug
1. Reproduce with test: `mix test test/path:line`
2. Fix in smallest scope possible
3. Verify: `mix test --failed`

### OTP/SMS testing
OTP codes are logged to console in dev. Check server logs after sending code.

## Testing

- 195 tests total
- Fixtures in `test/support/fixtures/`
- Use `user_fixture()`, `trainer_fixture()`, `package_fixture()`
- For OTP tests, create tokens with known codes via direct DB insert

## Environment Variables (Production)

```
DATABASE_URL=
SECRET_KEY_BASE=
PHX_HOST=
FLY_APP_NAME=
```

## Don't Do

- Don't use `@current_user` (use `@current_scope.user`)
- Don't use `<.form for={@changeset}>` (use `for={@form}`)
- Don't use `phx-update="append"` (use streams)
- Don't nest modules in same file
- Don't use `String.to_atom/1` on user input
