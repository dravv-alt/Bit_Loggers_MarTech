# Apple HIG Inclusion & Right-to-Left (RTL) Reference

Software designed according to Apple standards must be welcoming, culturally respectful, and functionally effortless for people worldwide, regardless of language, script direction, culture, or background.

---

## 1. Global Inclusion & Linguistic Elasticity

1. **Text Expansion Budgeting**:
   - English is concise. When translated into German, French, or Spanish, text length frequently expands by **30% to 50%**.
   - In Asian languages (Japanese, Korean, Chinese), glyphs are vertically denser and require increased line heights.
   - **Rule**: Never fix the width or height of containers holding localizable strings. Use dynamic wrapping, auto-sizing text, and flexible flexbox containers.
2. **Culturally Neutral Metaphors**:
   - Avoid idioms, regional slang, or culturally specific sports metaphors (*"hit it out of the park"*, *"drop the ball"*).
   - Use direct, universally understood operational terms (*"Launch Campaign"*, *"Review Metrics"*, *"Resolve Alert"*).

---

## 2. Right-to-Left (RTL) Layout Mirroring (Arabic, Hebrew, Persian)

When an RTL locale is active, the entire spatial model and reading order mirrors horizontally across the vertical axis:

| UI Component | LTR (English / Western) | RTL (Arabic / Hebrew) |
| :--- | :--- | :--- |
| **Reading Origin** | Top-Left | Top-Right |
| **Navigation Back Button** | Top-Left (`< Back`) | Top-Right (`Back >`) |
| **Table Row Primary Label** | Left-aligned | Right-aligned |
| **Table Row Accessory Chevron** | Trailing right edge (`>`) | Trailing left edge (`<`) |
| **Progress Bars & Sliders** | Fills Left-to-Right | Fills Right-to-Right (Right is zero) |
| **Metrics & KPI Columns** | Label Left, Number Right | Label Right, Number Left |

### Flutter Implementation:
Use `Directionality` aware widgets like `EdgeInsetsDirectional` rather than hardcoded `EdgeInsets.only(left: ...)`:
```dart
// ✅ Correct HIG RTL-Adaptive Spacing:
Padding(
  padding: EdgeInsetsDirectional.only(
    start: 16.0, // Maps to Left in LTR, Right in RTL
    end: 12.0,   // Maps to Right in LTR, Left in RTL
  ),
  child: Text(title, textAlign: TextAlign.start),
)
```

---

## 3. Directional vs. Non-Directional Icons

Not all icons should mirror in RTL environments:

### 🔄 Icons that MUST Flip in RTL:
- Navigation chevrons (`chevron_right` -> `chevron_left`)
- Forward and back directional arrows
- Text alignment icons (align leading, align trailing)
- Bulleted list markers
- Undo and redo arrows
- Search bar leading search icon (moves to leading right)

### ⏹️ Icons that MUST NOT Flip in RTL:
- **Clocks and Timers**: Analog hands move clockwise in all cultures.
- **Media Controls**: Play (`▶`), Pause (`❚❚`), Fast-Forward (`▶▶`) follow global standard convention.
- **Physical Hardware Icons**: Cameras, mobile phones, keyboards, headphones.
- **Checkmarks & Crosses**: Checkmarks (`✓`) and close badges (`✕`) do not mirror.
- **Battery & Signal Gauges**: Standard system meters remain fixed.

---

## 4. Bidirectional Mixed Text & Formats

- When displaying campaign identifiers (e.g. `CG-9021`), email addresses (`support@campaigngrid.com`), or currency strings (`$1,250.00`) inside RTL sentences, enclose them in Unicode directional isolate markers (`\u2066` ... `\u2069`) to prevent punctuation scrambling.
- Always respect the user's localized date format (e.g., `DD/MM/YYYY` vs `MM/DD/YYYY` vs Japanese imperial calendar).

