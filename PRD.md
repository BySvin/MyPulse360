# MyPulse360 — Product Requirements Document

## 1. Overview

MyPulse360 is a healthcare coordination app connecting patients with a clinic's
doctors and pharmacists. It ships as a single Flutter codebase with two
experiences from one build: a **mobile app** for patients, and a **web
dashboard** for clinic staff. The two are differentiated at runtime (platform
+ role), not by separate deployments.

**Current implementation stage:** functional prototype. All business logic
(auth, booking, queueing, prescriptions, inventory) is real and enforced in
code, but the "backend" is an in-memory mock (`MockDatabase`) with no network
layer or persistent storage beyond session identity. See [§9](#9-known-gaps--out-of-scope) for what a production build still needs.

## 2. Goals

- Let patients self-register, manage their health profile, and handle the
  full appointment lifecycle without staff intervention.
- Give clinic staff (doctors, pharmacists) a web dashboard scoped tightly to
  their responsibilities, with no ability for unauthorized roles to
  self-provision.
- Keep patient-facing and staff-facing surfaces on separate platforms
  (mobile vs. web) as a deliberate access-control boundary, not just a layout
  choice.
- Personalize the patient experience (BMI, wellness insights, goal tracking)
  from data the patient explicitly provides.

## 3. Roles & Personas

| Role | Surface | Self-registration? | Notes |
|---|---|---|---|
| **Patient** | Mobile app (native iOS/Android/desktop-as-mobile) | Yes, freely | Only role with open signup |
| **Doctor** | Web dashboard | No — provisioned by another doctor | Also carries the "admin" capability (staff provisioning) |
| **Pharmacist** | Web dashboard | No — provisioned by a doctor | |

**Not implemented today:** nurse, receptionist, and a standalone
administrator role distinct from "doctor." If these are needed, they require
new `UserRole` values and dedicated nav/permission scaffolding — this PRD
does not assume they already exist anywhere in the code.

## 4. Functional Requirements

### 4.1 Authentication & Access Control

- **Patient signup** is mobile-only and always creates a `patient` account —
  no code path accepts a role parameter from the signup form. On web, the
  signup screen is replaced with a message directing users to the mobile
  app.
- **Login** verifies a salted, hashed password (SHA-256 + per-user salt)
  against the stored credential — not just an email lookup.
- **Platform + role gate**: a doctor/pharmacist account is refused login on
  native mobile builds ("sign in through the web dashboard"); patients are
  not restricted from web.
- **Account status**: deactivated accounts are refused login regardless of
  password correctness.
- **Generic failure messaging**: unknown email and wrong password return the
  identical "Invalid email or password" error, preventing account
  enumeration.
- **Forced password rotation**: any staff account created by a doctor is
  flagged `mustChangePassword` and is routed to a mandatory "set a new
  password" screen before reaching any dashboard content.
- **Session persistence**: current user id persisted via Hive; full user
  record re-hydrated from the mock store on relaunch.

### 4.2 Staff Provisioning (Doctor-as-Admin)

- Only an existing doctor can create a Doctor or Pharmacist account, via
  **Staff Management** on the web dashboard (name, email, role, temporary
  password).
- New accounts start `isActive: true`, `mustChangePassword: true`.
- Any doctor can deactivate/reactivate any staff account except their own
  (self-lockout prevention).
- There is no "request access" or self-service staff signup flow anywhere.

### 4.3 Patient — Onboarding

1. Sign up (name, email, password).
2. **Wellness Goals** — select from Exercise, Hydration, Sleep, Diet.
3. **Health Profile Setup**:
   - Required: height (cm), weight (kg).
   - Optional: date of birth, gender, blood type (A+/A-/B+/B-/AB+/AB-/O+/O-/Unknown),
     existing conditions (Diabetes, High Blood Pressure, Asthma, Heart
     Condition, None, Other + free text).
   - Optional fields are genuinely nullable — skipped means absent, not a
     placeholder value.
4. Lands on the Home dashboard.

All Health Profile fields remain editable at any time from Profile → Health
Profile.

### 4.4 Patient — Mobile App

Bottom navigation (6 tabs): **Home · Appointments · Queue · AI Chat ·
Prescriptions · Profile**.

- **Home**: greeting, Book Appointment / Prescriptions quick actions, BMI +
  rule-based Wellness Insights (derived from BMI category, logged
  conditions, and weekly goal completion), Health Tips carousel, weekly
  goals progress, next-appointment banner.
- **Appointments**: book (month calendar + time-slot grid, standard or
  custom appointment type), view Upcoming/Past, reschedule.
- **Queue**: live position and estimated wait for today's visit, auto-
  refreshing. Other patients in the queue are shown anonymized ("Patient
  N"); only the signed-in patient sees their own identity.
- **AI Chat**: conversational health assistant with quick-reply prompts.
  *Currently rule-based/mock — not a connected LLM.*
- **Prescriptions**: view prescriptions and dispense status.
- **Profile**: personal info, full health profile editor, wellness goals,
  dark mode, notifications toggle, sign out, delete account.

### 4.5 Doctor — Web Dashboard

- **Dashboard**: today's queue, stat cards (confirmed / pending /
  completed), 30+-minute wait alerts, per-patient "Start Visit."
- **Patient history is view-only** — vitals, allergies, current
  medications, past consultations, existing prescriptions. There is no
  consultation-authoring form.
- The only doctor action on a visit is **"Send to Pharmacy"**: an optional
  free-text medication note that marks the visit seen and hands it to the
  pharmacist, who enters the formal prescription.
- **Staff Management**: see §4.2.

### 4.6 Pharmacist — Web Dashboard

- **Queue**: today's patients awaiting service.
- **New Rx**: converts a doctor's "sent to pharmacy" note into a formal
  e-prescription.
- **Inventory**: stock levels with low-stock highlighting, restock existing
  items, register new medications ("Custom Medicine Restock").
- **Verification**: a checklist step before a prescription is marked
  dispensed.

## 5. Non-Functional Requirements

- **Security**: no plaintext password storage or transmission in app code;
  role/platform checks enforced at the data-source layer, not just hidden in
  UI; account-enumeration-resistant error messages.
- **Responsiveness**: staff web dashboard adapts between a desktop sidebar
  layout (≥900px) and a mobile bottom-tab fallback at the same breakpoint
  used elsewhere in the app.
- **Consistency**: one design system (warm cream/orange/black patient
  theme, purple clinician accent) and one Cupertino-flavored interaction
  model (native-feeling transitions, swipe-back, alert dialogs) across both
  surfaces.

## 6. Data Model (Core Entities)

| Entity | Key Fields |
|---|---|
| `AppUser` | id, email, fullName, role, clinicId, isActive, mustChangePassword |
| `PatientProfile` | id, heightCm, weightKg, allergies[], chronicConditions[], currentMedications[], assignedDoctorId, dateOfBirth?, gender?, bloodType?, bmi (derived), bmiCategory (derived), age (derived) |
| `WellnessGoal` | id, patientId, type, targetValue, currentValue, unit, status, targetDate |
| `Appointment` | id, patientId, doctorId, scheduledAt, status, appointmentType, reasonForVisit? |
| `Consultation` | id, appointmentId, patientId, doctorId, status, notes?, diagnosis? |
| `Prescription` | id, patientId, doctorId, status, medications |
| `InventoryItem` | id, pharmacyId, medicationName, strength, form, currentStock, reorderLevel, unitCost, expiryDate |

## 7. Key User Flows

**Patient books and completes a visit:**
Book Appointment → confirmed → Queue tab shows live position on the day →
Doctor starts visit (views history, sends medication note to pharmacy) →
Pharmacist creates prescription → Patient sees it under Prescriptions.

**New staff member onboarding:**
Doctor opens Staff Management → creates account with temp password →
new hire logs into web dashboard → forced password reset → reaches their
role's dashboard.

**Patient personalization loop:**
Health Profile Setup (or a later Profile edit) → BMI + Wellness Insights
recompute on the dashboard automatically, no manual refresh step.

## 8. Success Metrics (suggested — not currently instrumented)

- Time-to-first-booked-appointment after signup.
- % of patients completing optional Health Profile fields.
- Average queue wait accuracy (estimated vs. actual).
- Staff account provisioning time (doctor request → active login).

## 9. Known Gaps / Out of Scope

Explicitly **not** built today — do not assume otherwise when scoping new
work against this PRD:

- Nurse and receptionist roles.
- A standalone administrator role separate from "doctor."
- A real backend/API/database — everything resets on relaunch; the mock
  layer is a behaviorally faithful prototype, not production infrastructure.
- A connected LLM behind AI Chat (currently rule-based responses).
- Push notifications, SMS/email reminders, payment/billing, insurance
  claims processing.
- Multi-clinic support (single `clinicId` seeded throughout).

## 10. Open Questions

- Should nurse/receptionist roles be added, and with what permission
  boundaries relative to doctor/pharmacist?
- Does production need a real backend (e.g. Supabase/Postgres) before
  further feature work, given the mock layer currently *is* the source of
  truth for every rule described above?
- Should AI Chat be connected to a real model, and if so, what data should
  it be allowed to read (profile, history, prescriptions)?
