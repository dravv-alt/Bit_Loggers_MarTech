---
name: apple-hig
description: "Master design skill implementing Apple Human Interface Guidelines (HIG). Non-negotiable principles, dynamic typography, 8pt spacing grid, materials & translucency, 44pt touch targets, and visual hierarchy for crafting world-class, premium UI."
version: 2.0.0
---

# Apple Human Interface Guidelines (HIG) Master Skill

This skill enforces Apple's official **Human Interface Guidelines (HIG)** (`https://developer.apple.com/design/human-interface-guidelines/`) as the non-negotiable architectural standard for UI design, component structures, typography, spatial layout, material physics, and interaction patterns.

---

## 1. The Core Philosophical Pillars

Every screen must reflect Apple's foundational design benchmarks:

1. **Purpose**: Design with singular clarity. Every screen has one dominant focus. Eliminate visual clutter, extraneous cards, and distracting secondary gadgets.
2. **Agency**: Users stay in control. Every action provides immediate feedback, clear undo paths, and progressive disclosure without trapping the user.
3. **Familiarity**: Rely on established physical and digital paradigms: grouped row-based lists, natural reading order, native controls, and intuitive gestures.
4. **Responsibility & Honesty**: Never display internal engineering jargon, requirement tags (e.g. `[FR-08]`), database lock syntax (e.g. `[SKIP LOCKED]`), or fake metrics. Speak pure brand and marketing intelligence.
5. **Flexibility & Accessibility**: All typography scales gracefully (Dynamic Type). High-contrast legibility (minimum 4.5:1 body, 3:1 large text/controls). Minimum touch target of **44x44pt**.

---

## 2. Spatial System & The 8-Point Grid

All layouts, margins, padding, and gaps strictly adhere to the **8-point spatial system** (with 4-point micro-spacing):

```
4pt (Micro)  ·  8pt (Tight)  ·  12pt (Compact)  ·  16pt (Base/Margin)  ·  24pt (Group)  ·  32pt (Section)  ·  48pt (Hero)
```

### Layout Architecture:
- **No Bento-Box Monotony**: Never wrap every single data point in a bordered floating card ("card inside a card"). Use **Grouped Table / Inset List layouts** with subtle separator lines (`0.5pt`) where content is presented in calm, scannable rows.
- **Reading Order**: Top-to-bottom, leading-to-trailing visual hierarchy. Large titles anchor the view, followed by primary data, then secondary details.
- **Screen Margin Safe Areas**: In mobile viewports, enforce a minimum 16pt margin from the display edge.

---

## 3. Typography: SF Pro Optical Sizing & Tabular Numerals

Typography in Apple platforms is powered by **SF Pro** (pairing seamlessly with editorial serif accents like New York):

- **SF Pro Text (<20 pt)**: Designed with wider proportions and looser tracking for maximum legibility at small sizes.
- **SF Pro Display (≥20 pt)**: Designed with tighter negative tracking to command visual authority.

### Canonical Dynamic Type Hierarchy:
- **Large Title**: `34pt` / Bold / Tracking: `-1.05` / Line Height: `41pt`
- **Title 1**: `28pt` / Bold / Tracking: `-0.80` / Line Height: `34pt`
- **Title 2**: `22pt` / Semibold / Tracking: `-0.70` / Line Height: `28pt`
- **Title 3**: `20pt` / Semibold / Tracking: `-0.60` / Line Height: `25pt`
- **Headline**: `17pt` / Semibold / Tracking: `-0.43` / Line Height: `22pt`
- **Body**: `17pt` / Regular / Tracking: `-0.43` / Line Height: `22pt`
- **Callout**: `16pt` / Regular / Tracking: `-0.32` / Line Height: `20pt`
- **Subhead**: `15pt` / Regular / Tracking: `0.00` / Line Height: `19pt`
- **Footnote**: `13pt` / Regular / Tracking: `+0.03` / Line Height: `16pt`
- **Caption 1**: `12pt` / Medium / Tracking: `+0.12` / Line Height: `15pt`
- **Caption 2**: `11pt` / Medium / Tracking: `+0.15` / Line Height: `14pt`

> [!IMPORTANT]
> All currency figures, percentages, ROI ratios, and timestamps must use **tabular numerals** (`FontFeature.tabularFigures()`) to prevent character jitter and maintain columnar alignment.

*Detailed specifications: [`references/typography.md`](references/typography.md)*

---

## 4. Materials, Depth & Continuous Curvature

Apple surfaces feel physical and tactile through materials and continuous curves:

### Squircles (Continuous Curvature):
Never use sharp or generic geometric circular arcs. Apple interfaces use **smooth continuous curvature**:
- **Controls & Buttons**: `8 pt` to `10 pt` radius.
- **Grouped Cards & Cells**: `12 pt` to `14 pt` radius.
- **Modal Sheets & Large Containers**: `16 pt` to `20 pt` radius.

### Dual-Layer Ambient Depth:
Replace hard 1px wireframe borders with Apple's ambient lighting elevation:
```dart
boxShadow: const [
  BoxShadow(
    color: Color(0x06000000), // 2.5% black ambient occlusion
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
  BoxShadow(
    color: Color(0x0A000000), // 4.0% black soft diffuse key light
    blurRadius: 16,
    offset: Offset(0, 6),
  ),
]
```

### Translucent Materials:
Navigation bars, toolbars, and floating action decks use frosted glass (`BackdropFilter` with `sigmaX: 16, sigmaY: 16` and semi-opaque surface tint) so underlying content peeks through softly as the user scrolls.

*Detailed specifications: [`references/materials-and-elevation.md`](references/materials-and-elevation.md)*

---

## 5. Component Patterns & Modality

- **Grouped Inset Lists**: The primary content presentation pattern. Replaces walls of floating disjointed cards with unified inset groups divided by 0.5pt hairlines.
- **Button Hierarchy**:
  - **Single Prominent Filled Primary Button**: One dominant action per screen (e.g. `[Commit Schedule]`).
  - **Tonal / Tinted Buttons**: Secondary actions (e.g. `[Add Flight]`).
  - **Borderless Plain Buttons**: Tertiary actions (e.g. `[Cancel]`).
- **Sheets & Modality**: Modal sheets present focused sub-tasks. Always include clear dismissal (`Cancel` vs `Done`). Never use a `Back` button to dismiss a modal sheet.
- **Alerts**: Reserved strictly for high-severity or destructive, irreversible events. Never interrupt with informational or startup alerts.

*Detailed specifications: [`references/components.md`](references/components.md)*

---

## 6. Motion & Velocity-Aware Spring Physics

- **Critically Damped Springs**: Interfaces glide smoothly into place without artificial mechanical bounce.
- **Interruptible Transitions**: Animations can be redirected mid-flight if the user touches the screen.
- **Reduce Motion Fallbacks**: Replace sliding spatial movements with a gentle cross-fade when accessibility motion reduction is enabled.
- **Multi-Modal Haptics**: Complement significant actions with crisp haptic patterns (Selection, Impact, Notification).

*Detailed specifications: [`references/motion-and-haptics.md`](references/motion-and-haptics.md)*

---

## 7. Writing & Microcopy Standards

- **Action-Oriented Verbs**: Buttons describe explicit outcomes (*"Approve Version"*, *"Schedule Flight"*, *"Discard Draft"*).
- **Sentence Case**: All buttons, navigation titles, section headers, and table labels are set in sentence case.
- **Zero Engineering Leaks**: Eliminate backend PRD codes (`[FR-xx]`), SQL locks (`[SKIP LOCKED]`), and database implementation tags from client views.
- **Constructive Error States**: State what happened without blaming the user, and offer an immediate path forward.

*Detailed specifications: [`references/writing-and-copy.md`](references/writing-and-copy.md)*

---

## 8. Accessibility & Inclusivity

- Minimum **44x44 pt** touch target on every interactive element.
- Minimum **4.5:1** text contrast ratio against background (3.0:1 for large text and controls).
- Color independence: never convey state purely through color alone (pair colors with symbols or text).

*Detailed specifications: [`references/accessibility.md`](references/accessibility.md)*

---

## 9. The Non-Negotiable Anti-Patterns (The 7 Deadly Sins of AI Slop)

1. **Card Inception**: BANNED. Never put a card inside a card inside a card. Use whitespace and 0.5pt dividers instead of nested bordered boxes.
2. **Technical Jargon on Screens**: BANNED. Never print `[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`, or database locking parameters in client UI.
3. **Template Punctuation**: BANNED. Never string metadata together with middle dots (`A · B · C · D · E`). Use clean columnar alignment.
4. **Untracked Display Type**: BANNED. Large headlines (≥20pt) without tight negative tracking look loose and unconsidered.
5. **Jittering Numerals**: BANNED. All monetary and metric figures must declare tabular figures.
6. **Harsh Flat Wireframe Borders**: BANNED. Replace uniform 1px solid lines with Apple's dual-layer ambient lighting shadows.
7. **Button Clutter**: BANNED. Never place two prominent filled primary buttons side-by-side in the same view.

---

## Reference Library Quicklinks

- [`references/typography.md`](references/typography.md) — SF Pro & Dynamic Type matrix
- [`references/materials-and-elevation.md`](references/materials-and-elevation.md) — Squircles, shadows, and translucency
- [`references/components.md`](references/components.md) — Grouped tables, buttons, and sheets
- [`references/motion-and-haptics.md`](references/motion-and-haptics.md) — Velocity springs and haptics
- [`references/writing-and-copy.md`](references/writing-and-copy.md) — Microcopy, tone, and humanized error handling
- [`references/accessibility.md`](references/accessibility.md) — Touch targets, contrast, and VoiceOver semantics
