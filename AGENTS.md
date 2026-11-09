# Project Design & Development Directives: Apple Human Interface Guidelines (HIG)

All user interface code, visual styles, component structures, typography, and interaction patterns in this repository must strictly adhere to the **Apple Human Interface Guidelines (HIG)**:

## Non-Negotiable Standards:
1. **Typography**: Use the SF Pro dynamic type hierarchy with exact tracking, line heights, and weights.
   - All monetary, percentage, and metric figures must use tabular numerals (`FontFeature.tabularFigures()`).
2. **Spatial System**: Layout spacing strictly adheres to the 8-point grid (4pt, 8pt, 12pt, 16pt, 24pt, 32pt).
3. **Materials & Depth**:
   - Eliminate flat 1px wireframe borders and "card inside a card" nesting.
   - Use Apple's dual-layer ambient shadows (`3%` ambient occlusion + `5%` diffuse key light) and organic continuous curvature (8pt controls, 12pt grouped cards, 16pt sheets).
4. **Touch & Interaction**:
   - Minimum 44x44pt touch/interaction target on every interactive element.
   - Clear visual feedback on press/active states.
   - Single dominant prominent filled primary button per view.
5. **No Technical Slop**:
   - Ban engineering requirement tags (`[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`) from client UI screens. Speak pure brand and marketing intelligence.
6. **Grouped Scannability**:
   - Present lists and options in clean grouped inset rows with 0.5pt hairline dividers rather than walls of floating disjointed cards.

