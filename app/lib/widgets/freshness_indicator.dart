import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';

class FreshnessIndicator extends StatelessWidget {
  final FreshnessLevel level;

  const FreshnessIndicator({super.key, required this.level});

  Color get backgroundColor {
    switch (level) {
      case FreshnessLevel.fresh:
        return const Color(0xFF66BB6A);
      case FreshnessLevel.warning:
        return const Color(0xFFFFA726);
      case FreshnessLevel.spoiled:
        return const Color(0xFFE53935);
    }
  }

  IconData get icon {
    switch (level) {
      case FreshnessLevel.fresh:
        return Icons.check_circle_outline;
      case FreshnessLevel.warning:
        return Icons.warning_amber_rounded;
      case FreshnessLevel.spoiled:
        return Icons.dangerous_outlined;
    }
  }

  String get label {
    switch (level) {
      case FreshnessLevel.fresh:
        return 'FRESH';
      case FreshnessLevel.warning:
        return 'WARNING';
      case FreshnessLevel.spoiled:
        return 'SPOILED';
    }
  }

  String get description {
    switch (level) {
      case FreshnessLevel.fresh:
        return 'Everything looks good';
      case FreshnessLevel.warning:
        return 'Early spoilage signs detected';
      case FreshnessLevel.spoiled:
        return 'Food has gone bad';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor.withValues(alpha: 0.25),
            backgroundColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: backgroundColor, size: 48),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: backgroundColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
