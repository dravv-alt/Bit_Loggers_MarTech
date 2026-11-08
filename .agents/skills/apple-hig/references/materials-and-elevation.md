# Apple HIG Materials & Elevation Reference

Apple interfaces replace harsh 1px borders and heavy flat boxes with **subtle ambient depth, materials, and organic curvature**.

## 1. Continuous Curvature (Squircles)

In Apple platforms, corners do not follow geometric circular arcs (which create visible corner "bumps"). Instead, Apple uses **continuous curvature**:
- **Controls & Small Chips**: `8 pt` – `10 pt`
- **Standard Grouped Rows & Cards**: `12 pt` – `14 pt`
- **Modal Sheets, Dialogs & Large Panels**: `16 pt` – `20 pt`

In Flutter, standard `BorderRadius.circular(12)` paired with a soft hairline or dual shadow creates a close approximation.

---

## 2. Dual-Layer Ambient Depth

Real physical objects cast two distinct shadows: a tight ambient occlusion shadow at the contact point, and a soft, diffused key light shadow:

```dart
class AppleElevation {
  // Low elevation for resting cards and grouped list containers
  static const List<BoxShadow> restingCard = [
    BoxShadow(
      color: Color(0x06000000), // 2.5% black tight contact shadow
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% black ambient diffuse shadow
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // Medium elevation for hovering or dragging elements
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // High elevation for modal sheets and popovers
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
}
```

---

## 3. Translucency & Frosted Materials

Navigation headers, bottom action bars, and modal sheets float over underlying scrollable content.

```dart
Widget buildFrostedHeader({required Widget child}) {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withOpacity(0.82), // Soft translucency
          border: const Border(
            bottom: BorderSide(color: Color(0x1F000000), width: 0.5), // 0.5pt hairline
          ),
        ),
        child: child,
      ),
    ),
  );
}
```
