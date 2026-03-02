import 'dart:math';

import 'package:flutter/material.dart';

class PieSlice {
  final double value;
  final Color color;
  final String label;

  PieSlice({required this.value, required this.color, required this.label});
}

class PieChart extends StatelessWidget {
  final List<PieSlice> slices;

  const PieChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PiePainter(slices),
      child: const SizedBox.expand(),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieSlice> slices;

  _PiePainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (p, e) => p + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * (s.value / total);
      canvas.drawArc(rect, start, sweep, true, Paint()..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => oldDelegate.slices != slices;
}
