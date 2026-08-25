# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/mypulse360-clinic-ios/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** MyPulse360 Clinic iOS — patient app
**Generated:** 2026-08-22 (ui-ux-pro-max `--design-system`, then hand-tuned)
**Category:** Healthcare App / Medical Clinic / Booking & Appointment App
**Design Dials:** Variance 3/10 (Centred, minimal) · Motion 3/10 (Subtle) · Density 4/10 (Standard)
**Live reference:** the token values below are applied in `lib/config/theme/`.

> **Note on generation.** The tool's default palette for this query was "calm cyan
> + health green" (`#0891B2`) and it resolved the style to *Exaggerated Minimalism*.
> Both were overridden: the palette because the brief specifies sage green + deep
> slate blue, the style because *Exaggerated Minimalism* (oversized type, luxury/
> editorial) is wrong for a clinic. The style below is the tool's own
> product-domain match for "Medical Clinic": **Accessible & Ethical + Minimalism**.

---

## Global Rules

### Colour Palette

Two families, one job each. **Sage commits, slate navigates.** Only one sage
button may appear per screen, and it is always the action that changes state on
the server.

| Role | Hex | Dart constant | Contrast |
|------|-----|---------------|----------|
| Primary / commit | `#3F6B55` | `primaryBlueFill`, `primaryGreenText` | 5.59:1 on paper · white on it 6.09:1 |
| Commit (fill variant) | `#4F7A63` | `primaryGreen` | 4.89:1 on white |
| Soft sage (decorative) | `#8AA793` | *unused in code* | **2.62:1 — never alone** |
| Sage on dark | `#A8C4AE` | `primaryGreenDark`, `primaryBlueTextDark` | 9.53:1 on `#10181F` |
| Slate / authority | `#2E4257` | `inkBlack` (hero + dark cards) | white on it 10.33:1 |
| Ink / primary text | `#1B2A38` | `darkSlate` | 13.43:1 |
| Secondary text | `#4A5C6B` | `slate` | 6.35:1 |
| Tertiary / disabled | `#6B7C8A` | `slateLight` | 3.95:1 — large / UI only |
| Paper (page ground) | `#F7F5F0` | `scaffoldLight` | — |
| Card | `#FFFFFF` | `cardLight` | — |
| Muted fill | `#EFEDE7` | `surfaceMuted` | — |
| Hairline | `#E3DED4` | `borderLight` | 1.23:1 — decorative only |
| Caution | `#8A5A12` text / `#B4761A` fill | `amberText` / `amber` | 5.43:1 |
| Danger | `#B3261E` | `rose`, `red` | 6.00:1 · white on it 6.54:1 |
| Info | `#3E5163` text / `#4F6579` fill | `tealText` / `teal` | 8.2:1 |
| Clinician role accent | `#46567F` | `primaryPurple` | — |

**Dark theme:** ground `#10181F`, card `#18242D`, border `#2A3A45`, primary text
`#E9EEEA` (15.25:1), secondary `#A7B8BD` (8.73:1).

**Rules**
1. **Sage commits, slate navigates.** A patient who learns this once never mis-taps.
2. **Soft sage `#8AA793` is decoration.** 2.62:1 — it cannot carry meaning alone.
   Always beside a word or number saying the same thing.
3. **Paper, not white.** Cards are brighter than the ground, so a floating card is
   legible by its own value shift before any shadow is drawn.

### Typography

- **UI font:** Figtree (`GoogleFonts.figtreeTextTheme()`) — humanist, tall x-height,
  survives Dynamic Type. Replaced Inter.
- **Data font:** IBM Plex Mono (`AppTypography.mono`) — anything a patient might
  read aloud to a nurse: queue numbers, dosages, timestamps, step counters.

| Role | Size / line | Weight | Tracking |
|------|-------------|--------|----------|
| Display | 28 / 1.1 | 800 | -3% |
| Greeting | 25 / 1.15 | 800 | -3% |
| Nav title | 16.5 | 700 | -1% |
| Card title | 15 | 700 | -1.5% |
| Section header | 15 | 700 | 0 |
| Body | 13.5 / 1.5 | 400 | 0 |
| Caption | 12 | 400 | 0 |
| Data label (mono) | 10.5 | 500 | +9%, uppercase |
| Numerals | tabular-nums always | 800 | -4% |

### Spacing — 4pt rhythm

`4 · 8 · 12 · 16 · 20 · 24 · 32` (`AppSpacing`)

Screen gutter 20. Card padding 14–16. Sibling card gap 9. Section headers take 22
above and 10 below — the asymmetry groups a header with its content rather than
floating it between two.

### Radius (`AppRadii`)

`sm 12` controls · `card 22` cards · `lg 24` lifted surfaces · `pill` chips and tags.
Radius rises with importance, not size. Nested corners step down by ≥4.

### Elevation (`AppShadows`)

Two levels, both tinted with the ink hue — never neutral black.

| Level | Value |
|-------|-------|
| `card` | `0 6px 16px rgba(27,42,56,.08)` + `0 1px 2px rgba(27,42,56,.05)` |
| `elevated` | `0 14px 32px rgba(27,42,56,.14)` |

### Glass

Rationed to **one card per screen** (the next appointment) plus sticky bars.
Blur 18px, saturate 1.25, **opacity floor 82%** so ink on glass never drops below
4.5:1 whatever scrolls beneath it.

---

## Motion

150–300ms, meaning only.

| Interaction | Timing |
|-------------|--------|
| Press feedback | 120ms opacity |
| Slot selection | 180ms fill + ring |
| Screen push | platform curve, untouched (`CupertinoPageTransitionsBuilder`) |
| Confirmation seal | 260ms `easeOutBack`, scale 0.9 → 1, **once** |

**Reduced motion** (`MediaQuery.disableAnimations`): seal appears at full scale,
slot fill is instant, transitions become a 100ms fade. Nothing is lost because no
state was ever communicated by movement alone.

---

## Touch & Accessibility

- 44×44pt minimum hit area, everywhere. Calendar days are 36pt visually with a
  44pt hit area via padding.
- 8pt dead space between adjacent targets, so a thumb between two slots picks neither.
- **State never rests on hue.** Booked slots are struck through *and* labelled;
  leave days struck through; the active tab goes bold as well as sage; BMI says
  "Normal" in words.
- Body text ≥4.5:1, secondary ≥3:1, in **both** themes.
- Bottom nav ≤5 items, each with a permanent text label.
- Multi-step flows show "Step N of M" with a bar.
- Safe areas respected; scroll content inset so nothing hides behind sticky bars.

---

## Anti-Patterns (Do NOT Use)

- ❌ **Emoji as icons** — use `IconData` / SVG. Font-dependent, untintable.
- ❌ **Bright neon colours** and **AI purple/pink gradients**
- ❌ **Motion-heavy animation** — decorative-only motion
- ❌ **Colour as the sole indicator** of state
- ❌ **Soft sage `#8AA793` carrying meaning on its own** (2.62:1)
- ❌ **Raw hex in widgets** — go through `AppColors` / `context.colors`
- ❌ **Low-contrast grey-on-grey**, text under 12px
- ❌ **Instant state changes** (0ms) or animations over 500ms
- ❌ **Placeholder-only labels** on form fields

---

## Pre-Delivery Checklist

- [ ] No emoji used as icons
- [ ] All icons from one family, consistent stroke (1.6px) and size tokens
- [ ] Touch targets ≥44×44pt, ≥8pt apart
- [ ] Pressed feedback within 80–150ms; press states don't shift layout
- [ ] Light **and** dark contrast checked independently
- [ ] State conveyed by more than colour
- [ ] `Semantics` labels on every slot, day cell and avatar
- [ ] Tested at 375pt wide, in landscape, and at the largest Dynamic Type size
- [ ] Reduced motion respected
- [ ] Safe areas respected; nothing hidden behind sticky bars
