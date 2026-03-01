# Engineer Memory

Lessons learned from code reviews. Read this before every task.

## Phoenix LiveView

- **Never use `phx-blur` or `phx-keyup` with `phx-value-*` to capture input values.** They send the rendered attribute, NOT the current input value. Always use `<form phx-submit>` or `<form phx-change>` with named inputs.
- **Form-based saves > auto-save.** Users need explicit Save buttons with visual feedback (flash messages).
- Use `phx-change` on forms for live search/filter. Use `phx-submit` for saves.
- `phx-debounce="300"` on search inputs to avoid excessive server calls.

## Ecto / Database

- `on_delete: :restrict` when column is `null: false` — `:nilify_all` is incompatible with NOT NULL.
- `training_sessions.client_id` references `users.id`, NOT `clients.id`.
- Always add indexes on foreign key columns in migrations.
- Use `Repo.transaction` for multi-step operations (e.g., reorder).

## Authorization

- Every mutation must verify ownership (not just mount).
- Return `{:error, :unauthorized}` from auth helpers — never `{:noreply, socket}`.
- Pattern match the error in callers with `case`, not `with`.

## Queries

- Escape ILIKE wildcards (`%`, `_`, `\`) in search queries.
- Prefer single queries with multiple aggregates over multiple separate queries.
- Always preload associations needed in templates.
- **N+1 pattern to avoid:** Never `Enum.map` over results to fire individual queries. Use window functions (`ROW_NUMBER() OVER (PARTITION BY ...)`) or lateral joins to batch. When multiple entities need the same data, use `where(field in ^ids)` + `Enum.group_by` in Elixir.
- **Batch query pattern:** Fetch all records with `where([x], x.foreign_key in ^ids)`, then `Enum.group_by(&1.foreign_key)` to build a lookup map. Avoids N+1 while keeping logic simple.
- **Always filter in SQL, not Elixir.** Push WHERE clauses into the query — don't fetch all rows then `Enum.filter` in memory. This is especially bad when combined with N+1 (queries run for rows that get discarded).

## Security

- **SRI hashes for CDN scripts:** Always add `integrity` and `crossorigin="anonymous"` attributes when loading scripts from CDNs. Pin to specific versions (e.g., `chart.js@4.4.8` not `chart.js@4`).

## Testing

- Test that form values actually persist (save → reload → verify).
- Test authorization on mutations, not just mount.
- Use `render_submit` for form tests, not `render_click` on individual events.

## Form UX

- Always show field names in form error messages (e.g., `"Weight: must be greater than 0"` not just `"must be greater than 0"`). Use `Phoenix.Naming.humanize(field)` to format.
- Hide data visualization sections (charts) when there's no relevant data — show them only when meaningful data exists.

## Code Style

- Group all `handle_event/3` clauses together. Private helpers after.
- Use `assign_new` for optional assigns with defaults.
- Display helpers: always handle nil with fallbacks (e.g., `name || email || "Unknown"`).

## Scheduling / Availability

- Trainer availability uses `users.id` as `trainer_id` (not `trainers.id`).
- `get_all_available_slots/1` returns slots with `trainer_id` + `trainer_name` — client booking selects both slot AND trainer.
- When updating BookSessionLive, existing tests that click `button[phx-value-slot]` need updating to also include `phx-value-trainer`.
- Time inputs from HTML forms come as "HH:MM" strings — append ":00" before `Time.from_iso8601/1`.
- `format_hour/1`: Always handle hour 0 explicitly — `format_hour(0)` must return "12:00 AM", not "0:00 AM".

## Calendar / Schedule Views

- Trainer schedule uses `list_trainer_availabilities/1` to show available hours (not time_slots).
- Admin calendar uses `list_all_sessions/1` with `trainer_id` filter option.
- Sessions grouped by `{date, hour}` for O(1) lookup in calendar grid.
- Mobile calendar: single day view with `mobile_day_offset` assign (0-6).
- Trainer colors in admin calendar: cycle through 8 predefined color pairs.
- `@hours_range` (6..21) defines visible calendar hours.
- **Use `Enum.group_by` not `Enum.into` for hour grouping** — `Enum.into` overwrites when multiple sessions share the same hour. Always use list-based grouping for calendar data.
- **Modal click-through:** Never put `phx-click="close_modal"` on the outer `.modal` div — click events bubble up from content. Use only `phx-click-away` on `.modal-box`.
- **Type consistency in filters:** Form params arrive as strings. Compare with `to_string(uuid)` when matching against Ecto UUID fields in templates.

## Project Conventions

- Package types: `standard_8`, `standard_12`, `premium_20`
- Phone numbers: Lebanese format `+961...`
- Brand color: Red
- GitHub account: `zaherh8` (switch with `gh auth switch -u zaherh8`)
- PATH: `export PATH="/opt/homebrew/opt/postgresql@17/bin:/Users/zaherhassan/.fly/bin:$PATH"`
- Checks before push: `mix format --check-formatted && mix compile --warnings-as-errors && mix test`
- Feature branches: `feat/<issue-number>-<short-name>`
