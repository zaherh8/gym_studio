# Progress Tracking Feature

## Overview

The client progress tracking feature allows clients to view their exercise history, track personal records (PRs), and visualize progress over time with charts.

## Routes

- `/client/progress` — Dashboard showing all exercises the client has logged, with filtering by category
- `/client/progress/exercises/:exercise_id` — Detailed view for a specific exercise with chart, history table, and stats

## Features

### Progress Dashboard (`/client/progress`)
- Lists all exercises the client has performed
- Each card shows: exercise name, category, latest stats (sets/reps/weight), total session count
- 🏆 PR badge displayed when the client has a personal record for an exercise
- Category filter dropdown (strength, cardio, flexibility, functional)
- Click any card to navigate to the exercise detail page

### Exercise Detail (`/client/progress/exercises/:exercise_id`)
- **Stats summary**: Max weight, max reps, total volume, total sessions
- **Progress chart**: Line chart (Chart.js) showing weight/reps/duration over time
- **History table**: All logged sessions for this exercise, ordered by most recent
- **PR highlighting**: Rows where the client achieved their best are highlighted with 🏆

## Chart.js Integration

Chart.js is loaded via CDN in the root layout. The `ProgressChart` LiveView hook (defined in `assets/js/app.js`) reads chart data from the `data-chart` attribute and renders a responsive line chart. The hook handles mount, update, and destroy lifecycle events.

## Context Functions (`GymStudio.Progress`)

- `list_client_exercises(client_id, opts)` — Distinct exercises with stats and PR info
- `get_exercise_history(client_id, exercise_id)` — All logs ordered by date desc
- `get_exercise_stats(client_id, exercise_id)` — Aggregated stats (max weight, max reps, total volume, total sessions)
- `get_personal_records(client_id)` — Best weight per exercise (pre-existing)

## Body Metrics (`/client/progress/metrics`)

Clients can log and track body measurements over time:

### Features
- **Log new entry**: Date (default today), weight (kg), body fat %, chest/waist/hips/bicep/thigh (cm), notes
- **Weight chart**: Chart.js line chart showing weight over time (reuses `ProgressChart` hook)
- **History table**: All entries ordered by most recent, with edit/delete actions
- **Upsert**: One entry per day per user — logging on the same date replaces the previous entry
- **Validation**: At least one measurement (weight or any body measurement) must be provided

### Context Functions (`GymStudio.Metrics`)
- `list_metrics(user_id, opts)` — All entries ordered by date desc, with optional `:limit`
- `get_metric!(id)` — Single entry by ID
- `create_metric(attrs)` — Create with upsert on `(user_id, date)`
- `update_metric(metric, attrs)` — Update existing entry
- `delete_metric(metric)` — Delete entry
- `get_latest_metric(user_id)` — Most recent entry
- `get_metric_history(user_id, field)` — `[{date, value}]` pairs for charting a specific field

### Schema: `body_metrics`
- `user_id` — the client
- `logged_by_id` — who logged it (currently always the client themselves)
- `date` — one entry per day (unique constraint with `user_id`)
- `weight_kg`, `body_fat_pct`, `chest_cm`, `waist_cm`, `hips_cm`, `bicep_cm`, `thigh_cm` — all optional decimals
- `notes` — optional text

## Authorization

All progress views are behind the `:require_client` pipeline. Queries are scoped to `current_scope.user.id`, so clients can only see their own data. Body metrics mutations verify ownership before edit/delete.
