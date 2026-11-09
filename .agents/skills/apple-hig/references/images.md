# Apple HIG Images, Assets & Visual Media Reference

Visual media in Apple interfaces must look crisp, vibrant, and razor-sharp across all Retina and Liquid Retina displays, respecting aspect ratios, wide color gamuts, and progressive loading ergonomics.

---

## 1. Resolution & Density Scaling (@1x, @2x, @3x)

Apple devices feature high-density displays where logical points map to multiple physical pixels:

| Asset Scale | Target Display Types | Logical Points | Physical Pixels |
| :--- | :--- | :--- | :--- |
| **@1x** | Legacy standard-definition displays | `100 x 100 pt` | `100 x 100 px` |
| **@2x** | Retina displays (MacBook Air/Pro, iPad, iPhone SE) | `100 x 100 pt` | `200 x 200 px` |
| **@3x** | Super Retina XDR displays (iPhone Pro models) | `100 x 100 pt` | `300 x 300 px` |

- **Prefer Vector for Glyphs**: Always use vector assets (SVG or PDF vector format) for custom UI icons, badges, and schematic illustrations to guarantee resolution independence.
- **Provide Crisp Raster for Photography**: Always provide `@2x` and `@3x` variants for raster marketing assets and photographic previews to prevent blurriness on Retina screens.

---

## 2. Aspect Ratios & Content Framing

1. **Zero Distortion**: Never distort or stretch an image's natural aspect ratio.
2. **Standard Scaling Modes**:
   - `BoxFit.cover`: Fills the bounding box completely, cropping symmetrically from the center. Ideal for campaign hero banners and profile avatars.
   - `BoxFit.contain`: Preserves the complete image within the bounds without clipping. Ideal for product ad mockups and creative asset previews.
3. **Continuous Squircle Masking**:
   - Apply continuous curvature clipping to raster cards:
   ```dart
   ClipRRect(
     borderRadius: BorderRadius.circular(12), // Or ContinuousRectangleBorder
     child: Image.network(
       imageUrl,
       fit: BoxFit.cover,
       errorBuilder: (context, error, stack) => buildImageFallback(),
     ),
   )
   ```

---

## 3. Wide Color Gamut (Display P3)

- Apple Liquid Retina and OLED panels natively support the **Display P3** color space, delivering 25% richer greens, vibrant ambers, and deep reds than standard sRGB.
- Export high-impact marketing imagery, brand moodboards, and campaign creative deliverables in Display P3 color profiles to maximize visual depth and fidelity.

---

## 4. Progressive Loading, Skeletons & Layout Stability

- **Prevent Layout Shifts**: Always reserve layout dimensions (via `AspectRatio` or explicit container bounds) before an image finishes loading over the network.
- **Ambient Skeleton Shimmer**: During network retrieval, display a subtle ambient gray placeholder with continuous corner rounding:
  ```dart
  Container(
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
    ),
  )
  ```
- **Resilient Fallback**: If an image fails to load, gracefully display a calm icon (e.g. `CupertinoIcons.photo`) and a soft neutral message (*"Preview unavailable"*). Never leave a broken layout or harsh red error box.

---

## 5. VoiceOver & Accessibility Semantics

- **Informative Images**: Provide a descriptive, contextual VoiceOver label:
  ```dart
  Semantics(
    image: true,
    label: 'Q4 Holiday Campaign Hero Graphic featuring minimalist autumn palette',
    child: Image(...),
  )
  ```
- **Decorative Images**: Background ambient glows, subtle gradients, and divider graphics must declare `excludeFromSemantics: true` to avoid cluttering screen readers.

