# Apple HIG Typography Reference (SF Pro & Dynamic Type)

Apple interfaces derive their authority and elegance from strict adherence to the **SF Pro** type hierarchy.

## Optical Sizing: SF Pro Text vs. SF Pro Display

- **SF Pro Text (<20 pt)**: Designed with wider proportions, larger x-height, and looser tracking so that tiny words remain razor-sharp at high reading speeds.
- **SF Pro Display (>=20 pt)**: Designed with tighter tracking and proportional stroke weights to command space without looking sprawling or loose.

## Complete Dynamic Type Scale

```dart
class AppleTypography {
  // Large Title (34pt / Leading 41pt / Tracking -1.05)
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    letterSpacing: -1.05,
    fontWeight: FontWeight.w700,
  );

  // Title 1 (28pt / Leading 34pt / Tracking -0.80)
  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.80,
    fontWeight: FontWeight.w700,
  );

  // Title 2 (22pt / Leading 28pt / Tracking -0.70)
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.70,
    fontWeight: FontWeight.w600,
  );

  // Title 3 (20pt / Leading 25pt / Tracking -0.60)
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    letterSpacing: -0.60,
    fontWeight: FontWeight.w600,
  );

  // Headline (17pt / Leading 22pt / Tracking -0.43 / Semibold)
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w600,
  );

  // Body (17pt / Leading 22pt / Tracking -0.43 / Regular)
  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w400,
  );

  // Callout (16pt / Leading 20pt / Tracking -0.32)
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    height: 20 / 16,
    letterSpacing: -0.32,
    fontWeight: FontWeight.w400,
  );

  // Subhead (15pt / Leading 19pt / Tracking 0.0)
  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    height: 19 / 15,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  // Footnote (13pt / Leading 16pt / Tracking +0.03)
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    letterSpacing: 0.03,
    fontWeight: FontWeight.w400,
  );

  // Caption 1 (12pt / Leading 15pt / Tracking +0.12)
  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    height: 15 / 12,
    letterSpacing: 0.12,
    fontWeight: FontWeight.w500,
  );

  // Caption 2 (11pt / Leading 14pt / Tracking +0.15)
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.15,
    fontWeight: FontWeight.w500,
  );
}
```

## Numeric Alignment & Tabular Figures

In high-end applications, numbers that change dynamically (currency, timers, ROI metrics, percentages) must use tabular numbers to eliminate jitter:

```dart
TextStyle get tabularMetricStyle => AppleTypography.title1.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
);
```
