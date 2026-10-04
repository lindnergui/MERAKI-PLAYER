import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meraki/src/ui/meraki_theme.dart';
import 'package:meraki/src/ui/widgets/cover_art_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Desktop turntable used by the redesigned home and "Tocando agora" views.
///
/// The record follows the outlined disc icon used by the Android navigation
/// bar: an outer ring, an offset groove arc and a ringed centre label. The
/// record spins while [isPlaying] and the tonearm moves onto the grooves.
/// All geometry is expressed in fractions of the deck height so it scales
/// with the available space.
class MerakiTurntable extends StatefulWidget {
  const MerakiTurntable({
    required this.coverArtUrlOrPath,
    required this.isPlaying,
    required this.hasTrack,
    required this.onTogglePlay,
    required this.volume,
    required this.onVolumeChanged,
    super.key,
  });

  /// Width / height of the deck.
  static const double aspectRatio = 1.25;

  final String? coverArtUrlOrPath;
  final bool isPlaying;
  final bool hasTrack;
  final VoidCallback? onTogglePlay;
  final double volume;
  final ValueChanged<double>? onVolumeChanged;

  @override
  State<MerakiTurntable> createState() => _MerakiTurntableState();
}

class _MerakiTurntableState extends State<MerakiTurntable>
    with SingleTickerProviderStateMixin {
  // 33⅓ RPM ≈ 1.8 s per revolution.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant MerakiTurntable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _spin.repeat();
      } else {
        _spin.stop();
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AspectRatio(
      aspectRatio: MerakiTurntable.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final geometry = _DeckGeometry(h);
          final recordRadius = geometry.platterRadius * 0.97;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h * 0.07),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF2E1F42),
                  Color(0xFF1B1226),
                  Color(0xFF130C1C),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.30),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 46,
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PlinthPainter(
                      geometry: geometry,
                      accent: accent,
                      isPlaying: widget.isPlaying,
                    ),
                  ),
                ),
                Positioned(
                  left: geometry.center.dx - recordRadius,
                  top: geometry.center.dy - recordRadius,
                  width: recordRadius * 2,
                  height: recordRadius * 2,
                  child: RepaintBoundary(
                    child: RotationTransition(
                      turns: _spin,
                      child: _Vinyl(
                        radius: recordRadius,
                        coverArtUrlOrPath: widget.coverArtUrlOrPath,
                        hasTrack: widget.hasTrack,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: widget.isPlaying ? 0.56 : 0.0),
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.easeInOutCubic,
                      builder: (context, angle, _) => CustomPaint(
                        painter: _TonearmPainter(
                          geometry: geometry,
                          angle: angle,
                          accent: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                // Start / stop button.
                Positioned(
                  left: h * 0.085 - h * 0.05,
                  top: h * 0.905 - h * 0.05,
                  width: h * 0.10,
                  height: h * 0.10,
                  child: _StartStopKnob(
                    isPlaying: widget.isPlaying,
                    onTap: widget.onTogglePlay,
                  ),
                ),
                // RPM label.
                Positioned(
                  right: h * 0.05,
                  bottom: h * 0.045,
                  child: Text(
                    '33 RPM',
                    style: merakiPixelStyle(
                      math.max(9, h * 0.034),
                      color: MerakiColors.softText.withValues(alpha: 0.75),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // Pitch fader, used as the volume control.
                Positioned(
                  left: geometry.faderX - h * 0.045,
                  top: geometry.faderTop - h * 0.07,
                  width: h * 0.09,
                  height: geometry.faderBottom - geometry.faderTop + h * 0.10,
                  child: _VolumeFader(
                    geometry: geometry,
                    value: widget.volume,
                    onChanged: widget.onVolumeChanged,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Deck geometry in logical pixels, derived from the deck height.
class _DeckGeometry {
  _DeckGeometry(this.h);

  final double h;

  Offset get center => Offset(0.5 * h, 0.5 * h);
  double get platterRadius => 0.42 * h;
  Offset get pivot => Offset(1.05 * h, 0.2 * h);
  double get armLength => 0.66 * h;
  double get faderX => 1.165 * h;
  double get faderTop => 0.42 * h;
  double get faderBottom => 0.80 * h;
}

class _PlinthPainter extends CustomPainter {
  _PlinthPainter({
    required this.geometry,
    required this.accent,
    required this.isPlaying,
  });

  final _DeckGeometry geometry;
  final Color accent;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final h = geometry.h;

    // Inner bevel.
    final inner = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(h * 0.022),
      Radius.circular(h * 0.055),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    // Corner screws.
    final screwRadius = h * 0.013;
    final inset = h * 0.055;
    for (final point in <Offset>[
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawCircle(point, screwRadius, Paint()..color = const Color(0xFF3B2A52));
      canvas.drawCircle(
        point,
        screwRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.12),
      );
      canvas.drawLine(
        point - Offset(screwRadius * 0.6, screwRadius * 0.6),
        point + Offset(screwRadius * 0.6, screwRadius * 0.6),
        Paint()
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.5),
      );
    }

    // Platter base.
    final center = geometry.center;
    final platterRadius = geometry.platterRadius;
    canvas.drawCircle(
      center,
      platterRadius + h * 0.05,
      Paint()..color = const Color(0xFF0A0610),
    );
    canvas.drawCircle(
      center,
      platterRadius + h * 0.05,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    // Strobe dots around the platter rim.
    const dots = 132;
    final dotRing = platterRadius + h * 0.028;
    final dotRadius = math.max(0.8, h * 0.0045);
    final dotPaint = Paint()
      ..color = MerakiColors.softText.withValues(alpha: 0.55);
    final strobePaint = Paint()
      ..color = accent.withValues(alpha: isPlaying ? 0.95 : 0.35);
    for (var index = 0; index < dots; index++) {
      final angle = index / dots * math.pi * 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * dotRing;
      // Strobe light zone at the lower left, like a classic deck.
      final isStrobe = angle > math.pi * 0.70 && angle < math.pi * 0.80;
      canvas.drawCircle(point, dotRadius, isStrobe ? strobePaint : dotPaint);
    }

    // Tonearm base.
    final pivot = geometry.pivot;
    canvas.drawCircle(
      pivot,
      h * 0.095,
      Paint()..color = const Color(0xFF241733),
    );
    canvas.drawCircle(
      pivot,
      h * 0.095,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      pivot,
      h * 0.07,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = MerakiColors.softText.withValues(alpha: 0.25),
    );

    // Arm rest.
    final rest = Offset(pivot.dx + h * 0.005, 0.83 * h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: rest, width: h * 0.035, height: h * 0.05),
        Radius.circular(h * 0.008),
      ),
      Paint()..color = const Color(0xFF2E1F42),
    );

    // Fader track.
    final faderTrack = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        geometry.faderX - h * 0.008,
        geometry.faderTop,
        geometry.faderX + h * 0.008,
        geometry.faderBottom,
      ),
      Radius.circular(h * 0.008),
    );
    canvas.drawRRect(faderTrack, Paint()..color = const Color(0xFF0A0610));
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..color = MerakiColors.softText.withValues(alpha: 0.35);
    for (var index = 0; index <= 8; index++) {
      final y =
          geometry.faderTop +
          (geometry.faderBottom - geometry.faderTop) * index / 8;
      final length = index.isEven ? h * 0.025 : h * 0.014;
      canvas.drawLine(
        Offset(geometry.faderX - h * 0.022 - length, y),
        Offset(geometry.faderX - h * 0.022, y),
        tickPaint,
      );
    }

    // Power LED.
    final led = Offset(0.175 * h, 0.94 * h);
    if (isPlaying) {
      canvas.drawCircle(
        led,
        h * 0.022,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.015),
      );
    }
    canvas.drawCircle(
      led,
      h * 0.009,
      Paint()
        ..color = isPlaying ? accent : MerakiColors.softText.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_PlinthPainter oldDelegate) {
    return oldDelegate.geometry.h != geometry.h ||
        oldDelegate.accent != accent ||
        oldDelegate.isPlaying != isPlaying;
  }
}

class _TonearmPainter extends CustomPainter {
  _TonearmPainter({
    required this.geometry,
    required this.angle,
    required this.accent,
  });

  final _DeckGeometry geometry;
  final double angle;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final h = geometry.h;
    final pivot = geometry.pivot;
    final direction = Offset(-math.sin(angle), math.cos(angle));
    final length = geometry.armLength;
    final tip = pivot + direction * length;
    final shadowOffset = Offset(h * 0.012, h * 0.018);

    // Counterweight.
    final weightStart = pivot - direction * (h * 0.04);
    final weightEnd = pivot - direction * (h * 0.13);
    canvas.drawLine(
      weightStart + shadowOffset,
      weightEnd + shadowOffset,
      Paint()
        ..strokeWidth = h * 0.062
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawLine(
      weightStart,
      weightEnd,
      Paint()
        ..strokeWidth = h * 0.062
        ..color = const Color(0xFF3B2A52),
    );
    canvas.drawLine(
      weightStart,
      weightEnd,
      Paint()
        ..strokeWidth = h * 0.02
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    // Arm tube (shadow + tube + highlight).
    final armEnd = pivot + direction * (length - h * 0.05);
    canvas.drawLine(
      pivot + shadowOffset,
      armEnd + shadowOffset,
      Paint()
        ..strokeWidth = h * 0.02
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawLine(
      pivot,
      armEnd,
      Paint()
        ..strokeWidth = h * 0.018
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD7CBE6),
    );
    canvas.drawLine(
      pivot,
      armEnd,
      Paint()
        ..strokeWidth = h * 0.005
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    // Headshell.
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle + 0.38);
    final headshell = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: h * 0.055,
        height: h * 0.11,
      ),
      Radius.circular(h * 0.012),
    );
    canvas.drawRRect(
      headshell.shift(shadowOffset),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawRRect(headshell, Paint()..color = const Color(0xFFD7CBE6));
    final stripePaint = Paint()..color = accent;
    for (var index = 0; index < 3; index++) {
      canvas.drawRect(
        Rect.fromLTWH(
          -h * 0.018,
          -h * 0.035 + index * h * 0.022,
          h * 0.036,
          h * 0.011,
        ),
        stripePaint,
      );
    }
    canvas.restore();

    // Pivot cap.
    canvas.drawCircle(
      pivot,
      h * 0.045,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFFEDE4F7), Color(0xFF8C7BA3)],
        ).createShader(Rect.fromCircle(center: pivot, radius: h * 0.045)),
    );
    canvas.drawCircle(pivot, h * 0.012, Paint()..color = const Color(0xFF241733));
  }

  @override
  bool shouldRepaint(_TonearmPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.geometry.h != geometry.h ||
        oldDelegate.accent != accent;
  }
}

class _Vinyl extends StatelessWidget {
  const _Vinyl({
    required this.radius,
    required this.coverArtUrlOrPath,
    required this.hasTrack,
  });

  final double radius;
  final String? coverArtUrlOrPath;
  final bool hasTrack;

  static const double labelFactor = 0.36;

  @override
  Widget build(BuildContext context) {
    final labelSize = radius * labelFactor * 2;
    final cacheSize = (labelSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(64, 900)
        .toInt();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CustomPaint(painter: _VinylPainter()),
        Center(
          child: ClipOval(
            child: SizedBox(
              width: labelSize,
              height: labelSize,
              child: hasTrack
                  ? CoverArtImage(
                      coverArtUrlOrPath: coverArtUrlOrPath,
                      cacheWidth: cacheSize,
                      cacheHeight: cacheSize,
                      borderRadius: BorderRadius.zero,
                    )
                  : Image.asset(
                      'assets/images/meraki_mark.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),
        ),
        CustomPaint(painter: _VinylLabelPainter()),
      ],
    );
  }
}

/// Record body drawn after the Android disc icon: outer ring + groove arc.
class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF1C1127), Color(0xFF09060E)],
        ).createShader(rect),
    );

    // Grooves.
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.04);
    for (var r = radius * 0.40; r < radius * 0.95; r += radius * 0.024) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Light sheen, visible while the record spins.
    canvas.drawCircle(
      center,
      radius * 0.95,
      Paint()
        ..shader = SweepGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.08, 0.18, 0.5, 0.58, 0.68],
        ).createShader(rect),
    );

    // Outer ring of the disc icon.
    final ringWidth = radius * 0.028;
    canvas.drawCircle(
      center,
      radius - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = MerakiColors.softText.withValues(alpha: 0.9),
    );

    // The disc icon's offset arc between the label and the outer ring.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.64),
      -math.pi / 2 + 0.15,
      math.pi / 2.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.032
        ..strokeCap = StrokeCap.round
        ..color = MerakiColors.softText,
    );
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) => false;
}

/// Ring around the centre label and the spindle on top of the cover art.
class _VinylLabelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final ringWidth = radius * 0.028;
    canvas.drawCircle(
      center,
      radius * _Vinyl.labelFactor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = MerakiColors.softText,
    );
    canvas.drawCircle(
      center,
      radius * 0.045,
      Paint()..color = MerakiColors.deepPurple,
    );
    canvas.drawCircle(
      center,
      radius * 0.03,
      Paint()..color = const Color(0xFFD9CCE8),
    );
  }

  @override
  bool shouldRepaint(_VinylLabelPainter oldDelegate) => false;
}

class _StartStopKnob extends StatelessWidget {
  const _StartStopKnob({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: isPlaying ? 'Pausar' : 'Tocar',
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: <Color>[Color(0xFF4A3763), Color(0xFF1E142B)],
              ),
              border: Border.all(
                color: isPlaying
                    ? accent
                    : MerakiColors.softText.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Icon(
                PhosphorIconsBold.power,
                size: constraints.maxWidth * 0.45,
                color: isPlaying ? accent : MerakiColors.softText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeFader extends StatelessWidget {
  const _VolumeFader({
    required this.geometry,
    required this.value,
    required this.onChanged,
  });

  final _DeckGeometry geometry;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final h = geometry.h;
    final trackTop = h * 0.07;
    final trackLength = geometry.faderBottom - geometry.faderTop;
    final clamped = value.clamp(0.0, 1.0);

    void update(double localY) {
      final onChanged = this.onChanged;
      if (onChanged == null) return;
      onChanged((1 - (localY - trackTop) / trackLength).clamp(0.0, 1.0));
    }

    return Tooltip(
      message: 'Volume ${(clamped * 100).round()}%',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => update(details.localPosition.dy),
          onVerticalDragUpdate: (details) => update(details.localPosition.dy),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Text(
                  'VOL',
                  textAlign: TextAlign.center,
                  style: merakiPixelStyle(
                    math.max(8, h * 0.03),
                    color: MerakiColors.softText.withValues(alpha: 0.75),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Positioned(
                left: h * 0.045 - h * 0.035,
                top: trackTop + (1 - clamped) * trackLength - h * 0.017,
                width: h * 0.07,
                height: h * 0.034,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h * 0.008),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFFEDE4F7), Color(0xFF8C7BA3)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      height: 1.5,
                      margin: EdgeInsets.symmetric(horizontal: h * 0.008),
                      color: MerakiColors.deepPurple,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
