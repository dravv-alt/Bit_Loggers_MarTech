import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'scale_tick_sound.dart';
import 'v2_tokens.dart';

/// Mechanical rolling weight scale for V2ProposalStudioSheet budget allocation.
/// Swiping right-to-left pulls the graduated tape left to roll higher values under
/// the fixed center Cadmium needle, with weighted resistance, notch detents, and sound.
class V2BudgetWeightScale extends StatefulWidget {
  final double budget;
  final double minBudget;
  final double maxBudget;
  final double ceilingBudget;
  final double step;
  final ValueChanged<double> onBudgetChanged;

  const V2BudgetWeightScale({
    super.key,
    required this.budget,
    this.minBudget = 15000.0,
    this.maxBudget = 35000.0,
    this.ceilingBudget = 30000.0,
    this.step = 1000.0,
    required this.onBudgetChanged,
  });

  @override
  State<V2BudgetWeightScale> createState() => _V2BudgetWeightScaleState();
}

class _V2BudgetWeightScaleState extends State<V2BudgetWeightScale>
    with SingleTickerProviderStateMixin {
  static const double _pixelsPerStep = 28.0; // 140px per $5,000 interval

  late final Ticker _ticker;
  Duration? _lastElapsed;

  late double _visualValue;
  late double _emittedBudget;
  late int _lastNotchIdx;

  double _velocityValuePerSec = 0.0;
  double? _targetSnapValue;
  bool _isDragging = false;
  bool _playedBoundaryBump = false;
  DateTime? _lastScrollWheelTick;

  // Mechanical center pawl recoil & numeral micro-pulse
  double _needleTiltRad = 0.0;
  double _readoutPulse = 0.0;

  @override
  void initState() {
    super.initState();
    _visualValue = widget.budget.clamp(widget.minBudget, widget.maxBudget);
    _emittedBudget = _snapToNotch(_visualValue);
    _lastNotchIdx = _notchIndex(_visualValue);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant V2BudgetWeightScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.budget - _emittedBudget).abs() > 1.0 && !_isDragging) {
      _emittedBudget = _snapToNotch(widget.budget);
      _targetSnapValue = _emittedBudget;
      _ensureTickerRunning();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _snapToNotch(double value) {
    return ((value / widget.step).round() * widget.step)
        .clamp(widget.minBudget, widget.maxBudget);
  }

  int _notchIndex(double value) {
    return (value / widget.step)
        .round()
        .clamp((widget.minBudget / widget.step).round(),
            (widget.maxBudget / widget.step).round());
  }

  void _ensureTickerRunning() {
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _triggerNotchFeedback(int newIdx, int direction) {
    final snapped = (newIdx * widget.step).clamp(widget.minBudget, widget.maxBudget);
    final isCeiling = (snapped - widget.ceilingBudget).abs() < 1.0;
    final isMajor = snapped % 5000.0 == 0.0;

    if (isCeiling) {
      HapticFeedback.mediumImpact();
    } else if (isMajor) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    V2ScaleTickAudio.playTick(isMajor: isMajor, isCeiling: isCeiling);

    // Pawl brushes against passing teeth: rightward swipe -> teeth sweep right (-tilt),
    // leftward swipe -> teeth sweep left (+tilt)
    final strength = (isMajor || isCeiling) ? 0.115 : 0.085;
    _needleTiltRad = (direction >= 0 ? strength : -strength);
    _readoutPulse = isCeiling ? 1.0 : 0.65;

    if ((snapped - _emittedBudget).abs() > 1.0) {
      _emittedBudget = snapped;
      widget.onBudgetChanged(snapped);
    }
  }

  void _updateVisualAndNotify(double nextVisual, {required int directionHint}) {
    _visualValue = nextVisual;
    final nextIdx = _notchIndex(_visualValue);
    if (nextIdx != _lastNotchIdx) {
      final stepDir = nextIdx > _lastNotchIdx ? 1 : -1;
      // If fast flick jumped >1 notch in one frame, advance index one notch visually/audibly cleanly
      _lastNotchIdx = nextIdx;
      _triggerNotchFeedback(nextIdx, directionHint != 0 ? directionHint : stepDir);
      // Slight mechanical escapement drag on every tooth while coasting
      if (!_isDragging && _velocityValuePerSec.abs() > 0) {
        _velocityValuePerSec *= 0.89;
      }
    }
  }

  void _applyDraggedDeltaPx(double deltaDx) {
    if (deltaDx == 0.0) return;

    // Right-to-left swipe (deltaDx < 0) moves scale LEFT -> increases budget
    final rawDeltaVal = (-deltaDx / _pixelsPerStep) * widget.step;
    final dir = rawDeltaVal >= 0 ? 1 : -1;

    // Base mechanical wheel resistance
    double resistance = 0.72;

    // Extra tension when pushing past the $30,000 governance ceiling
    if (_visualValue >= widget.ceilingBudget && rawDeltaVal > 0) {
      resistance = 0.56;
    }

    // Subtle cogging micro-detent near each $1k notch crest
    final frac = (_visualValue / widget.step) - (_visualValue / widget.step).floorToDouble();
    final toothProximity = math.cos(frac * math.pi).abs(); // 1.0 at notch, 0.0 midway
    resistance *= (1.03 - 0.19 * toothProximity * toothProximity);

    double deltaVal = rawDeltaVal * resistance;
    double candidate = _visualValue + deltaVal;

    // Elastic rubber-band boundary over-travel beyond [minBudget, maxBudget]
    const maxOverdrag = 1150.0;
    if (candidate < widget.minBudget && deltaVal < 0) {
      final overshoot = (widget.minBudget - candidate).clamp(0.0, maxOverdrag);
      if (!_playedBoundaryBump && overshoot > 60) {
        _playedBoundaryBump = true;
        HapticFeedback.lightImpact();
        V2ScaleTickAudio.playTick(isBump: true);
      }
      final rubber = 0.24 * math.exp(-overshoot / 550.0);
      candidate = math.max(widget.minBudget - maxOverdrag, _visualValue + deltaVal * rubber);
    } else if (candidate > widget.maxBudget && deltaVal > 0) {
      final overshoot = (candidate - widget.maxBudget).clamp(0.0, maxOverdrag);
      if (!_playedBoundaryBump && overshoot > 60) {
        _playedBoundaryBump = true;
        HapticFeedback.lightImpact();
        V2ScaleTickAudio.playTick(isBump: true);
      }
      final rubber = 0.24 * math.exp(-overshoot / 550.0);
      candidate = math.min(widget.maxBudget + maxOverdrag, _visualValue + deltaVal * rubber);
    } else {
      _playedBoundaryBump = false;
    }

    _updateVisualAndNotify(candidate, directionHint: dir);
    setState(() {});
    _ensureTickerRunning();
  }

  void _handleTrackpadScroll(double scrollDx) {
    if (scrollDx == 0.0) return;
    V2ScaleTickAudio.warmUp();
    _velocityValuePerSec = 0.0;

    final rawVal = (scrollDx / _pixelsPerStep) * widget.step * 0.65;
    final dir = rawVal >= 0 ? 1 : -1;
    final nextVal = (_visualValue + rawVal).clamp(widget.minBudget, widget.maxBudget);

    _updateVisualAndNotify(nextVal, directionHint: dir);
    // Settle smoothly to nearest $1k tick shortly after wheel stops emitting
    _targetSnapValue = _snapToNotch(nextVal);
    _lastScrollWheelTick = DateTime.now();
    setState(() {});
    _ensureTickerRunning();
  }

  void _onHorizontalDragDown(DragDownDetails _) {
    V2ScaleTickAudio.warmUp();
    setState(() {
      _isDragging = true;
      _velocityValuePerSec = 0.0;
      _targetSnapValue = null;
      _playedBoundaryBump = false;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final pxPerSec = details.velocity.pixelsPerSecond.dx;
    // Leftward swipe (negative pxPerSec) creates positive budget velocity (moves tape left)
    final initialVel = (-pxPerSec * 0.56 / _pixelsPerStep) * widget.step;
    setState(() {
      _isDragging = false;
      _targetSnapValue = null;
      _velocityValuePerSec = initialVel.clamp(-24000.0, 24000.0);
    });
    _ensureTickerRunning();
  }

  void _onHorizontalDragCancel() {
    setState(() {
      _isDragging = false;
      _velocityValuePerSec = 0.0;
      _targetSnapValue = _snapToNotch(_visualValue);
    });
    _ensureTickerRunning();
  }

  void _onTapScale(TapUpDetails details, double trackWidth) {
    V2ScaleTickAudio.warmUp();
    final dxFromCenter = details.localPosition.dx - (trackWidth / 2.0);
    final tappedApprox = _visualValue + (dxFromCenter / _pixelsPerStep) * widget.step;
    final target = _snapToNotch(tappedApprox);
    if ((target - _visualValue).abs() > 1.0) {
      setState(() {
        _isDragging = false;
        _velocityValuePerSec = 0.0;
        _targetSnapValue = target;
      });
      _ensureTickerRunning();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final prev = _lastElapsed;
    _lastElapsed = elapsed;
    if (prev == null) return;

    final rawDt = (elapsed - prev).inMicroseconds / 1000000.0;
    final dt = rawDt.clamp(0.001, 0.04);

    bool changed = false;

    // 1. Decay pawl needle deflection & numeral pulse smoothly
    if (_needleTiltRad.abs() > 0.001) {
      _needleTiltRad *= math.exp(-26.0 * dt);
      if (_needleTiltRad.abs() <= 0.001) _needleTiltRad = 0.0;
      changed = true;
    }
    if (_readoutPulse > 0.005) {
      _readoutPulse *= math.exp(-22.0 * dt);
      if (_readoutPulse <= 0.005) _readoutPulse = 0.0;
      changed = true;
    }

    // 2. When not dragging, run coasting friction + elastic wall recovery + magnetic notch snap
    if (!_isDragging) {
      final isWheelCoolingDown = _lastScrollWheelTick != null &&
          DateTime.now().difference(_lastScrollWheelTick!).inMilliseconds < 110;

      if (_visualValue < widget.minBudget || _visualValue > widget.maxBudget) {
        // Elastic rebound back to min/max rail stop
        _velocityValuePerSec = 0.0;
        final bound = _visualValue < widget.minBudget ? widget.minBudget : widget.maxBudget;
        final next = _visualValue + (bound - _visualValue) * (1.0 - math.exp(-24.0 * dt));
        _updateVisualAndNotify(
          (next - bound).abs() < 2.0 ? bound : next,
          directionHint: bound > _visualValue ? 1 : -1,
        );
        changed = true;
      } else if (_targetSnapValue != null) {
        if (!isWheelCoolingDown) {
          final target = _targetSnapValue!;
          final diff = target - _visualValue;
          if (diff.abs() < 2.5) {
            _updateVisualAndNotify(target, directionHint: 0);
            _targetSnapValue = null;
          } else {
            // Smooth brisk roll so taps play ticks clearly across traversed teeth
            final maxStep = 14000.0 * dt;
            final stepDelta = (diff * (1.0 - math.exp(-18.0 * dt))).clamp(-maxStep, maxStep);
            _updateVisualAndNotify(
              _visualValue + stepDelta,
              directionHint: diff >= 0 ? 1 : -1,
            );
          }
          changed = true;
        }
      } else if (_velocityValuePerSec.abs() > 1400.0) {
        // Heavy mechanical inertial glide
        final prevVal = _visualValue;
        _velocityValuePerSec *= math.exp(-8.5 * dt);
        double next = prevVal + _velocityValuePerSec * dt;

        // Cushion into bounds if flick reaches rail ends
        if (next < widget.minBudget) {
          next = widget.minBudget;
          _velocityValuePerSec = 0.0;
          HapticFeedback.lightImpact();
          V2ScaleTickAudio.playTick(isBump: true);
        } else if (next > widget.maxBudget) {
          next = widget.maxBudget;
          _velocityValuePerSec = 0.0;
          HapticFeedback.lightImpact();
          V2ScaleTickAudio.playTick(isBump: true);
        }

        _updateVisualAndNotify(
          next,
          directionHint: _velocityValuePerSec >= 0 ? 1 : -1,
        );
        changed = true;
      } else {
        // Magnetic snap onto nearest $1,000 notch
        _velocityValuePerSec = 0.0;
        final nearest = _snapToNotch(_visualValue);
        final diff = nearest - _visualValue;
        if (diff.abs() >= 2.0) {
          final next = _visualValue + diff * (1.0 - math.exp(-22.0 * dt));
          _updateVisualAndNotify(next, directionHint: diff >= 0 ? 1 : -1);
          changed = true;
        } else if ((_visualValue - nearest).abs() > 0.01) {
          _updateVisualAndNotify(nearest, directionHint: 0);
          changed = true;
        }
      }
    }

    if (changed) {
      setState(() {});
    }

    final settled = !_isDragging &&
        _velocityValuePerSec.abs() <= 1400.0 &&
        _targetSnapValue == null &&
        (_visualValue - _snapToNotch(_visualValue)).abs() < 0.5 &&
        _needleTiltRad == 0.0 &&
        _readoutPulse == 0.0;

    if (settled) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBudget = _snapToNotch(_visualValue);
    final isOverCeiling = activeBudget > widget.ceilingBudget;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return Listener(
            onPointerDown: (_) => V2ScaleTickAudio.warmUp(),
            onPointerSignal: (event) {
              if (event is PointerScrollEvent &&
                  event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs() &&
                  event.scrollDelta.dx != 0) {
                _handleTrackpadScroll(event.scrollDelta.dx);
              }
            },
            child: MouseRegion(
              cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
              child: Semantics(
                label: 'Budget cap rolling weight scale',
                value: V2Tokens.formatCurrency(activeBudget),
                increasedValue: V2Tokens.formatCurrency(
                  math.min(widget.maxBudget, activeBudget + widget.step),
                ),
                decreasedValue: V2Tokens.formatCurrency(
                  math.max(widget.minBudget, activeBudget - widget.step),
                ),
                onIncrease: () {
                  final next = math.min(widget.maxBudget, activeBudget + widget.step);
                  setState(() {
                    _targetSnapValue = next;
                  });
                  _ensureTickerRunning();
                },
                onDecrease: () {
                  final next = math.max(widget.minBudget, activeBudget - widget.step);
                  setState(() {
                    _targetSnapValue = next;
                  });
                  _ensureTickerRunning();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragDown: _onHorizontalDragDown,
                  onHorizontalDragUpdate: (details) => _applyDraggedDeltaPx(details.delta.dx),
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onHorizontalDragCancel: _onHorizontalDragCancel,
                  onTapUp: (details) => _onTapScale(details, width - 32),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Budget cap', style: V2Tokens.t3(color: V2Tokens.textSecondary)),
                            Text(
                              'Ceiling ${V2Tokens.formatCurrency(widget.ceilingBudget)}',
                              style: V2Tokens.t4(color: V2Tokens.blockedSolid),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Transform.scale(
                            scale: 1.0 + (0.022 * _readoutPulse),
                            child: Text(
                              V2Tokens.formatCurrency(activeBudget),
                              style: V2Tokens.t1(
                                mono: true,
                                color: isOverCeiling ? V2Tokens.blockedSolid : V2Tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Rolling Weight Scale Viewport + Fixed Center Cadmium Needle
                        SizedBox(
                          height: 46,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              // Moving graduated scale with soft left/right edge mask
                              Positioned.fill(
                                child: ClipRect(
                                  child: ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (rect) {
                                      return const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black,
                                          Colors.black,
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.10, 0.90, 1.0],
                                      ).createShader(rect);
                                    },
                                    child: CustomPaint(
                                      size: Size(width - 32, 46),
                                      painter: _WeightScaleRulerPainter(
                                        visualValue: _visualValue,
                                        minBudget: widget.minBudget,
                                        maxBudget: widget.maxBudget,
                                        ceilingBudget: widget.ceilingBudget,
                                        pixelsPerStep: _pixelsPerStep,
                                        step: widget.step,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Fixed Center Cadmium Yellow Needle with mechanical ratchet tilt
                              Positioned(
                                top: 0,
                                child: Transform.rotate(
                                  angle: _needleTiltRad,
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomPaint(
                                        size: const Size(7, 4),
                                        painter: _CenterPipPainter(
                                          color: isOverCeiling
                                              ? V2Tokens.blockedSolid
                                              : V2Tokens.inkPrussian,
                                        ),
                                      ),
                                      Container(
                                        width: 4.5,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: V2Tokens.cadmiumYellow,
                                          borderRadius: BorderRadius.circular(1.5),
                                          border: Border.all(
                                            color: isOverCeiling
                                                ? V2Tokens.blockedSolid
                                                : V2Tokens.inkPrussian,
                                            width: 0.75,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CenterPipPainter extends CustomPainter {
  final Color color;

  const _CenterPipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CenterPipPainter oldDelegate) => oldDelegate.color != color;
}

class _WeightScaleRulerPainter extends CustomPainter {
  final double visualValue;
  final double minBudget;
  final double maxBudget;
  final double ceilingBudget;
  final double pixelsPerStep;
  final double step;

  const _WeightScaleRulerPainter({
    required this.visualValue,
    required this.minBudget,
    required this.maxBudget,
    required this.ceilingBudget,
    required this.pixelsPerStep,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    const baselineY = 24.0;

    // Subtle hairline horizon rule running underneath the rolling teeth
    final railPaint = Paint()
      ..color = V2Tokens.hairline.withOpacity(0.85)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      const Offset(0, baselineY),
      Offset(size.width, baselineY),
      railPaint,
    );

    final minorSubStep = step / 2.0; // $500 vernier sub-ticks
    final paintStartVal = minBudget - 4000.0;
    final paintEndVal = maxBudget + 4000.0;

    for (double val = paintStartVal; val <= paintEndVal + 0.5; val += minorSubStep) {
      final x = centerX + ((val - visualValue) / step) * pixelsPerStep;
      if (x < -36 || x > size.width + 36) continue;

      final inActiveRange = val >= minBudget - 0.5 && val <= maxBudget + 0.5;
      final isIntegerStep = (val % step).abs() < 1.0 || (val % step - step).abs() < 1.0;
      final isMajor = inActiveRange && (val % 5000.0).abs() < 1.0;
      final isCeiling = inActiveRange && (val - ceilingBudget).abs() < 1.0;

      // Distance from fixed needle subtly boosts tick contrast as it rolls into focus
      final focus = (1.0 - ((x - centerX).abs() / (pixelsPerStep * 1.4))).clamp(0.0, 1.0);

      double tickHeight;
      double strokeWidth;
      Color tickColor;

      if (!inActiveRange) {
        tickHeight = isIntegerStep ? 7.0 : 4.0;
        strokeWidth = 1.0;
        tickColor = V2Tokens.hairline.withOpacity(0.35);
      } else if (isCeiling) {
        tickHeight = 16.0 + 1.5 * focus;
        strokeWidth = 2.0;
        tickColor = V2Tokens.blockedSolid;
      } else if (isMajor) {
        tickHeight = 15.0 + 1.5 * focus;
        strokeWidth = 2.0;
        tickColor = V2Tokens.inkPrussian;
      } else if (isIntegerStep) {
        tickHeight = 9.5 + 1.5 * focus;
        strokeWidth = 1.5;
        tickColor = Color.lerp(
          const Color(0xFFA69F92),
          V2Tokens.inkPrussian,
          focus * 0.65,
        )!;
      } else {
        tickHeight = 5.0;
        strokeWidth = 1.0;
        tickColor = V2Tokens.hairline;
      }

      final paint = Paint()
        ..color = tickColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, baselineY - tickHeight),
        Offset(x, baselineY),
        paint,
      );

      if (isMajor) {
        final kVal = (val / 1000.0).round();
        final labelText = isCeiling ? '\$${kVal}k cap' : '\$${kVal}k';
        final labelColor = isCeiling
            ? V2Tokens.blockedSolid
            : Color.lerp(V2Tokens.textSecondary, V2Tokens.textPrimary, focus)!;

        final tp = TextPainter(
          text: TextSpan(
            text: labelText,
            style: V2Tokens.t4(color: labelColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(x - tp.width / 2.0, baselineY + 5.0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightScaleRulerPainter oldDelegate) {
    return oldDelegate.visualValue != visualValue ||
        oldDelegate.minBudget != minBudget ||
        oldDelegate.maxBudget != maxBudget ||
        oldDelegate.ceilingBudget != ceilingBudget;
  }
}
