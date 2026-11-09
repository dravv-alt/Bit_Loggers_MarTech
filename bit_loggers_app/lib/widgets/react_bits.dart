import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// REACT BITS IN FLUTTER: MICRO-INTERACTIONS & MEMORABLE COMPONENTS
// ============================================================================

/// 1. SHINY TEXT (React Bits: Text Animations / Shiny Text)
/// Sweeps a beam of luminous sheen across text, from soft bands to chrome reflection.
class ShinyText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color shimmerColor;
  final Duration duration;

  const ShinyText({
    super.key,
    required this.text,
    this.style,
    this.shimmerColor = AppTheme.phosphorChartreuse,
    this.duration = const Duration(milliseconds: 2400),
  });

  @override
  State<ShinyText> createState() => _ShinyTextState();
}

class _ShinyTextState extends State<ShinyText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? const TextStyle(color: AppTheme.textPrimary, fontSize: 14);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final sweep = _controller.value;
            final width = bounds.width;
            final start = -width + (sweep * width * 2.5);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseStyle.color ?? AppTheme.textPrimary,
                widget.shimmerColor,
                baseStyle.color ?? AppTheme.textPrimary,
              ],
              stops: const [0.35, 0.50, 0.65],
              transform: _SlidingGradientTransform(slidePercent: sweep),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(widget.text, style: baseStyle),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final distance = bounds.width * 2;
    return Matrix4.translationValues(-bounds.width + (slidePercent * distance), 0.0, 0.0);
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
    this.duration = const Duration(milliseconds: 1400),
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
    final effectiveStyle = (widget.style ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)).copyWith(
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
    this.scaleDown = 0.96,
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
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// 4. BORDER GLOW CARD (React Bits: Components / Border Glow & Spotlight Card)
/// Smoked quartz card featuring a specular animated rim sweep.
class BorderGlowCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const BorderGlowCard({
    super.key,
    required this.child,
    this.glowColor = AppTheme.phosphorChartreuse,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.onTap,
  });

  @override
  State<BorderGlowCard> createState() => _BorderGlowCardState();
}

class _BorderGlowCardState extends State<BorderGlowCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;
        return ElasticPressable(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: SweepGradient(
                center: Alignment.center,
                transform: GradientRotation(angle),
                colors: [
                  AppTheme.rimKeyLight.withOpacity(0.15),
                  widget.glowColor.withOpacity(0.55),
                  AppTheme.rimKeyLight.withOpacity(0.15),
                  widget.glowColor.withOpacity(0.20),
                  AppTheme.rimKeyLight.withOpacity(0.15),
                ],
                stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                ...AppTheme.appleCardShadow,
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(1.0), // 1px border reveal
              padding: widget.padding,
              decoration: BoxDecoration(
                color: AppTheme.slabQuartz,
                borderRadius: BorderRadius.circular(radius.topLeft.x - 1),
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// 5. LIQUID HOLD BUTTON (React Bits: Micro / Hold Button)
/// Press-and-hold action button with rising bioluminescent fill before confirmation.
class LiquidHoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onComplete;
  final Duration holdDuration;
  final Color fillColor;
  final IconData? icon;

  const LiquidHoldButton({
    super.key,
    required this.label,
    required this.onComplete,
    this.holdDuration = const Duration(milliseconds: 1000),
    this.fillColor = AppTheme.phosphorChartreuse,
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
              color: AppTheme.slabElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.fillColor.withOpacity(0.4 + (progress * 0.6)),
                width: 1.0,
              ),
              boxShadow: progress > 0
                  ? [
                      BoxShadow(
                        color: widget.fillColor.withOpacity(0.3 * progress),
                        blurRadius: 16 * progress,
                        spreadRadius: 1 * progress,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  // Liquid fill rising
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      color: widget.fillColor,
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
                              ? 'Confirmed!'
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

/// 6. PULSE STATUS GLOW (React Bits: Micro / Status Mark & Backgrounds / Magic Rings)
/// A glowing status node with concentric breathing aura.
class PulseStatusGlow extends StatefulWidget {
  final Color color;
  final double size;

  const PulseStatusGlow({
    super.key,
    this.color = AppTheme.phosphorChartreuse,
    this.size = 8.0,
  });

  @override
  State<PulseStatusGlow> createState() => _PulseStatusGlowState();
}

class _PulseStatusGlowState extends State<PulseStatusGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric expanding ring
              Transform.scale(
                scale: 1.0 + (val * 1.2),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withOpacity((1.0 - val) * 0.7),
                      width: 1.0,
                    ),
                  ),
                ),
              ),
              // Solid core dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

