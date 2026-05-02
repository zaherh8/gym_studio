# Engineer Memory

Lessons learned from code reviews. Read this before every task.

## Phoenix LiveView

- **Never use `phx-blur` or `phx-keyup` with `phx-value-*` to capture input values.** They send the rendered attribute, NOT the current input value. Always use `<form phx-submit>` or `<form phx-change>` with named inputs.
- **Form-based saves > auto-save.** Users need explicit Save buttons with visual feedback (flash messages).
- Use `phx-change` on forms for live search/filter. Use `phx-submit` for saves.
- `phx-debounce="300"` on search inputs to avoid excessive server calls.
- **LiveComponent forms with `phx-target={@myself}`** submit params under the form's `as` key (e.g., `"branch"`). Handle events with `%{"branch" => params}` pattern.
- **`input_value/2` is NOT available in LiveComponents by default.** Use `Phoenix.HTML.Form.input_value/2` instead.
- **CoreComponents `<.input>` does NOT support arbitrary attrs like `hint`.** Only use documented attributes.

## Ecto / Database

- `on_delete: :restrict` when column is `null: false` — `:nilify_all` is incompatible with NOT NULL.
- `training_sessions.client_id` references `users.id`, NOT `clients.id`.
- Always add indexes on foreign key columns in migrations.
- Use `Repo.transaction` for multi-step operations (e.g., reorder).
- **Date vs DateTime in queries:** When comparing against `:utc_datetime` columns, use `DateTime`, not `Date`. Use `DateTime.new!/3` to convert.

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
- **Never call context functions from templates.** Pre-compute all data in mount/handle_event and pass as assigns. Template-side context calls cause N+1.

## Security

- **SRI hashes for CDN scripts:** Always add `integrity` and `crossorigin="anonymous"` attributes when loading scripts from CDNs. Pin to specific versions (e.g., `chart.js@4.4.8` not `chart.js@4`).

## Concurrency / Race Conditions

- **Never read-then-write in Ecto for counters.** Reading a value into Elixir memory then updating creates race conditions under concurrent requests. Use atomic SQL: `update_all` with `set: [col: p.col + 1]` and a WHERE guard, or `lock("FOR UPDATE")` inside a transaction.
- **`toggle_branch_active` must use atomic `update_all`.** The old read-then-toggle pattern (`branch |> change(%{active: !branch.active}) |> update`) was a race condition. Use `from(b in Branch, where: b.id == ^branch.id, update: [set: [active: ^new_active]]) |> Repo.update_all([])` instead. Note: pinned variables in `update_all` keyword lists only work inside `from` macro's `update:` option, NOT in `Repo.update_all(query, set: [...])`.

## String Safety

- **Never use `String.to_existing_atom/1` on user input.** Use a whitelist approach: `if role in ~w(client trainer admin), do: String.to_existing_atom(role), else: :default`. Extracted as `BranchHelpers.parse_role/1`.
- **Never use `String.to_integer/1` on untrusted input.** Always guard against empty strings and invalid format. Extracted as `BranchHelpers.safe_string_to_integer/1`.

## Confirmation Modals

- **Dangerous actions must have confirmation.** Deactivating a branch strands users/trainers/sessions — always show a confirmation modal before executing. Reactivating is safe and doesn't need confirmation.

## Form Validation with Ecto

- **Always use Ecto changesets for forms.** Raw HTML forms bypass validation. Use `<.form for={@changeset}>` with `phx-change="validate"` for live feedback and `phx-submit="save"` for persistence.
- **Access field errors from form:** Use `form.source.errors |> Enum.filter(fn {f, _} -> f == field end)` to get per-field error messages. `Phoenix.HTML.Form.input_errors/2` may not be available in all versions.
- **The `<.error>` component in CoreComponents is PRIVATE** — it can only be used inside `<.input>`. For standalone error display, use `<p class="text-sm text-error">` instead.
- **`as:` attribute not supported in `<.form>` component.** The form's `as` name is derived from the changeset's data struct. Use `Phoenix.HTML.Form.input_name/2` for input name attributes.

## Branch Filtering Pattern

- All context functions that accept `branch_id: nil` should return unfiltered results (all branches).
- The `BranchSelectorComponent.effective_branch_id/1` helper converts `"all"` to `nil` for query filtering.
- Branch selector is a reusable function component — use `BranchSelectorComponent.branch_selector/1` in any admin LiveView.
- **Dead code from defensive clamping:** If you `max(value, 0)` before `validate_number >= 0`, the validation is dead code. Pick one approach: clamp OR validate, not both.
- **Always test boundary conditions:** exhausted packages, zero balances, max capacity — don't just test the happy path.

## Testing

- **All tests must pass before pushing.** Run `mix test` as part of the standard pre-push checks. No exceptions.
- **Never skip, tag with @tag :skip, or delete a failing test.** If a test fails, fix the code or the test to satisfy the requirement it was testing. Removing or skipping a test means the requirement is no longer verified — that's a regression waiting to happen.
- **Fixtures must not hardcode values that clash with seeds.** Use unique suffixes (e.g., `System.unique_integer`) for slugs, emails, and other unique fields. Never override fixture uniqueness in test code.
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

## Double-Booking Prevention

- Partial unique index `training_sessions_trainer_scheduled_at_active_index` on `(trainer_id, scheduled_at) WHERE status != 'cancelled'` prevents double-booking at the DB level.
- `unique_constraint` in `TrainingSession.changeset/2` catches the violation; `book_session/1` translates it to `{:error, :slot_taken}`.
- LiveView handles `:slot_taken` by flashing an error and resetting to slot selection.
- An older index `training_sessions_trainer_scheduled_active_index` (without `_at_`) existed from a previous attempt — migration drops it.

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
- **Heat-map data requires a dedicated query** — `count_sessions_per_day_for_trainer/4` groups by `DATE(scheduled_at)` and returns `%Date{} => count`. PostgreSQL's `DATE()` returns an Ecto Date struct, not a string — handle both types with pattern matching.
- **No `elseif` in HEEX templates** — Elixir doesn't have `elseif`. Use `cond do` in helper functions instead of inline multi-branch `if` in class/style attributes.
- **Scroll-triggered collapse** — Use a sentinel element + IntersectionObserver in a `phx-hook`. The hook pushes an event to the LiveView to toggle state. Works without full-page reload.
- **Flash messages need a container** — `put_flash/3` in LiveView handle_event only works if there's a flash container in the rendered template or layout. Root layout didn't have one, so added inline flash display in the LiveView itself.
- **Trainer availability vs time slots** — The schedule `is_available?` check uses `TrainerAvailability` records (set via `set_trainer_availability/3`), NOT `TimeSlot` records. Tests that need available slots must create trainer availability, not time slots.

## Label / Display Conventions

- Trainer fallback label is **"Unassigned"** (not "Unknown") — consistent across all views.
- `display_name/1` catch-all returns "Unassigned" for trainer contexts.
- Admin calendar modal conditionally shows "Assign a Trainer" panel when `trainer_id` is nil.

## Project Conventions

- Package types: `standard_8`, `standard_12`, `premium_20`
- Phone numbers: Lebanese format `+961...`
- Brand color: Red
- GitHub account: `zaherh8` (switch with `gh auth switch -u zaherh8`)
- **Verify git identity before committing.** Repo-level config should be `user.name="Zaher Hassan"` and `user.email="zaherh8@users.noreply.github.com"`. If `git config user.email` shows a work email, fix it with `git config user.email "zaherh8@users.noreply.github.com"` before any commits.
- PATH: `export PATH="/opt/homebrew/opt/postgresql@17/bin:/Users/zaherhassan/.fly/bin:$PATH"`
- Checks before push: `mix format --check-formatted && mix compile --warnings-as-errors && mix test`
- Feature branches: `feat/<issue-number>-<short-name>`

## Branch Scoping (#68)

- All Scheduling context functions that accept `opts \\ []` support `:branch_id` for scoping.
- When adding branch_id to existing functions, always use `opts \\ []` keyword list for backward compatibility — never add a required positional arg.
- Client/trainer profile views show "My Branch" label with badge — use `Branches.get_branch!(user.branch_id)`.
- Registration form includes branch dropdown for clients; trainers get branch assigned by admin.
- Cross-branch access guard pattern: check `session.branch_id != user.branch_id` → redirect with flash error.
- `trainer_has_client?/3` now accepts `opts` (3rd arg) with `:branch_id` — update all call sites.
- Pre-existing test failures (9) in registration/forgot_password tests are unrelated to branch work — Telnyx OTP mock issue.
- **Branch filter consistency:** When joining sessions + users, always filter on `s.branch_id` (session's branch), not `c.branch_id` (client's current branch). If a client moves branches, filtering on `c.branch_id` leaks old sessions into the wrong branch's client list.
- **`get_branch/1` doesn't exist** — only `get_branch!/1` (raises) and `get_branch_by_slug/1`. For validation in changesets, use `get_branch!` with `rescue Ecto.NoResultsError`.
- **Registration must validate branch is active**, not just that it exists. `foreign_key_constraint` only checks FK integrity — it doesn't validate business rules like `active == true`. Use a custom `validate_branch_active` changeset helper.

## Timezone Awareness

- **Never use `Time.utc_now()` or `Date.utc_today()` for display logic.** The app is configured for Asia/Beirut timezone. Use `DateTime.now("Asia/Beirut")` for any time calculations shown to users (now-lines, date comparisons in templates, etc.).
- **`DateTime.now/1` requires tzdata.** Without the `tzdata` dependency and `config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase`, named timezone lookups fail with `{:error, :utc_only_time_zone_database}`. Always add `tzdata` to deps when using named timezones.
- **Graceful fallback:** When `DateTime.now("Asia/Beirut")` fails (e.g., test env without tzdata), fall back to `Time.utc_now()` rather than crashing.

## IntersectionObserver / Scroll Hooks

- **Never use boolean toggle events from IntersectionObserver.** An observer that fires `toggle_calendar` when an element leaves viewport creates an infinite loop: collapse → scroll → re-expand → scroll → collapse. Use one-directional events (e.g., `collapse_calendar` that only sets `false`, with a separate `expand_calendar` that only sets `true`).

## Cross-View Session Lookup

- **When session data exists in multiple assigns (day_sessions, week_sessions), lookup must search all of them.** A click handler that only searches one map will silently fail for sessions in the other. Use a unified `find_session_by_id` that handles both flat (`%{hour => [sessions]}`) and nested (`%{date => %{hour => [sessions]}}`) map structures.

## HEEx / Template Interpolation

- **Elixir string interpolation `#{...}` does NOT work inside HEEx `<script>` tags.** HEEx renders `<script>` content as literal text — the `#{}` is not evaluated. Use `{raw(...)}` with an Elixir function that returns the interpolated string (e.g., `Jason.encode!` for JSON-LD), or use `<%=` in a `.ex` template (not `.heex`).
- **`raw/1` is required when injecting pre-rendered HTML/JSON into HEEx.** Without it, the content gets HTML-escaped (e.g., quotes become `&quot;`).
- **`og:url`, `canonical`, and attribute interpolation `{...}` work fine in HEEx** — the issue is only with text content inside `<script>` blocks.

## Plug / Redirects

- **`conn.request_path` does NOT include `conn.query_string`.** When building redirect URLs, always check if `conn.query_string` is non-empty and append `"?" <> conn.query_string`. Otherwise UTM params and other query strings are silently dropped on redirect.
- **Always test `init/1` for Plugs** — it may have default-fetching logic (e.g., reading from Application config) that should be verified independently.

## Elixir Pattern Matching

- **`Date.from_iso8601/1` returns `{:error, reason}`, not `:error`.** Pattern matching on `:error` will never match. Always use `{:error, _}`.

## Socket Assigns vs Module Attributes

- **Compile-time constants (color maps, ranges) should be module attributes, not socket assigns.** Socket assigns are for runtime data that changes per request. Moving static maps to `@module_attr` avoids unnecessary assigns and template `@` references. Use helper functions (e.g., `heat_color_for_level/1`) for template access to module attributes.

## Layout / SEO / PWA

- **Every layout must have `og:image`, `canonical`, and PWA meta tags** (manifest, apple-touch-icon, apple-mobile-web-app-capable). Missing any of these breaks social sharing previews or mobile "Add to Home Screen". Compare with root layout before shipping a new layout.
- **`twitter:card` must be consistent across layouts.** Use `summary_large_image` for sharing/link-in-bio pages — the large card is always better for pages designed to be shared.
- **Extract duplicated inline SVGs to function components.** When the same SVG icon appears in multiple places in a template, extract it to a shared function component (e.g., `Layouts.whatsapp_icon/1`) with a `class` attr for sizing/styling. Avoids maintenance burden and keeps templates DRY.

## Dead Code in Date Calculations

- **`Date.beginning_of_week` on a value that's already the beginning of the week is a no-op.** Same for `Date.end_of_week` on a value computed from `beginning_of_week + 6`. Remove unnecessary recalculations.

## Schedule Redesign — Month Grid + Day Rail (PR #87)

- **`select_date` must sync `current_month`** when clicking a padding day from another month. Without this, the month grid doesn't navigate to show the selected date. Check `date.month != current_month.month or date.year != current_month.year` and update `current_month` accordingly.
- **`compute_day_stats` available hours must intersect with display range (6..21).** If a trainer's availability starts at 5 AM, counting `end_h - start_h` inflates the open count. Use `MapSet.intersection` with the display range to only count visible hours.
- **Never use `Date.utc_today()` for display logic** — use `DateTime.now("Asia/Beirut")` with fallback. Store as `local_today` assign for template access. This prevents the now-line and today-highlight from being 3 hours off between midnight and 3 AM Beirut time.
- **Now-line position should use percentage, not hardcoded pixel row height.** Use `(minutes_from_6am / 960) * 100%` instead of `minutes / 60 * 58px`. This is robust regardless of row height changes.
- **Move hardcoded inline styles to CSS classes.** Hex colors in inline styles are hard to maintain and override. Use semantic CSS classes (e.g., `schedule-accent-bar-confirmed`, `schedule-now-line-dot`) and keep inline styles only for truly dynamic values (heat-map background colors from data).
- **Flash messages need auto-dismiss** — use a `phx-hook` (`FlashAutoDismiss`) that hides the element after 5 seconds. The hook requires an `id` attribute on the element.
- **`phx-hook` requires an `id` attribute** on the element. Without it, Phoenix LiveView raises a parse error.
- **Remove unused helper functions** — `status_badge_styles`, `session_accent_color`, `day_text_style` etc. became dead code after moving to CSS classes. `mix compile --warnings-as-errors` catches these.
- **Test for cross-month date selection** — verify that clicking a padding day from another month updates the month navigation header.
- **Test for availability intersection with display range** — verify that hours outside 6..21 don't inflate the open count.
