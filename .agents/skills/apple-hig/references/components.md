# Apple HIG Component Hierarchy Reference

## 1. Grouped List (The Antidote to "Card-in-Card" Clutter)

Instead of nesting individual cards with borders, Apple groups related items into an **Inset Grouped Table**.

- **Section Header**: `Footnote (13pt)` or `Subhead (15pt)`, uppercase or sentence case, muted grey (`secondaryLabel`), leading indent `16pt`.
- **Card Container**: Rounded squircle `12pt`, white surface, soft dual-shadow or `0.5pt` subtle outline.
- **Rows**: Separated by `0.5pt` hairline divider indented to align with the text (`indent: 56pt` if there is a leading icon).

```dart
Widget buildAppleGroupedSection({
  String? title,
  required List<Widget> rows,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C6C70),
              letterSpacing: 0.2,
            ),
          ),
        ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                const Divider(height: 0.5, thickness: 0.5, indent: 16, color: Color(0x1F000000)),
            ],
          ],
        ),
      ),
    ],
  );
}
```

---

## 2. Interactive Buttons & Accessible Touch Targets

All buttons must provide a minimum **44x44pt** tap target.

### Primary Prominent Button:
Reserved for the view's singular primary goal:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF007AFF), // System Blue or Primary Brand Ink
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ),
  onPressed: onConfirm,
  child: const Text('Commit Flight Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
)
```

### Secondary Tonal Button:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFF2F2F7),
    foregroundColor: const Color(0xFF007AFF),
    minimumSize: const Size(0, 44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 0,
  ),
  onPressed: onSecondaryAction,
  child: const Text('Add Reviewer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
)
```
