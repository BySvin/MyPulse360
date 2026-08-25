# Booking Flow — Page Overrides

> **PROJECT:** MyPulse360 Clinic iOS — patient app
> **Screens:** `find a doctor` → `doctor profile` →
> `appointments/presentation/pages/book_appointment_page.dart` →
> `appointments/presentation/pages/queue_number_page.dart`
> **Page Type:** Multi-step task flow

> ⚠️ Rules here **override** `design-system/mypulse360-clinic-ios/MASTER.md`.

---

## Principle — two decisions, nothing else

The patient makes exactly two choices: **who**, and **when**. Everything else the
app already knows — the clinic, the visit type from their history, and which days
the doctor is on leave. Never ask for what can be inferred.

| Step | Screen | What the patient does |
|------|--------|----------------------|
| 1 | Find a doctor | Filters. No decision committed. |
| 2 | Doctor profile | **Decision one** — who |
| 3 | Select a time | **Decision two** — when |
| 4 | Confirmed | Receives the queue number |

## Overrides

- **Step indicator is mandatory.** "Step 3 of 4" plus a segmented bar, above the
  content. The current `book_appointment_page.dart` gives no indication of
  position in the flow.
- **Commit lives in a persistent bottom bar**, not inline in the scroll. The bar
  is glass, holds the running summary ("Wed 26 Aug · 10:30") on the left and the
  single sage commit button below it. Summary before commit, always.
- **One sage button per screen.** Step 2 → "Book appointment". Step 3 → "Confirm
  booking". Steps 1 and 4 have no sage commit ("Done" on the confirmation is the
  exception — the state is already committed, so it reads as dismissal).
- **Leave is shown, never hidden.** Days the doctor is on leave stay visible in
  the calendar, struck through, and the profile screen surfaces the leave window
  as a caution card *before* the patient reaches the calendar. Silently removing
  dates makes the app look broken.

## Component Specs

### Time slot — four states, each with a non-colour signal

| State | Treatment |
|-------|-----------|
| Available | white card, 1pt `#D0C9BB` border |
| Selected | sage fill, white label, 3pt ring |
| Booked | muted fill, **struck through**, sub-label "Booked" |
| On leave | same treatment, sub-label "On leave" |

Grid is 3-across, 8pt gap, 44pt minimum height.

### Month calendar

- Cell 36pt visual / **44pt hit area** via padding.
- Availability dot (soft sage) under open days — decorative, always paired with
  the day being tappable.
- Leave days struck through, not removed.
- Today carries a 1.5pt border ring, not a fill (fill is reserved for selection).

### Confirmation

- Queue number is the payoff: 52pt tabular numerals on the slate gradient hero.
- The seal animates **once**, 260ms `easeOutBack`. Suppressed under reduced motion.
- Details list uses hairline dividers, label left / value right.

## Outstanding

- `Semantics` on every slot and day cell: "10:30, available" / "27 August, doctor
  on leave, unavailable".
- Slot grid must collapse 3-across → 2-across at the largest Dynamic Type sizes.
