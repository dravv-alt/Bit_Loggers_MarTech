# Apple HIG Accessibility & Inclusivity Reference

Apple platforms treat accessibility as a fundamental design baseline, not an afterthought or compliance checklist.

---

## 1. Contrast & Visual Legibility

Every text element, icon, and boundary must satisfy strict WCAG / Apple HIG contrast ratios:

- **Body & Headline Text**: Minimum **4.5:1** contrast ratio against its background.
- **Large Text (≥20pt / bold ≥17pt)**: Minimum **3.0:1** contrast ratio.
- **Interactive Controls & Focus Rings**: Minimum **3.0:1** contrast against adjacent canvas colors.
- **Color Independence**: Never use color as the sole indicator of state or status. Always accompany colors with an icon, text label, or numeric indicator (e.g. green checkmark + *"Approved"*, amber alert icon + *"In Review"*, red badge + *"Rejected"*).

---

## 2. Dynamic Type Compliance

1. Interfaces must scale seamlessly when users adjust their system text size preferences.
2. Layouts must never clip or truncate text when scaled up. Use flexible containers, `minHeight`, and scrollable wrappers rather than fixed container heights (`height: 48` on a container holding variable text is an anti-pattern).

---

## 3. Touch Targets (44 x 44 pt Minimum)

Every tappable control (buttons, icons, chips, checkboxes, disclosure chevrons) must provide at least **44x44pt** of accessible hit area:

```dart
Widget buildAppleTouchTarget({
  required Widget child,
  required VoidCallback onTap,
  BorderRadius? borderRadius,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(child: child),
      ),
    ),
  );
}
```

---

## 4. Semantic Hierarchy & Assistive Technology (VoiceOver)

- Group related labels together into a single semantic unit so screen readers don't read disjointed fragments.
- Use explicit labels on image assets and icons (`tooltip` or `Semantics(label: ...)`).
- Decorative icons and background images must declare `excludeFromSemantics: true` to avoid cluttering screen readers with visual noise.
