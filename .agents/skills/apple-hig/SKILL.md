---
name: apple-hig
description: "Master design skill implementing Apple Human Interface Guidelines (HIG). Non-negotiable principles, dynamic typography, 8pt spacing grid, materials & translucency, 44pt touch targets, and visual hierarchy for crafting world-class, premium UI."
version: 1.0.0
---

# Apple Human Interface Guidelines (HIG) Skill

This skill enforces Apple's Human Interface Guidelines as the non-negotiable standard for user interface architecture, visual design, typography, spacing, component hierarchy, and material physics.

---

## 1. The Core Non-Negotiable Pillars

Every screen built under Apple HIG must satisfy Apple's five foundational design principles:

1. **Purpose**: Design with singular clarity. Every screen has one dominant intention. Do not clutter the interface with extraneous cards or secondary gadgets.
2. **Agency**: Users remain in control. Provide immediate, visible confirmation for user actions, clear undo paths, and seamless progressive disclosure.
3. **Familiarity**: Rely on standard digital and physical paradigms. Standard row-based grouped lists, natural reading order, native controls, and intuitive gestures.
4. **Responsibility & Honesty**: Never display internal engineering jargon, requirement tags (e.g. `[FR-08]`), database lock syntax (e.g. `[SKIP LOCKED]`), or synthetic metrics. Present real user outcomes in human language.
5. **Flexibility & Accessibility**: All typography scales gracefully (Dynamic Type). High-contrast legibility (minimum 4.5:1 body, 3:1 large text/controls). Minimum touch target of **44x44pt**.

---

## 2. Layout & The 8-Point Spatial Grid

Apple HIG interfaces are organized on a strict **8-point spatial system** (with 4-point micro-increments):

| Token | Dimension | Use Case |
| :--- | :--- | :--- |
| `space-xxs` | **4 pt** | Micro-spacing between icon and tight badge label, hairline offsets |
| `space-xs` | **8 pt** | Gap between related label and body text, horizontal button icon gap |
| `space-sm` | **12 pt** | Compact list item vertical padding, secondary margin gaps |
| `space-md` | **16 pt** | Standard screen edge margin on mobile, standard card padding |
| `space-lg` | **24 pt** | Gap between distinct content groups, section separation |
| `space-xl` | **32 pt** | Major section rhythm, header to content separation |
| `space-xxl` | **48 pt** | Hero breathing room, dramatic editorial spacing |

### Layout Rules:
- **No Container Monotony**: Never wrap every single data point in a bordered floating card ("card inside a card"). Use **Grouped Table / Inset List layouts** with subtle separator lines (`0.5pt`) where content is presented in calm, scannable rows.
- **Reading Order**: Top-to-bottom, leading-to-trailing hierarchy. Large titles anchor the view, followed by primary data, then secondary details.
- **Screen Margin Safe Areas**: In mobile viewports, enforce a minimum 16pt margin from the display edge.

---

## 3. Typography & Dynamic Type Scale

Use **SF Pro** (or platform equivalent sans-serif / editorial serif pairing) respecting Apple's optical size boundary:
- **SF Pro Text**: Sizes **under 20 pt** (optimized for tracking, legibility, and high-density reading).
- **SF Pro Display**: Sizes **20 pt and above** (optimized for tight negative tracking, brand confidence, and headline presence).

### Canonical Apple HIG Type Scale:

| Style | Size | Weight | Tracking (pt) | Line Height (pt) | Role |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Large Title** | 34 pt | Bold | `-1.05` | 41 pt | Primary view hero title |
| **Title 1** | 28 pt | Bold / Semibold | `-0.80` | 34 pt | Major section header |
| **Title 2** | 22 pt | Bold / Semibold | `-0.70` | 28 pt | Card / Group title |
| **Title 3** | 20 pt | Semibold | `-0.60` | 25 pt | Sub-section header |
| **Headline** | 17 pt | Semibold | `-0.43` | 22 pt | Emphasized row / item title |
| **Body** | 17 pt | Regular | `-0.43` | 22 pt | Default running copy |
| **Callout** | 16 pt | Regular | `-0.32` | 20 pt | Highlighted excerpt |
| **Subhead** | 15 pt | Regular / Medium| `0.00` | 19 pt | Metadata subtitle |
| **Footnote** | 13 pt | Regular | `+0.03` | 16 pt | Secondary timestamps, author tags |
| **Caption 1** | 12 pt | Regular / Medium| `+0.12` | 15 pt | Compact labels, badge text |
| **Caption 2** | 11 pt | Regular / Medium| `+0.15` | 14 pt | Minimum legible subtext |

### Tabular Figures:
Financial, time, and numeric telemetry (e.g. `$14,500.00`, `4.8% CTR`, `00:04:12`) must always use **tabular numbers** (`FontFeature.tabularFigures()`) to prevent character jitter and maintain columnar alignment.

---

## 4. Materials, Translucency & Continuous Curvature

Apple surfaces feel physical and tactile through materials and continuous curves:

### Squircles (Continuous Curvature):
Never use sharp or generic geometric corners. Apple interfaces use **smooth continuous curvature**:
- **Controls & Buttons**: `8 pt` to `10 pt` radius.
- **Grouped Cards & Cells**: `12 pt` to `14 pt` radius.
- **Modal Sheets & Large Containers**: `16 pt` to `20 pt` radius.

### Dual-Layer Ambient Depth:
Replace hard 1px wireframe borders with Apple's ambient lighting elevation:
```dart
boxShadow: const [
  BoxShadow(
    color: Color(0x08000000), // 3% black ambient occlusion
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
  BoxShadow(
    color: Color(0x0C000000), // 5% black key light
    blurRadius: 16,
    offset: Offset(0, 6),
  ),
]
```

### Translucent Materials:
Navigation bars, toolbars, and floating action decks use frosted glass (`BackdropFilter` with `sigmaX: 16, sigmaY: 16` and semi-opaque surface tint) so underlying content peeks through softly as the user scrolls.

---

## 5. Controls, Buttons & Touch Targets

1. **44x44 pt Minimum Touch Region**:
   Every clickable element (icons, chips, switches, buttons) must occupy at least 44x44pt of accessible hit area, even if the visible graphic is smaller.
2. **Button Hierarchy**:
   - **Prominent Filled Button**: Reserved for the **single primary action** of the screen (e.g. `[Commit Schedule]`, `[Approve Version]`).
   - **Tonal / Tinted Button**: Secondary actions (`[Add Flight]`, `[Duplicate]`).
   - **Bordered / Plain Text Button**: Tertiary actions (`[Cancel]`, `[Dismiss]`).
3. **Press States**:
   Every interactive element must provide immediate feedback on touch (opacity shift to `0.7` or subtle scale down to `0.98`), reassuring the user that the tap was registered.

---

## 6. Semantic Color System

| Apple Token | Light Hex | Semantic Meaning |
| :--- | :--- | :--- |
| `systemBackground` | `#F2F2F7` | Grouped canvas background |
| `secondarySystemBackground` | `#FFFFFF` | Grouped card / row surface |
| `tertiarySystemBackground` | `#E5E5EA` | Sub-level well or search input |
| `label` | `#000000` (88%) | High-contrast primary text |
| `secondaryLabel` | `#3C3C43` (60%) | Muted supporting descriptions |
| `tertiaryLabel` | `#3C3C43` (30%) | Timestamps, placeholders |
| `separator` | `#3C3C43` (20%) | Subtle hairline dividers |
| `systemBlue` | `#007AFF` | Primary interactive accent |
| `systemGreen` | `#34C759` | Success / Approved / Growth |
| `systemOrange` | `#FF9500` | Pacing alert / In review |
| `systemRed` | `#FF3B30` | Destructive / Failed / Rejected |

---

## 7. Anti-Patterns & "AI Slop" Prohibitions

1. **BAN Technical Jargon on Screens**: Never print `[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`, or database locking parameters in user interfaces.
2. **BAN Card Inception**: Never put a card inside a card inside a card. Use whitespace and 0.5pt dividers instead of nested bordered boxes.
3. **BAN Middle-Dot Soup**: Avoid strings like `Jane · Social · v1 · $10k · Oct 20`. Place metadata in clean columns or key-value rows.
4. **BAN Non-Responsive Buttons**: Never render a button that lacks a pressed state or accessible touch padding.
5. **BAN Generic Stock Placeholders**: Creative previews must simulate real-world formats (e.g., social feed ads with avatars and action pills, or billboards with 16:9 cinematic framing).

---

## 8. Verification Checklist Before Handing Back Code

- [ ] Does every text style match the SF Pro / Dynamic Type scale (exact size, weight, tracking)?
- [ ] Are all margins and padding multiples of the 8pt spatial grid (4, 8, 12, 16, 24, 32)?
- [ ] Do all interactive elements have at least 44x44pt hit targets?
- [ ] Is technical engineering jargon absent from user-facing screens?
- [ ] Are numbers and metrics rendered with tabular figures?
- [ ] Do elevated surfaces use subtle dual-layer ambient shadows rather than harsh flat borders?
- [ ] Is there only **one** prominent filled primary button per screen context?
