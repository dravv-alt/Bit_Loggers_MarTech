# Apple HIG Color & Dark Mode Architecture Reference

Apple platforms treat color not as static decoration, but as a dynamic semantic communication system that responds fluidly to environmental lighting, user preferences, and accessibility settings.

---

## 1. The Dynamic Semantic Color System

Never hardcode arbitrary hex colors for standard UI components. Apple interfaces rely on **semantic color roles** that automatically resolve to appropriate values across Light and Dark appearances:

### Content & Label Hierarchy:
| Semantic Role | Light Mode Value | Dark Mode Value | Usage |
| :--- | :--- | :--- | :--- |
| **Label (Primary)** | `#000000` (100% Black) | `#FFFFFF` (100% White) | Primary headlines, prominent numbers, titles |
| **Secondary Label** | `rgba(60, 60, 67, 0.60)` | `rgba(235, 235, 245, 0.60)` | Subtitles, metadata, timestamps, units |
| **Tertiary Label** | `rgba(60, 60, 67, 0.30)` | `rgba(235, 235, 245, 0.30)` | Placeholder text, inactive icons, subtle hints |
| **Quaternary Label** | `rgba(60, 60, 67, 0.18)` | `rgba(235, 235, 245, 0.18)` | Hairline dividers, subtle watermarks |

### Surface & Canvas Hierarchy:
| Semantic Role | Light Mode Value | Dark Mode Value | Usage |
| :--- | :--- | :--- | :--- |
| **System Background** | `#FFFFFF` | `#000000` (True OLED Black) | Base canvas of full-screen standard views |
| **Secondary Background** | `#F2F2F7` | `#1C1C1E` (Dark Graphite) | Grouped table row cells, search fields |
| **Tertiary Background** | `#FFFFFF` | `#2C2C2E` (Elevated Gray) | Popovers, modal sheets, dropdown menus |
| **Grouped Background** | `#F2F2F7` | `#000000` | Background canvas behind grouped inset lists |
| **Separator** | `rgba(60, 60, 67, 0.29)` | `rgba(84, 84, 88, 0.65)` | 0.5pt hairline dividers between table rows |

---

## 2. Dark Mode: The Ambient Elevation Ladder

In Dark Mode, visual depth is conveyed by **luminance elevation**, not by heavy drop shadows:

- **The Higher the Z-Index, the Lighter the Gray**:
  1. **Base Screen Level (Z=0)**: `#000000` (Deep black).
  2. **Grouped Card / Table Cell (Z=1)**: `#1C1C1E` (Luminance +11%).
  3. **Modal Sheet / Card Popover (Z=2)**: `#2C2C2E` (Luminance +17%).
  4. **Floating Action Menu / Alert (Z=3)**: `#3A3A3C` (Luminance +23%).
- **Never Invert Arbitrarily**: Dark Mode is an intentional, handcrafted dark palette—not a mathematical color inversion. A white document sheet does not become pure black text on a white card; it becomes an elevated dark gray card with white typography.

---

## 3. High Contrast & Accessibility Ratios

- **WCAG Compliance**:
  - Regular body text and subheads must achieve at least **4.5:1** contrast against adjacent backgrounds.
  - Large titles (≥20pt or bold ≥17pt) must achieve at least **3.0:1** contrast.
- **Increased Contrast Mode**:
  - When the user enables the system setting *"Increase Contrast"*, semantic labels darken in Light Mode and brighten in Dark Mode, while separator lines thicken or become more opaque to sharpen visual boundaries.

---

## 4. Semantic Tinting & Color Independence

Apple platforms use color intentionally to indicate state, but never rely on it alone:

| State | Apple System Semantic Tint | Paired Affirmative Indicator |
| :--- | :--- | :--- |
| **Success / Approved** | Apple System Green (`#34C759`) | Checkmark icon (`✓`) + Clear text label |
| **Warning / In Review** | Apple System Orange (`#FF9500`) | Alert triangle (`⚠`) + Status text |
| **Destructive / Error** | Apple System Red (`#FF3B30`) | Exclamation badge (`!`) + Explanatory error |
| **Active / Informative** | Apple System Blue (`#007AFF`) | Solid filled pill or highlighted glyph |

