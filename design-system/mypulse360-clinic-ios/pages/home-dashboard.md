# Home Dashboard — Page Overrides

> **PROJECT:** MyPulse360 Clinic iOS — patient app
> **Screen:** `lib/features/health_dashboard/presentation/pages/dashboard_page.dart`
> **Page Type:** Native dashboard (scanned, not read)

> ⚠️ Rules here **override** `design-system/mypulse360-clinic-ios/MASTER.md`.
> Only deviations are documented; everything else follows the Master.

> The generator's default output for this page was a web landing-page skeleton
> (1200px max width, hero → benefits → CTA → footer, "certificate carousel").
> None of that applies to a 393pt native dashboard; it is replaced below.

---

## Layout — one question answered per band

The dashboard is scanned. Each horizontal band answers a single question, in the
order a patient actually asks them. Bands are ordered by that, not by data source.

| # | Band | Question it answers |
|---|------|--------------------|
| 1 | Greeting + date + bell | Who am I, and when is it |
| 2 | Two hero action cards | The two things people open the app to do |
| 3 | Next appointment (glass) | The single most important fact |
| 4 | Snapshot stat tiles ×3 | Am I doing alright |
| 5 | Wellness insights | What should I know |
| 6 | Health tips strip | What could I learn |
| 7 | Tab bar (5 items) | Where else can I go |

- Screen gutter **20pt**. Sibling card gap **9pt**. Section header 22 above / 10 below.
- Scroll content is inset at the bottom so nothing hides behind the tab bar.

## Component Overrides

- **Hero action pair** — 2-up grid, 11pt gap, min height 118pt.
  - *Book appointment*: slate fill (`AppColors.inkBlack`), white text — the heavier
    of the two, because it is the primary job.
  - *Prescriptions*: sage surface, ink text.
  - Both carry **live state** in the subtitle ("2 ready to collect", "Next opening
    today, 14:00") so the tap is informed rather than exploratory.
  - Glyphs are `IconData` at 20pt in a 36pt rounded tile. **Not emoji** — the
    current build passes `emoji: '📅'` / `'💊'` to `_HeroActionCard`; that
    parameter should become an `IconData`.
- **Next appointment** — the *one* glass surface on this screen. Date, time and
  queue number are chips, not a text run, so they survive Dynamic Type without
  reflowing the card.
- **Stat tiles** — tabular numerals, a sparkline for trend, and a **word** for
  status. BMI reads "Normal" in text; green alone is not the signal.
- **Bell** — carries a dot, never a count. A number here invites anxiety.
- **Tab bar** — 5 items max, 48pt tall, label always visible. Active tab is sage
  **and** bold, so state does not rest on colour.

## Colour Overrides

- No new values. Sage appears exactly twice on this screen: the Prescriptions
  card surface and the active tab. There is **no sage button** here — the hero
  cards are navigation, not commits.

## Motion Overrides

- Cards do not animate in on scroll. This screen is opened to be read, and a
  staggered reveal delays the one fact the patient came for.

## Outstanding

- `Semantics` labels for the stat tiles ("Resting heart rate, 68 beats per minute").
- Stat tiles must collapse 3-across → 2-across before clipping at the largest
  Dynamic Type sizes.
