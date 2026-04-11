# QA Process

## Overview

QA is automated via the browser tool. No manual testing required from Zaher.

After every merge to main (auto-deploys to Fly.io), the agent runs QA checks
using the browser tool with desktop and mobile viewports.

## When QA Runs

1. **Per-issue QA** — after each PR merge + deploy
2. **Pre-release QA** — full regression before public launch
3. **Ad-hoc QA** — when Zaher asks "check X"

## QA Tools

- **Browser tool** — navigate, click, type, screenshot
- **Mobile simulation** — 375×812 viewport (iPhone X)
- **Desktop simulation** — 1280×720 viewport
- **Screenshots** — visual verification at each step
- **Console logs** — catch JS errors

## QA Flow Per Issue

1. Wait for deploy to complete (~2 min after merge)
2. Run the relevant QA checklist section (see below)
3. Test on mobile viewport first, then desktop
4. Log any bugs as GitHub issues with `qa` label
5. Report results to Zaher

## Viewport Sizes

| Device | Width | Height |
|--------|-------|--------|
| Mobile (iPhone X) | 375 | 812 |
| Tablet (iPad) | 768 | 1024 |
| Desktop | 1280 | 720 |

## Test Accounts

| Role | Phone | Password |
|------|-------|----------|
| Admin | (from seeds) | password123 |
| Trainer | (from seeds) | password123 |
| Client | (from seeds) | password123 |

## QA Checklist

### Public Pages

- [ ] Landing page loads
- [ ] About section renders
- [ ] Packages section shows pricing
- [ ] Locations section shows branches
- [ ] Mobile: navigation works (hamburger menu)
- [ ] Mobile: all sections readable without horizontal scroll

### Client Flow

- [ ] Registration: phone → verify → password
- [ ] Login
- [ ] View available packages
- [ ] Book a session
- [ ] View upcoming sessions
- [ ] View session history
- [ ] Progress tracking page loads
- [ ] Mobile: all forms usable (no tiny inputs, buttons tappable)

### Trainer Flow

- [ ] Login
- [ ] View schedule/calendar
- [ ] View assigned sessions
- [ ] Mark session as completed
- [ ] View client list
- [ ] Progress tracking: read/write client progress
- [ ] Mobile: calendar view usable

### Admin Flow

- [ ] Login → dashboard loads
- [ ] User management: list, filter
- [ ] Trainer approval workflow
- [ ] Package assignment
- [ ] Calendar view: sessions visible
- [ ] Assign trainer to session
- [ ] Branch management (CRUD)
- [ ] Mobile: dashboard stats readable
- [ ] Mobile: admin tables scroll or stack properly

### Cross-Cutting Checks

- [ ] No JS console errors on any page
- [ ] All navigation links work (no 404s)
- [ ] Logout works
- [ ] Unauthorized access redirects to login
- [ ] Back button works correctly
- [ ] Flash messages display and disappear

## Bug Tracking

Bugs found during QA are created as GitHub issues:
- Label: `qa`
- Include: page, viewport, steps to reproduce, screenshot

## Reporting

After QA, send a summary to Zaher:
- ✅ What passed
- 🐛 What failed (with issue links)
- 📱 Any mobile-specific issues
