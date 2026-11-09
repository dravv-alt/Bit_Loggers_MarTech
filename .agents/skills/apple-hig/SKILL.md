---
name: apple-hig
description: "Master design skill implementing Apple Human Interface Guidelines (HIG) Foundations. Non-negotiable principles, dynamic typography, 8pt spacing grid, materials & translucency, 44pt touch targets, app icons, color systems, dark mode, gestures, images, inclusion & RTL, and microcopy."
version: 3.0.0
---

# Apple Human Interface Guidelines (HIG) Master Foundations Skill

This skill enforces Apple's official **Human Interface Guidelines (HIG) Foundations** (`https://developer.apple.com/design/human-interface-guidelines/foundations`) as the non-negotiable architectural standard for all user interface design, visual styles, component structures, typography, spatial layout, material physics, and interaction patterns across this repository.

---

## The 15 Apple HIG Foundations Master Index

| # | Apple HIG Foundation Topic | Reference Module | Status |
| :---: | :--- | :--- | :---: |
| 1 | **Accessibility** | [`references/accessibility.md`](references/accessibility.md) | ✅ Complete |
| 2 | **App Icons** | [`references/app-icons.md`](references/app-icons.md) | ✅ Complete |
| 3 | **Branding** | [`references/branding.md`](references/branding.md) | ✅ Complete |
| 4 | **Color** | [`references/color-and-dark-mode.md`](references/color-and-dark-mode.md) | ✅ Complete |
| 5 | **Dark Mode** | [`references/color-and-dark-mode.md`](references/color-and-dark-mode.md) | ✅ Complete |
| 6 | **Design Principles** | Section 1 below | ✅ Complete |
| 7 | **Gestures** | [`references/gestures-and-inputs.md`](references/gestures-and-inputs.md) | ✅ Complete |
| 8 | **Images** | [`references/images.md`](references/images.md) | ✅ Complete |
| 9 | **Inclusion** | [`references/inclusion-and-rtl.md`](references/inclusion-and-rtl.md) | ✅ Complete |
| 10 | **Inputs** | [`references/gestures-and-inputs.md`](references/gestures-and-inputs.md) | ✅ Complete |
| 11 | **Layout** | Section 2 below | ✅ Complete |
| 12 | **Materials** | [`references/materials-and-elevation.md`](references/materials-and-elevation.md) | ✅ Complete |
| 13 | **Motion** | [`references/motion-and-haptics.md`](references/motion-and-haptics.md) | ✅ Complete |
| 14 | **Right-to-Left (RTL)** | [`references/inclusion-and-rtl.md`](references/inclusion-and-rtl.md) | ✅ Complete |
| 15 | **Typography** | [`references/typography.md`](references/typography.md) | ✅ Complete |
| 16 | **Writing** | [`references/writing-and-copy.md`](references/writing-and-copy.md) | ✅ Complete |

---

## 1. Philosophical Pillars (HIG Design Principles)

Every screen and interaction must reflect Apple's foundational design benchmarks:

1. **Purpose**: Design with singular clarity. Every screen has one dominant focus. Eliminate visual clutter, extraneous cards, and distracting secondary gadgets.
2. **Agency**: Users stay in control. Every action provides immediate feedback, clear undo paths, and progressive disclosure without trapping the user.
3. **Familiarity**: Rely on established physical and digital paradigms: grouped row-based lists, natural reading order, native controls, and intuitive gestures.
4. **Responsibility & Honesty**: Never display internal engineering jargon, requirement tags (e.g. `[FR-08]`), database lock syntax (e.g. `[SKIP LOCKED]`), or fake metrics. Speak pure brand and marketing intelligence.
5. **Flexibility & Accessibility**: All typography scales gracefully (Dynamic Type). High-contrast legibility (minimum 4.5:1 body, 3:1 large text/controls). Minimum touch target of **44x44pt**.

---

## 2. Spatial System & The 8-Point Grid (HIG Layout)

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

## 5. Color Architecture & Dark Mode Luminance Ladder

- **Semantic Color Roles**: Always use semantic roles (`Label`, `SecondaryLabel`, `SystemBackground`, `SecondaryGroupedBackground`, `Separator`) rather than hardcoded hex values.
- **Dark Mode Elevation Ladder**: In Dark Mode, depth is communicated by luminance (the higher the z-index, the lighter the gray: `#000000` -> `#1C1C1E` -> `#2C2C2E` -> `#3A3A3C`).
- **Color Independence**: Never rely on color alone to indicate state; always pair color with a symbol or text label.

*Detailed specifications: [`references/color-and-dark-mode.md`](references/color-and-dark-mode.md)*

---

## 6. App Icons & Multi-Layer System

- **Singular Focus**: One simple, iconic motif that communicates the core app identity. No UI screenshots, miniature buttons, or text.
- **iOS 18 Multi-Layer Appearances**: Separate background, midground, and foreground layers to support Light, Dark, and Tinted system appearances seamlessly.
- **No Pre-Rendered Borders or Shadows**: iOS applies squircle clipping and elevation dynamically. Assets are delivered full-bleed 1024x1024.

*Detailed specifications: [`references/app-icons.md`](references/app-icons.md)*

---

## 7. Branding & Voice Restraint

- **Never Hijack Navigation**: Keep top navigation titles clean for user context; avoid persistent giant corporate logos in navigation bars.
- **Accent Restraint**: Use the brand accent color strictly for key interactive affordances, not for solid backgrounds.
- **Blameless Professional Tone**: Speak like an intelligent human collaborator.

*Detailed specifications: [`references/branding.md`](references/branding.md)*

---

## 8. Gestures, Pointers & Multi-Input System

- **Direct Touch Manipulation**: Minimum 44x44pt hit targets with immediate tap feedback.
- **Protect System Gestures**: Never place custom gestures along screen edges that interfere with the Home Bar, App Switcher, or Control Center.
- **Pointer Effects**: Support Highlight and Lift effects on trackpad/mouse hover. Full keyboard navigation with accessible focus rings.

*Detailed specifications: [`references/gestures-and-inputs.md`](references/gestures-and-inputs.md)*

---

## 9. Images & Visual Assets

- **Density Assets**: Deliver assets at `@2x` and `@3x` for Retina/Super Retina displays; use vector SVG/PDF for icons.
- **Aspect Ratio Integrity**: Zero stretching or distortion (`BoxFit.cover` or `BoxFit.contain`).
- **Display P3**: Export marketing creatives in Display P3 wide color gamut.
- **Layout Stability**: Reserve layout dimensions with skeleton shimmer placeholders to prevent layout shift.

*Detailed specifications: [`references/images.md`](references/images.md)*

---

## 10. Inclusion & Right-to-Left (RTL) Mirroring

- **Horizontal Mirroring**: In RTL locales (Arabic, Hebrew), the entire layout mirrors horizontally (origin at top right, chevrons flip, sliders fill right-to-left).
- **Directional vs Fixed Glyphs**: Flip navigation arrows and chevrons; keep clocks, media controls, and checkmarks non-flipped.
- **Dynamic Text Expansion**: Allow 30% to 50% flex in containers for localized text expansion.

*Detailed specifications: [`references/inclusion-and-rtl.md`](references/inclusion-and-rtl.md)*

---

## 11. Motion & Velocity-Aware Spring Physics

- **Critically Damped Springs**: Interfaces glide smoothly into place without artificial mechanical bounce.
- **Interruptible Transitions**: Animations can be redirected mid-flight if the user touches the screen.
- **Reduce Motion Fallbacks**: Replace sliding spatial movements with a gentle cross-fade when accessibility motion reduction is enabled.
- **Multi-Modal Haptics**: Complement significant actions with crisp haptic patterns (Selection, Impact, Notification).

*Detailed specifications: [`references/motion-and-haptics.md`](references/motion-and-haptics.md)*

---

## 12. Writing & Microcopy Standards

- **Action-Oriented Verbs**: Buttons describe explicit outcomes (*"Approve Version"*, *"Schedule Flight"*, *"Discard Draft"*).
- **Sentence Case**: All buttons, navigation titles, section headers, and table labels are set in sentence case.
- **Zero Engineering Leaks**: Eliminate backend PRD codes (`[FR-xx]`), SQL locks (`[SKIP LOCKED]`), and database implementation tags from client views.
- **Constructive Error States**: State what happened without blaming the user, and offer an immediate path forward.

*Detailed specifications: [`references/writing-and-copy.md`](references/writing-and-copy.md)*

---

## 13. Accessibility & Inclusivity

- Minimum **44x44 pt** touch target on every interactive element.
- Minimum **4.5:1** text contrast ratio against background (3.0:1 for large text and controls).
- Color independence: never convey state purely through color alone (pair colors with symbols or text).

*Detailed specifications: [`references/accessibility.md`](references/accessibility.md)*

---

## The 7 Non-Negotiable Anti-Patterns (The 7 Deadly Sins of AI Slop)

1. **Card Inception**: BANNED. Never put a card inside a card inside a card. Use whitespace and 0.5pt dividers instead of nested bordered boxes.
2. **Technical Jargon on Screens**: BANNED. Never print `[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`, or database locking parameters in client UI.
3. **Template Punctuation**: BANNED. Never string metadata together with middle dots (`A · B · C · D · E`). Use clean columnar alignment.
4. **Untracked Display Type**: BANNED. Large headlines (≥20pt) without tight negative tracking look loose and unconsidered.
5. **Jittering Numerals**: BANNED. All monetary and metric figures must declare tabular figures.
6. **Harsh Flat Wireframe Borders**: BANNED. Replace uniform 1px solid lines with Apple's dual-layer ambient lighting shadows.
7. **Button Clutter**: BANNED. Never place two prominent filled primary buttons side-by-side in the same view.

---

## Complete Reference Library Quicklinks

- [`references/accessibility.md`](references/accessibility.md) — VoiceOver, contrast ratios, and touch targets
- [`references/app-icons.md`](references/app-icons.md) — Multi-layer icon geometry, squircle grid, and iOS 18 dynamic appearances
- [`references/branding.md`](references/branding.md) — Brand identity, accent restraint, and content-first hierarchy
- [`references/color-and-dark-mode.md`](references/color-and-dark-mode.md) — Semantic color system, Dark Mode elevation ladder, and contrast
- [`references/components.md`](references/components.md) — Grouped tables, button hierarchy, and modal sheets
- [`references/gestures-and-inputs.md`](references/gestures-and-inputs.md) — Multi-touch gestures, pointer hover effects, and keyboard navigation
- [`references/images.md`](references/images.md) — Density scaling (@2x/@3x), Display P3 wide gamut, and skeleton loaders
- [`references/inclusion-and-rtl.md`](references/inclusion-and-rtl.md) — Right-to-Left (RTL) mirroring, directional glyphs, and text expansion
- [`references/materials-and-elevation.md`](references/materials-and-elevation.md) — Squircles, ambient dual-layer depth, and translucency
- [`references/motion-and-haptics.md`](references/motion-and-haptics.md) — Velocity spring physics and multi-modal haptics
- [`references/typography.md`](references/typography.md) — SF Pro optical sizing matrix and tabular numerals
- [`references/writing-and-copy.md`](references/writing-and-copy.md) — Human microcopy, tone of voice, and error recovery
