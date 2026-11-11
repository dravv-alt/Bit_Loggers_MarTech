import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// REACT BITS IN FLUTTER: MICRO-INTERACTIONS & MEMORABLE COMPONENTS
// Refactored per heydamir/unslop: quiet chrome, no neon glowing sweeps,
// no rainbow gradients, crisp typography, and purposeful micro-physics.
// ============================================================================

/// 1. SHINY TEXT (React Bits: Text Animations / Clean Typography)
/// Replaces the AI-slop neon sweep with clean, crisp typography.
class ShinyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? shimmerColor;
  final Duration? duration;

  const ShinyText({
    super.key,
    required this.text,
    this.style,
    this.shimmerColor,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle(fontSize: 14)).copyWith(
        color: style?.color ?? AppTheme.textPrimary,
      ),
    );
  }
}

/// 2. COUNT UP (React Bits: Text Animations / Count Up)
/// Odometer roll counter with smooth easing and tabular figures.
class CountUp extends StatefulWidget {
  final double end;
  final double start;
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const CountUp({
    super.key,
    required this.end,
    this.start = 0.0,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: widget.start, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.end != widget.end) {
      _animation = Tween<double>(begin: _animation.value, end: widget.end).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final val = _animation.value;
        final formatted = widget.decimals > 0
            ? val.toStringAsFixed(widget.decimals)
            : val.toInt().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              );
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: effectiveStyle,
        );
      },
    );
  }
}

/// 3. ELASTIC PRESSABLE (React Bits: Micro / Squish & Magnet Physics)
/// Micro spring scale feedback on pointer down/hover.
class ElasticPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const ElasticPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ElasticPressable> createState() => _ElasticPressableState();
}

class _ElasticPressableState extends State<ElasticPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        child: widget.child,
      ),
    );
  }
}

/// 4. BORDER GLOW CARD (Refactored to Unslop Clean Architectural Card)
/// Strips out rotating sweep neon gradients and 20px fuzzy glowing halos.
/// Renders an authentic, quiet card adhering to current theme tokens.
class BorderGlowCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const BorderGlowCard({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.tokens.radiusCard);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: radius,
        border: Border.all(
          color: AppTheme.hairline,
          width: AppTheme.tokens.structuralRuleWidth,
        ),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return ElasticPressable(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// 5. LIQUID HOLD BUTTON (React Bits: Micro / Hold Button)
/// Press-and-hold action button with clean solid fill confirmation.
class LiquidHoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onComplete;
  final Duration holdDuration;
  final Color? fillColor;
  final IconData? icon;

  const LiquidHoldButton({
    super.key,
    required this.label,
    required this.onComplete,
    this.holdDuration = const Duration(milliseconds: 1000),
    this.fillColor,
    this.icon,
  });

  @override
  State<LiquidHoldButton> createState() => _LiquidHoldButtonState();
}

class _LiquidHoldButtonState extends State<LiquidHoldButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.holdDuration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        setState(() => _completed = true);
        widget.onComplete();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _controller.reset();
            setState(() => _completed = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown() {
    if (!_completed) _controller.forward();
  }

  void _onUp() {
    if (!_completed && _controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFill = widget.fillColor ?? AppTheme.accent;

    return GestureDetector(
      onTapDown: (_) => _onDown(),
      onTapUp: (_) => _onUp(),
      onTapCancel: () => _onUp(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.well,
              borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl),
              border: Border.all(
                color: effectiveFill.withOpacity(0.4 + (progress * 0.6)),
                width: AppTheme.tokens.structuralRuleWidth,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.tokens.radiusControl > 1 ? AppTheme.tokens.radiusControl - 1 : 0),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      color: effectiveFill,
                    ),
                  ),
                  // Button Text
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            _completed ? Icons.check_circle_rounded : widget.icon,
                            size: 16,
                            color: progress > 0.5 ? AppTheme.textInverse : AppTheme.textPrimary,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _completed
                              ? 'Confirmed'
                              : (progress > 0.05
                                  ? 'Hold to confirm (${(progress * 100).toInt()}%)'
                                  : widget.label),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: progress > 0.5 ? AppTheme.textInverse : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 6. PULSE STATUS GLOW (Clean Crisp Status Mark per Unslop)
/// Strips out animated concentric expanding rings and fuzzy drop-shadows.
/// Renders a calm, solid status dot with clean hairline outline.
class PulseStatusGlow extends StatelessWidget {
  final Color? color;
  final double size;

  const PulseStatusGlow({
    super.key,
    this.color,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? AppTheme.statusApproved;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: dotColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
    );
  }
}
