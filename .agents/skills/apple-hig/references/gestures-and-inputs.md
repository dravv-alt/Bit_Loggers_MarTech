# Apple HIG Gestures & Multi-Input System Reference

Apple platform experiences support a rich spectrum of input modalities: direct touch, precision trackpads, mice, external keyboards, Apple Pencil, and game controllers. Interfaces must adapt fluidly between touch and precision pointer inputs.

---

## 1. Gestural Conventions & Mental Models

Users expect touch interactions to feel physical, direct, and immediate:

- **Tap**: Primary selection or activation. Must show instantaneous feedback (opacity drop to ~0.7 or subtle scale) within 16ms of contact.
- **Swipe / Flick**: Momentum-based navigation or paging. Respect scrolling inertia and damping.
- **Touch and Hold (Long Press)**: Reveals secondary context menus or preview cards without performing a destructive action.
- **Pinch**: Smooth continuous zoom centered precisely between touch points.
- **Edge Swipe (`< Back`)**: Swiping inward from the leading screen edge navigates backward in the view hierarchy. Never block or disable this gesture unless an uncommitted destructive form is active.

### 🚫 Non-Negotiable System Gesture Protection:
Never attach custom gesture recognizers to screen boundaries that conflict with OS-reserved gestures:
- **Bottom Edge**: iOS Home Indicator bar & App Switcher swipe.
- **Top / Top-Right Edge**: Notification Center & Control Center pull.
- **Leading / Trailing Screen Edges**: Native hierarchical navigation transitions.

---

## 2. Multi-Input Modalities: Touch, Pointer & Cursor

On iPadOS, macOS, and Desktop Web, the interface must respond gracefully to mouse and trackpad pointers:

### Pointer Visual Styles:
1. **Highlight Effect**: When hovering over tabular list rows, segmented control items, or navigation pills, a subtle translucent rounded rectangle appears behind the element.
2. **Lift Effect**: When hovering over primary buttons or floating action cards, the button subtly scales up (`1.02x`), deepens its diffuse shadow, and tracks small cursor movements.
3. **Hover States**: Always provide visual feedback when an interactive element is hovered on desktop/tablet viewports.

---

## 3. Keyboard Navigation & Accessibility Focus

1. **Logical Tab Traversal**:
   - `Tab` advances focus top-to-bottom, leading-to-trailing.
   - `Shift + Tab` reverses focus order.
   - `Space` or `Return` activates the focused control.
   - `Escape` dismisses the active modal sheet, popover, or search bar.
2. **Accessible Focus Rings**:
   - Never suppress focus rings (`outline: none` without replacement is strictly forbidden).
   - Apple focus rings are dual-layer: a 2pt vibrant accent ring separated from the control by a 1pt transparent hairline to prevent color clashing against varied backdrops.
3. **Specialized Virtual Keyboards**:
   - When requesting emails: specify `TextInputType.emailAddress`.
   - When entering budgets, percentages, or metrics: specify `TextInputType.numberWithOptions(decimal: true)`.
   - When entering search queries: show the blue action button labeled *"Search"*.

---

## 4. Redundant Access: Never Hide Actions Behind Gestures Alone

Every critical action reachable via gesture must have a visible, accessible UI counterpart:
- If a table row can be swiped to delete, include an **Edit** mode or a trailing action menu (`...`) so VoiceOver users and users with motor impairments can perform the action without multi-directional swiping.

