import 'dart:math';
import 'package:flutter/material.dart';

class SensorGauge extends StatelessWidget {
  final String label;
  final String gasName;
  final double value;
  final double maxValue;
  final double warningThreshold;
  final double spoiledThreshold;
  final double trend;

  const SensorGauge({
    super.key,
    required this.label,
    required this.gasName,
    required this.value,
    required this.maxValue,
    required this.warningThreshold,
    required this.spoiledThreshold,
    this.trend = 0,
  });

  Color get gaugeColor {
    if (value >= spoiledThreshold) return const Color(0xFFE53935);
    if (value >= warningThreshold) return const Color(0xFFFFA726);
    return const Color(0xFF66BB6A);
  }

  String get trendArrow {
    if (trend > 0.5) return ' ^';
    if (trend < -0.5) return ' v';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gaugeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            gasName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _GaugePainter(
                value: value,
                maxValue: maxValue,
                color: gaugeColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)}$trendArrow',
                      style: TextStyle(
                        color: gaugeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'ppm',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.75 * pi,
      1.5 * pi,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweep = (value / maxValue).clamp(0.0, 1.0) * 1.5 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.75 * pi,
      sweep,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
