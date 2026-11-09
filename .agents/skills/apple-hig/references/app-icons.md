# Apple HIG App Icons Reference

Your app icon is the visual signature of your application across the App Store, Home Screen, Dock, Settings, Search, and Notification sheets.

---

## 1. Core Principles: Simplicity, Clarity & Focus

1. **Singular Focal Point**: Choose one simple, iconic motif that directly conveys the core purpose of the app. Avoid cramming multiple concepts or complex narratives into a tiny canvas.
2. **Never Include UI Elements or Text**: Do not render miniature UI screens, buttons, charts, or unnecessary product names. Let the icon be purely graphical.
3. **No Artificial Borders or Pre-Rendered Shadows (iOS/iPadOS)**: 
   - Never clip corners or draw a pre-baked drop shadow around the border on iOS/iPadOS. The system automatically applies the proprietary continuous-curvature squircle mask and lighting elevation.
   - Design assets as full-bleed, edge-to-edge square artwork.
4. **macOS Distinct Icon Geometry**: 
   - Unlike iOS full-bleed squares, macOS app icons have a physical rounded rectangular card shape (using the standard Apple macOS squircle template) with a subtle ambient drop shadow baked inside the 1024x1024 canvas, or a distinctive lifelike utility object with realistic materials and perspective.

---

## 2. Multi-Layer Structure & iOS 18 Dynamic Appearances

Modern Apple platforms support dynamic icon rendering across **Light**, **Dark**, and **Tinted** system configurations:

1. **Light Appearance**: Standard vibrant color palette with realistic materials, specular highlights, and natural depth.
2. **Dark Appearance**: Uses rich, deep neutral background tones (dark graphite, charcoal, or deep obsidian `#1C1C1E`) with vibrant or luminescent foreground symbols to ensure high contrast without glaring in dark environments.
3. **Tinted Appearance**: Automatically converts the icon into a duotone asset where the user-selected system tint color is applied to foreground glyphs over a dark translucent backdrop.
4. **Layer Separation**:
   - **Background Layer**: Full-bleed 1024x1024 background texture or gradient.
   - **Foreground / Symbol Layer**: Transparent cutout of the primary glyph or emblem, optically centered.

---

## 3. Optical Alignment & The Apple Icon Grid

Human visual perception perceives curved or circular shapes as smaller than sharp-cornered squares of identical geometric dimensions. To maintain optical equilibrium:

| Shape Geometry | Recommended Bounding Box (1024 Canvas) | Optical Compensation |
| :--- | :--- | :--- |
| **Full-Bleed Background** | `1024 x 1024 px` | Fills corner-to-corner |
| **Square Subject** | `684 x 684 px` | Constrained to primary square |
| **Circle / Spherical Subject** | `768 x 768 px` | ~12% larger to compensate for negative corner space |
| **Vertical Rectangle** | `616 x 768 px` | Aligned with vertical golden ratio guides |
| **Horizontal Rectangle** | `768 x 616 px` | Aligned with horizontal golden ratio guides |

---

## 4. Platform Asset Sizing Specifications

| Platform & Context | Rendered Points | Pixel Density (@2x / @3x) | Target Dimensions |
| :--- | :--- | :--- | :--- |
| **App Store (iOS / iPadOS / macOS)** | 1024 x 1024 pt | 1x (PNG, no alpha for iOS) | `1024 x 1024 px` |
| **iPhone Home Screen** | 60 x 60 pt | @3x / @2x | `180 x 180 px` / `120 x 120 px` |
| **iPhone Spotlight Search** | 40 x 40 pt | @3x / @2x | `120 x 120 px` / `80 x 80 px` |
| **iPhone Settings & Preferences** | 29 x 29 pt | @3x / @2x | `87 x 87 px` / `58 x 58 px` |
| **iPhone Notification Banners** | 20 x 20 pt | @3x / @2x | `60 x 60 px` / `40 x 40 px` |
| **iPad Pro Home Screen** | 83.5 x 83.5 pt | @2x | `167 x 167 px` |
| **iPad Home Screen** | 76 x 76 pt | @2x | `152 x 152 px` |
| **macOS Dock** | 512 x 512 pt | @2x / @1x | `1024 x 1024 px` / `512 x 512 px` |

---

## 5. Technical Requirements & Color Profile

- **Color Space**: Master assets must be exported in **Display P3** (wide color gamut) or **sRGB**. Display P3 provides noticeably richer reds, emerald greens, and deep ambers on Apple OLED and Liquid Retina screens.
- **Bit Depth**: 8-bit or 16-bit per color channel RGB.
- **File Format**: Clean, uncompressed PNG without interlacing.
- **No Alpha Channel on iOS Home Screen**: The master iOS App Store icon must not contain transparent pixels (alpha = 0); the background must be completely opaque.

