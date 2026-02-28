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

## Testing

- Test that form values actually persist (save → reload → verify).
- Test authorization on mutations, not just mount.
- Use `render_submit` for form tests, not `render_click` on individual events.

## Code Style

- Group all `handle_event/3` clauses together. Private helpers after.
- Use `assign_new` for optional assigns with defaults.
- Display helpers: always handle nil with fallbacks (e.g., `name || email || "Unknown"`).

## Project Conventions

- Package types: `standard_8`, `standard_12`, `premium_20`
- Phone numbers: Lebanese format `+961...`
- Brand color: Red
- GitHub account: `zaherh8` (switch with `gh auth switch -u zaherh8`)
- PATH: `export PATH="/opt/homebrew/opt/postgresql@17/bin:/Users/zaherhassan/.fly/bin:$PATH"`
- Checks before push: `mix format --check-formatted && mix compile --warnings-as-errors && mix test`
- Feature branches: `feat/<issue-number>-<short-name>`
