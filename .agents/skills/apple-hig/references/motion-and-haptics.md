# Apple HIG Motion & Haptics Reference

Apple interfaces feel physical, continuous, and alive because their animations are grounded in real-world spring physics rather than mechanical linear transitions.

---

## 1. Physics-Based Spring Animations

In Apple HIG, motion is not a canned linear or cubic bezier duration. It is driven by **mass, stiffness, and damping**:

- **Natural & Velocity-Aware**: When a user drags or flings an element (like a sheet or card), the release velocity carries forward into the animation trajectory.
- **Interruptible**: Any running animation can be redirected mid-flight without snapping or jarring pauses if the user touches the screen again.
- **Damping Ratios**:
  - **Critically Damped (ratio ≈ 1.0)**: Smoothly glides into place without any bounce or oscillation. Standard for navigation transitions, modal presentation, and list reflows.
  - **Slight Under-damping (ratio ≈ 0.85 – 0.9)**: Subtle organic overshoot that settles immediately. Reserved for micro-interactions (e.g., button press rebound or chip toggle).

### Flutter Implementation:
```dart
// Apple-style critically damped spring simulation
class AppleMotion {
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration standardDuration = Duration(milliseconds: 320);
  static const Duration modalDuration = Duration(milliseconds: 450);

  // Curves closely modeling Apple's smooth spring deceleration
  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve responsiveSpring = Curves.easeOutQuad;
  static const Curve sheetSpring = Cubic(0.2, 0.9, 0.3, 1.0);
}
```

---

## 2. Purposeful Motion Principles

1. **Clarify Hierarchy**: When opening a dossier or detail view, the tapped card should visually expand from its origin into the new view, keeping spatial orientation clear.
2. **Provide Immediate Sensory Feedback**:
   - Tapping an action button scales the container down slightly (`0.98`) and reduces opacity (`0.85`), returning immediately on release.
   - Toggling a switch slides with subtle weight rather than jumping instantaneously.
3. **Never Obstruct Workflow**: Animations must never force the user to wait. Controls remain interactive, and progress animations operate asynchronously.

---

## 3. Accessibility: Reduce Motion

Always respect the system accessibility setting:
- If `prefers-reduced-motion` is active (or `MediaQuery.of(context).disableAnimations` is true), replace sliding spatial transitions with a gentle **cross-fade** (`opacity` fade of 150ms) to prevent motion sickness.

```dart
Widget buildAccessibleTransition({
  required BuildContext context,
  required Widget child,
  required Animation<double> animation,
}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  if (reduceMotion) {
    return FadeTransition(opacity: animation, child: child);
  }
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .chain(CurveTween(curve: AppleMotion.sheetSpring))
        .animate(animation),
    child: FadeTransition(opacity: animation, child: child),
  );
}
```

---

## 4. Multi-Modal Haptic Patterns

Haptics reinforce physical confidence in digital actions:
- **Selection**: Light tactile tick on picking an option from a wheel or segmented tab.
- **Impact (Light / Medium / Heavy)**: Fired when physical collision occurs (e.g., dropping a card into a column).
- **Notification (Success / Warning / Error)**:
  - Success: Rapid double-tap confirmation on flight scheduling or proposal approval.
  - Warning: Resonant pulse on encountering an edit lease contention.
  - Error: Triple vibration buzz on network dispatch timeout.

