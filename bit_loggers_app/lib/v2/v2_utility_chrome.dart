import 'package:flutter/material.dart';
import 'v2_tokens.dart';

/// Shared top navigation rule for pushed v2 utility & governance sub-screens.
class V2SubScreenAppBar extends StatelessWidget {
  final String backLabel;
  final Widget? trailing;
  final VoidCallback? onBack;

  const V2SubScreenAppBar({
    super.key,
    this.backLabel = 'Activity',
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: V2Tokens.hairline, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onBack ?? () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 19,
                    color: V2Tokens.textPrimary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    backLabel,
                    style: V2Tokens.t3(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Hairline action pill matching Edit/Mark-read controls across v2 screens.
class V2ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const V2ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = active
        ? V2Tokens.labelOnInk
        : disabled
            ? V2Tokens.textSecondary
            : V2Tokens.inkPrussian;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? V2Tokens.inkPrussian : V2Tokens.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? V2Tokens.inkPrussian : V2Tokens.hairline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: V2Tokens.t4(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable filter pills with Prussian active border & Cadmium Yellow indicator.
class V2FilterChipStrip extends StatelessWidget {
  final List<({String id, String label})> chips;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const V2FilterChipStrip({
    super.key,
    required this.chips,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = selectedId == chip.id;
          return GestureDetector(
            onTap: () => onSelect(chip.id),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isSelected ? V2Tokens.surfaceCard : V2Tokens.surfaceRecessed,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? V2Tokens.inkPrussian : V2Tokens.hairline,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Text(
                      chip.label,
                      style: V2Tokens.t4(
                        color: isSelected ? V2Tokens.textPrimary : V2Tokens.textSecondary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2.5,
                        color: V2Tokens.cadmiumYellow,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Proportional 24-cell tactile instrument meter for queue/health/test telemetry.
class V2SegmentMeter extends StatelessWidget {
  final int okCount;
  final int warnCount;
  final int errorCount;
  final int totalCells;

  const V2SegmentMeter({
    super.key,
    required this.okCount,
    this.warnCount = 0,
    this.errorCount = 0,
    this.totalCells = 24,
  });

  @override
  Widget build(BuildContext context) {
    final sum = okCount + warnCount + errorCount;
    final okCells = sum == 0 ? 0 : ((okCount / sum) * totalCells).round().clamp(0, totalCells);
    final warnCells = sum == 0
        ? 0
        : ((warnCount / sum) * totalCells).round().clamp(0, totalCells - okCells);
    final errCells = sum == 0
        ? 0
        : ((errorCount / sum) * totalCells)
            .round()
            .clamp(0, totalCells - okCells - warnCells);

    return Row(
      children: List.generate(totalCells, (idx) {
        Color color = V2Tokens.surfaceRecessed;
        if (idx < okCells) {
          color = V2Tokens.approvedSolid;
        } else if (idx < okCells + warnCells) {
          color = V2Tokens.cadmiumYellow;
        } else if (idx < okCells + warnCells + errCells) {
          color = V2Tokens.blockedSolid;
        }
        return Expanded(
          child: Container(
            height: 10,
            margin: EdgeInsets.only(right: idx == totalCells - 1 ? 0 : 2.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        );
      }),
    );
  }
}

