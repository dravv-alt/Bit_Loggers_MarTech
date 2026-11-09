# Project Design & Development Directives: Apple Human Interface Guidelines (HIG) Foundations

All user interface code, visual styles, component structures, typography, and interaction patterns in this repository must strictly adhere to the **Apple Human Interface Guidelines (HIG) Foundations** (`https://developer.apple.com/design/human-interface-guidelines/foundations`):

## Non-Negotiable Standards:
1. **Typography**: SF Pro dynamic type hierarchy with optical tracking, proportional leading, and tabular numerals (`FontFeature.tabularFigures()`) for all currency, metric, and percentage values.
2. **Spatial System & Layout**: Strict 8-point spatial grid (4pt, 8pt, 12pt, 16pt, 24pt, 32pt) with 16pt safe margins.
3. **Materials, Depth & Squircles**: Dual-layer ambient depth (`2.5%` ambient occlusion + `4.0%` diffuse key light) and organic continuous curvature squircles (8pt controls, 12pt grouped rows, 16pt sheets). No flat 1px wireframes.
4. **Grouped Scannability**: Replace bento-box floating disjointed cards with iOS-style Inset Grouped Tables divided by 0.5pt hairlines.
5. **Touch, Pointers & Interaction**: Minimum 44x44pt hit targets, immediate touch feedback, desktop hover lift/highlight effects, and a single prominent primary filled button per view.
6. **Color & Dark Mode**: Semantic color roles (`Label`, `SecondaryLabel`, `SystemBackground`, `SecondaryGroupedBackground`, `Separator`) with luminance-based elevation ladder for Dark Mode.
7. **App Icons & Branding**: Multi-layer depth architecture (Light, Dark, Tinted), no pre-baked borders or shadows. Subtle brand accenting without persistent navigation bar logo takeover.
8. **Inclusion & RTL**: Dynamic text elasticity for localization, complete Right-to-Left (RTL) horizontal layout mirroring, and directional vs. fixed icon semantics.
9. **No Technical Slop & Blameless Tone**: Zero engineering leaks (`[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`) in client UI. Human, action-oriented sentence-case microcopy.

*Master Reference Skill: [`.agents/skills/apple-hig/SKILL.md`](.agents/skills/apple-hig/SKILL.md)*
