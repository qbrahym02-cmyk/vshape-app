import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated circular progress ring with a centred label.
class RingProgress extends StatelessWidget {
  final double value; // 0..1+
  final double size;
  final Color color;
  final Color? trackColor;
  final double stroke;
  final Widget? child;
  final IconData? icon;

  const RingProgress({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.size = 150,
    this.stroke = 13,
    this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.25)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            color: color,
            track: trackColor ?? theme.dividerColor,
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    final tp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, tp);

    if (progress <= 0) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.55), color],
        stops: const [0.0, 1.0],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}

/// Thin rounded linear meter.
class BarProgress extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final Color? track;

  const BarProgress({super.key, required this.value, required this.color, this.height = 10, this.track});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: v,
            backgroundColor: track ?? Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: height,
          ),
        ),
      ),
    );
  }
}

/// Minimal spark line for strength logs.
class SparkLine extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const SparkLine({super.key, required this.values, required this.color, this.height = 56});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final minV = v.reduce(math.min);
    final maxV = v.reduce(math.max);
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final stepX = v.length == 1 ? 0.0 : size.width / (v.length - 1);

    Offset pt(int i) {
      final x = v.length == 1 ? size.width / 2 : i * stepX;
      final y = size.height - ((v[i] - minV) / span) * (size.height - 10) - 5;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }

    final fill = Path.from(path)
      ..lineTo(pt(v.length - 1).dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    for (var i = 0; i < v.length; i++) {
      canvas.drawCircle(pt(i), i == v.length - 1 ? 4.5 : 2.6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.color != color;
}
