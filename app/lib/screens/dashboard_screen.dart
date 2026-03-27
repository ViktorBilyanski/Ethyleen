import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';
import '../services/firebase_service.dart';
import '../widgets/sensor_gauge.dart';
import '../widgets/freshness_indicator.dart';
import '../widgets/recipe_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebase = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SensorReading?>(
      stream: _firebase.latestReadingStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
          );
        }

        final reading = snapshot.data;
        if (reading == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors_off,
                    size: 64, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'No sensor data yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your Ethyleen device is powered on\nand connected to WiFi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF1E1E2E),
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Freshness status
              FreshnessIndicator(level: reading.freshness),
              const SizedBox(height: 8),

              // Last updated + environment bar
              _buildStatusBar(reading),
              const SizedBox(height: 24),

              // Sensor gauges
              Row(
                children: [
                  Expanded(
                    child: SensorGauge(
                      label: 'MQ-135',
                      gasName: 'NH3 / CO2',
                      value: reading.mq135,
                      maxValue: 150,
                      warningThreshold: 30,
                      spoiledThreshold: 80,
                      trend: reading.trendMq135,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SensorGauge(
                      label: 'MQ-3',
                      gasName: 'Ethanol',
                      value: reading.mq3,
                      maxValue: 100,
                      warningThreshold: 15,
                      spoiledThreshold: 50,
                      trend: reading.trendMq3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SensorGauge(
                      label: 'MQ-9',
                      gasName: 'CH4 / CO',
                      value: reading.mq9,
                      maxValue: 120,
                      warningThreshold: 20,
                      spoiledThreshold: 60,
                      trend: reading.trendMq9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Spoilage explanation (when not fresh)
              if (reading.freshness != FreshnessLevel.fresh) ...[
                _buildSpoilageExplanation(reading),
                const SizedBox(height: 16),
              ],

              // Recipe suggestion (only when warning/spoiled)
              if (reading.freshness != FreshnessLevel.fresh)
                StreamBuilder<String?>(
                  stream: _firebase.recipeStream,
                  builder: (context, recipeSnap) {
                    final recipe = recipeSnap.data;
                    if (recipe == null || recipe.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RecipeCard(recipe: recipe),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(SensorReading reading) {
    final batteryColor = reading.battery > 30
        ? const Color(0xFF66BB6A)
        : reading.battery > 15
            ? const Color(0xFFFFA726)
            : const Color(0xFFE53935);

    final batteryIcon = reading.battery > 80
        ? Icons.battery_full
        : reading.battery > 50
            ? Icons.battery_5_bar
            : reading.battery > 20
                ? Icons.battery_3_bar
                : Icons.battery_1_bar;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Last updated
        Text(
          'Updated ${_formatTime(reading)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 16),
        // Temperature
        Icon(Icons.thermostat, size: 14,
            color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 2),
        Text(
          '${reading.temperature.toStringAsFixed(1)}°C',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        // Humidity
        Icon(Icons.water_drop_outlined, size: 14,
            color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 2),
        Text(
          '${reading.humidity.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        // Battery
        Icon(batteryIcon, size: 14, color: batteryColor),
        const SizedBox(width: 2),
        Text(
          '${reading.battery.toStringAsFixed(0)}%',
          style: TextStyle(
            color: batteryColor.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatTime(SensorReading reading) {
    final dt = reading.dateTime;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }

  Widget _buildSpoilageExplanation(SensorReading reading) {
    final explanations = <String>[];

    if (reading.mq135 >= 30) {
      explanations
          .add('Ammonia levels rising — likely protein breakdown in meat or dairy');
    }
    if (reading.mq3 >= 15) {
      explanations
          .add('Ethanol detected — fermentation in fruits, vegetables, or bread');
    }
    if (reading.mq9 >= 20) {
      explanations
          .add('Methane/CO detected — anaerobic bacteria in sealed food');
    }

    if (explanations.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What does this mean?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...explanations.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('  ', style: TextStyle(color: Colors.white54)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
