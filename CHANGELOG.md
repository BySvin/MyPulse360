# Changelog

All notable changes to this project will be documented in this file. This provides a running log of recent major iterations and a foundation for tracking future updates.

## [Recent Changes - Last 8 Days]

### 🚀 Features
- **Database (Supabase Backend):**
  - Added Supabase backend design spec and database foundation plan.
  - Implemented identity tables, RLS helpers, policies, and doctor directory.
  - Created appointments schema with double-booking prevention.
  - Added booking, reschedule, and queue-position RPCs.
  - Added prescriptions, items, interactions, and safety lookup.
  - Introduced health metrics, goals, and progress tracking with RLS.
  - Developed pharmacy inventory with FEFO dispensing.
  - Added scheduling tables, leave/attendance RPCs, and `available_slots`.
  - Added chat conversations and messages schema.
  - Seeded clinics, demo accounts, availability, and inventory data.
  - Added month availability feature so calendar data costs only one call.
- **Authentication:**
  - Integrated `supabase_flutter` client and added a mock-mode switch.
  - Added sign-in against Supabase with role and active checks.
  - Implemented patient sign-up with server-side doctor assignment.
  - Added `create-staff-account` edge function and `set_account_active` RPC.
  - Allowed restoring a persisted Supabase session on launch.
- **Appointments & Patient Profile:**
  - Mapped appointment, slot, and patient rows to entities.
  - Added functionality to read appointments and availability from Postgres.
  - Enabled reading and updating the patient profile from Postgres.
  - Allowed booking and rescheduling through database RPCs.
- **Theme:**
  - Rethemed application to the sage-and-slate design system.

### 🐛 Bug Fixes
- **Database:**
  - Restricted self-update to non-authority columns.
  - Closed INSERT-time doctor self-assignment vulnerability.
  - Failed loudly when a concurrent dispense leaves pharmacy stock short.
  - Fixed unwinnable `available_slots` column assertion and updated to `OUT` parameters.
  - Scoped staff unavailability reads and anchored leave dates to UTC.
  - Revoked write and truncate privileges from anonymous users.
  - Closed prescription-forgery security hole.
  - Scoped doctor-initiated assignment to their own clinic.
  - Read clinic opening hours in the clinic's timezone instead of UTC.
- **Authentication:**
  - Tore down the session on every refused login.
  - Ensured patient registration is an atomic server-side RPC.
  - Surfaced edge function errors and cleared the password gate.
  - Prevented a failed profile fetch from stranding the user.
  - Let auth pages survive submit and unblocked patient onboarding.
- **Appointments:**
  - Stopped rendering unloaded appointment data as a positive statement.
  - Handled write failures at three previously unguarded booking call sites.
  - Ordered appointments correctly in ascending order.
  - Stopped treating an unsettled `AsyncValue` as a negative answer.
- **Router:**
  - De-flaked the errored-profile redirect assertion.

### 🛠 Refactoring & Chores
- **Refactoring:**
  - Made profile lookups async behind a provider.
  - Dropped the unused `AsyncInlineText` widget.
  - Made appointment reads async and the queue live.
- **Chores:**
  - Regenerated plugin registrants for `supabase_flutter`.
  - Untracked the generated Gradle problems report.
  - Declared `http` as a dev dependency and dropped transitive imports.
- **Testing:**
  - Asserted cross-tenant isolation and RPC invariants.
  - Ensured other patients had real data to make isolation tests bite.
  - Guarded the splash gate against session restore race conditions.
  - Asserted the GoTrue token columns are never NULL.
  - Proved a month costs one request instead of 31 requests.

### 📝 Documentation
- Updated various design specs, plans, and tracking files (Plan 01, 02, 03).
- Added a demo guide and an honest project status report (`PROJECT-STATUS.md`).
- Added a Judges Q&A and recorded the end-to-end run results and review defects.

---

## Format Guidelines for Future Updates

To keep this log neat, categorize your new commits and changes under the following headers when making updates:

- **🚀 Features:** New capabilities, pages, and components.
- **🐛 Bug Fixes:** Resolving issues, crashes, or unintended behaviors.
- **🛠 Refactoring & Chores:** Structural code changes without changing external behavior, or maintenance tasks.
- **📝 Documentation:** Changes to `README.md`, PRD, or inside the `docs/` folder.
- **🧪 Testing:** New unit, widget, or integration tests.
