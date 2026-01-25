# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
