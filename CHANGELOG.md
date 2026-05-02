# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.5] - 2026-05-02

### Added
- Opening hours section on landing page (Mon–Fri 6 AM–10 PM, Sat 6 AM–2 PM, Sun Closed)
- "Visit Our Website" link on `/links` page (links to site root)

### Changed
- Opening hours copy: "Both" → "All branches"
- Removed bottom note from opening hours section

## [0.8.4] - 2026-05-02

### Added
- Link-in-bio page at `/links` — mobile-first "linktree" style page for Instagram/social sharing
  - React logo and slogan
  - Location buttons linking to Google Maps (Horsh Tabet, Jal El Dib)
  - WhatsApp "Chat with us" button with branch picker modal
  - Instagram icon with follow link
  - Standalone layout (no nav bar or footer)

## [0.8.3] - 2026-05-01

### Changed
- Reduce to 1 photo per branch (Horsh Tabet: kettlebell press, Jal El Dib: stretching)
- Fix mobile auto-scroll to packages section — use scrollLeft instead of scrollIntoView

## [0.8.2] - 2026-05-01

### Changed
- Replace Horsh Tabet branch photos with new training photos (kettlebell press + trap bar row)

## [0.8.1] - 2026-05-01

### Changed
- Replace em dashes with more natural punctuation on landing page (#109)
  - Hero: period split instead of dash
  - 100% Personal section: comma flow instead of dash
  - Ready to Start section: colon instead of dash
- Standard package card: "Flexible scheduling" instead of "Priority booking" (#109)

## [0.8.0] - 2026-04-30

### Added
- Real location photos for both branches on landing page (#95)
  - Horsh Tabet: wide interior shot + cable cross / REACT logo wall
  - Jal El Dib: stretching duo + trainer coaching client
  - Responsive srcset (400w/800w/1200w WebP) with lazy loading
  - Proper alt text for accessibility

## [0.7.0] - 2026-04-30

### Added
- Testimonial carousel with 5 real member reviews (#94, #103)
  - Auto-rotation every 5 seconds
  - Navigation dots with ARIA tablist pattern
  - Keyboard navigation (ArrowLeft/ArrowRight) with circular wrapping
  - Swipe support on touch devices
  - Progressive enhancement: first testimonial visible without JS
  - Accessibility: `aria-roledescription="carousel"`, slide roles, live region

### Changed
- WhatsApp deep links now include pre-filled message: "Hello, can you tell me more about the service you provide at React?" (#94, #103)
  - Applies to all WhatsApp links: hero CTA modal, locations section, footer
- WhatsApp pre-filled message text refined for natural conversation starter

## [0.6.0] - 2026-04-29

### Changed
- Landing page branches are now static (no database query) (#96)
  - Horsh Tabet: Clover Park 4th floor, +961 70 379 764
  - Jal El Dib: Main Street, +961 71 633 970
- All CTA buttons now open a branch selector modal → WhatsApp (#93)
  - "Start Your Journey", "Explore Our Packages", "Get Started", "Get In Touch" all trigger the modal
  - Users pick a branch → opens WhatsApp chat for that location
- Phone numbers in locations section are WhatsApp deep links
- Removed operating hours display from landing page
- Get Directions uses Google Maps search URLs (no coordinates needed)
- Footer branch links now go to WhatsApp instead of anchor links

### Removed
- `format_operating_hours/1` and related helpers from `PageHTML` (unused after removing operating hours)

## [0.5.0] - 2026-04-29

### Changed
- Landing page release: hide auth routes, trainer section, and portal access (#92, #98, #101)
  - Auth routes (`/users/register`, `/users/log-in`) redirect to `/`
  - Trainer section removed from landing page
  - Client/trainer/admin portals accessible but not linked from landing page
- All CTA buttons converted to WhatsApp deep links (#93)
- Phone numbers in locations section link to WhatsApp chat (#97)
- Facebook icon removed from footer (no Facebook page)
- Hero CTAs now anchor to `#packages` and `#contact` sections
- Footer quick links updated: added Packages, removed Trainers
- 29 auth-related tests excluded with `landing_page_auth` tag

### Fixed
- Mobile navbar gap on notched devices (iPhone X+) (#99, #101)
  - Added `viewport-fit=cover` meta tag
  - Safe area padding via CSS utility classes (`pt-safe-top`, `pb-safe-bottom`, `pb-safe-24`, `pb-safe-20`)
  - Bottom nav now accounts for `safe-area-inset-bottom` on notched devices

## [0.4.1] - 2026-04-19

### Fixed
- Mobile bottom nav active tab not updating on LiveView navigation (#90)
  - Changed JS hook to listen for `phx:page-loading-stop` instead of `phx:navigated`
  - `phx:navigated` only fires for `<.link navigate>` links, but bottom nav uses `<.link href>` (redirect-style)
  - Now active state correctly updates on every navigation, including browser back/forward

## [0.4.0] - 2026-04-19

### Added
- Trainer schedule redesign with month grid + hourly day rail for mobile (#86)
- Heat-map density circles on month grid (5 levels, busier = redder)
- Scroll-triggered collapse: month grid collapses into week strip with "Expand ∨" link
- Hourly day rail (6 AM–10 PM) with session cards and open slot cards
- Session cards with 4px left accent bar (red confirmed, amber pending, gray cancelled)
- Status badge pills: CONFIRMED, PENDING, CANCELLED with color-coded styles
- Open slot cards with dashed border and red `+` button (placeholder for #85)
- Stats row: booked · pending · open counts
- Now-line indicator at current time
- Heat-map legend with gradient indicator
- Month navigation with `<` `>` chevrons
- Day selection on month grid loads hourly rail for that day
- `ScheduleCollapse` JS hook with IntersectionObserver for scroll-triggered collapse
- `count_sessions_per_day_for_trainer/4` in Scheduling context for heat-map data
- Flash message container in schedule LiveView

### Changed
- Mobile schedule view completely redesigned from single-day list to month grid + hourly rail
- Desktop 7-day weekly grid unchanged
- Calendar navigation uses month-based instead of week-based on mobile
- Tests updated to use `set_trainer_availability` instead of `time_slot_fixture`

## [0.3.0] - 2026-04-19

### Added
- Glass bottom navigation bar for mobile clients — frosted glass effect, 5-tab layout with pulse FAB for booking (#79, #80, #84)
- Horizontal wordmark logos for navbar, hero, and footer sections (#82)
- Trainer/admin bottom navigation bar with role-specific tabs
- `aria-label` on all navigation tabs for accessibility
- LiveView `navigate` links for SPA-style page transitions (no full reloads)
- Role-specific body padding: `pb-24` for client, `pb-20` for trainer/admin
- iOS safe area support via `env(safe-area-inset-bottom)` on mobile nav
- Pulse animation on booking FAB (plays 3 times then stops)

### Changed
- Replaced old R-icon + "REACT" text with horizontal wordmark SVGs across all layouts
- Removed unused logo assets (20 → 8 files kept)
- Tab label font size increased to 11px for better mobile readability

### Fixed
- Bottom content no longer hidden behind fixed mobile nav bar
- Active tab indicator now uses DaisyUI `text-primary` / `text-base-content` tokens (theme-aware)

## [0.2.1] - 2026-04-12

### Fixed
- Google Maps directions link was double-encoding `query=` parameter, breaking the URL (#78)

## [0.2.0] - 2026-04-12

### Added
- Landing page "Our Locations" section — dynamic branch cards with address, phone, hours, and Google Maps directions (#69)
  - Replaces hardcoded Contact section with DB-driven branch display
  - `format_operating_hours/1` helper groups consecutive days with identical hours
  - Trainer cards show branch badge (red pill)
  - Footer branch names link to #locations section
- Admin branch management + dashboard branch selector (#67)
- Client & trainer views scoped to branch (#68)
- Branches system — multi-location gym support (#65)
  - `branches` table with name, slug, address, capacity, phone, coordinates, operating hours
  - CRUD context (`GymStudio.Branches`) with slug-based lookups
  - Slug is immutable after creation (prevents broken URLs)
  - Unique index on slug for fast lookups
  - Active/inactive branch filtering
  - Seed data: React — Sin El Fil branch
- Admin calendar: nil guard for sessions outside current week view
- Calendar tests: navigate to correct week dynamically

### Added
- Initial Phoenix 1.8 application setup
- User authentication system with email/password and magic links (phx.gen.auth)
- User roles: client, trainer, admin
- Phone number requirement for all users
- Trainer profiles with approval workflow (pending → approved → suspended)
- Client profiles with health notes and emergency contacts
- Session packages system (8, 12, 20 sessions)
  - Admin package assignment
  - Session usage tracking
  - Expiration management
- Training session booking system
  - Client booking requests (pending status)
  - Admin/trainer approval with trainer assignment
  - Session completion and cancellation flows
  - Time slots management
- In-app notification system
  - Real-time notifications via PubSub
  - Booking confirmations, cancellations, reminders
  - Package assignment notifications
  - Trainer approval notifications
- Black & red brand theme (DaisyUI)
- PostgreSQL database configuration with Docker Compose
- Oban for background job processing
- Swoosh for email delivery
- Tailwind CSS with DaisyUI for styling
- Basic telemetry and LiveDashboard integration

### Infrastructure
- Docker Compose configuration for local PostgreSQL
- Project structure for fly.io deployment
