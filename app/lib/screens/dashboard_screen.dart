import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
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
  Map<String, double> _thresholds = {
    'mq135_warning': 4.0, 'mq135_spoiled': 10.0,
    'mq3_warning': 0.5, 'mq3_spoiled': 2.0,
    'mq9_warning': 1.5, 'mq9_spoiled': 5.0,
  };
  Map<String, dynamic>? _calibrationData;
  List<SensorReading>? _history;

  @override
  void initState() {
    super.initState();
    _firebase.thresholdsStream.listen((t) {
      setState(() => _thresholds = t);
    });
    _firebase.calibrationStream.listen((data) {
      setState(() => _calibrationData = data);
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _firebase.getHistory(hours: 24);
    if (mounted) setState(() => _history = history);
  }

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
                    size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'No sensor data yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your Ethyleen device is powered on\nand connected to WiFi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF42A5F5),
          backgroundColor: Theme.of(context).colorScheme.surface,
          onRefresh: () async {
            await _loadHistory();
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Freshness status (tappable)
              GestureDetector(
                onTap: () => _showFreshnessDetail(reading),
                child: FreshnessIndicator(level: reading.freshness),
              ),
              const SizedBox(height: 8),

              // Last updated + environment bar
              _buildStatusBar(reading),
              const SizedBox(height: 24),

              // Sensor gauges (tappable)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSensorDetail(
                        'MQ-135', 'Ammonia / CO2', reading.mq135,
                        reading.trendMq135,
                        _thresholds['mq135_warning']!,
                        _thresholds['mq135_spoiled']!,
                        'Detects ammonia and carbon dioxide gases. '
                        'These rise when proteins break down in meat, fish, dairy, and eggs. '
                        'A rising MQ-135 usually means animal-based products are spoiling.',
                        ['Meat', 'Fish', 'Dairy', 'Eggs'],
                      ),
                      child: SensorGauge(
                        label: 'MQ-135',
                        gasName: 'NH3 / CO2',
                        value: reading.mq135,
                        maxValue: _thresholds['mq135_spoiled']! * 2,
                        warningThreshold: _thresholds['mq135_warning']!,
                        spoiledThreshold: _thresholds['mq135_spoiled']!,
                        trend: reading.trendMq135,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSensorDetail(
                        'MQ-3', 'Ethanol', reading.mq3,
                        reading.trendMq3,
                        _thresholds['mq3_warning']!,
                        _thresholds['mq3_spoiled']!,
                        'Detects ethanol produced during fermentation. '
                        'Fruits, vegetables, and bread release ethanol as they break down. '
                        'This sensor is less sensitive in cold environments.',
                        ['Fruits', 'Vegetables', 'Bread', 'Juice'],
                      ),
                      child: SensorGauge(
                        label: 'MQ-3',
                        gasName: 'Ethanol',
                        value: reading.mq3,
                        maxValue: _thresholds['mq3_spoiled']! * 2,
                        warningThreshold: _thresholds['mq3_warning']!,
                        spoiledThreshold: _thresholds['mq3_spoiled']!,
                        trend: reading.trendMq3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSensorDetail(
                        'MQ-9', 'Methane / CO', reading.mq9,
                        reading.trendMq9,
                        _thresholds['mq9_warning']!,
                        _thresholds['mq9_spoiled']!,
                        'Detects methane and carbon monoxide from anaerobic bacteria. '
                        'These gases appear in tightly sealed containers where food decays '
                        'without oxygen. Indicates deep, advanced spoilage.',
                        ['Sealed leftovers', 'Vacuum-packed food', 'Canned goods'],
                      ),
                      child: SensorGauge(
                        label: 'MQ-9',
                        gasName: 'CH4 / CO',
                        value: reading.mq9,
                        maxValue: _thresholds['mq9_spoiled']! * 2,
                        warningThreshold: _thresholds['mq9_warning']!,
                        spoiledThreshold: _thresholds['mq9_spoiled']!,
                        trend: reading.trendMq9,
                      ),
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

              // Fridge environment card (tappable)
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showEnvironmentDetail(reading),
                child: _buildEnvironmentCard(reading),
              ),

              // Device status card (tappable)
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showDeviceDetail(reading),
                child: _buildDeviceStatusCard(reading),
              ),

              // Daily summary card (tappable)
              if (_history != null && _history!.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showSummaryDetail(),
                  child: _buildDailySummaryCard(),
                ),
              ],

              const SizedBox(height: 20),
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
        // Last updated (live ticking)
        _LiveTimestamp(dateTime: reading.dateTime),
        const SizedBox(width: 16),
        // Temperature
        Icon(Icons.thermostat, size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 2),
        Text(
          '${reading.temperature.toStringAsFixed(1)}°C',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        // Humidity
        Icon(Icons.water_drop_outlined, size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 2),
        Text(
          '${reading.humidity.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: isDark ? null : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ==================== Detail Bottom Sheets ====================

  void _showSheet(String title, Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)),
          Text(value, style: TextStyle(
            color: valueColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
            fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showFreshnessDetail(SensorReading reading) {
    final color = reading.freshness == FreshnessLevel.fresh
        ? const Color(0xFF66BB6A)
        : reading.freshness == FreshnessLevel.warning
            ? const Color(0xFFFFA726)
            : const Color(0xFFE53935);

    _showSheet('Freshness Status', Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Status', reading.freshnessLabel, valueColor: color),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        _detailRow('MQ-135 (NH3/CO2)', '${reading.mq135.toStringAsFixed(1)} ppm',
          valueColor: reading.mq135 >= _thresholds['mq135_warning']!
              ? const Color(0xFFFFA726) : null),
        _detailRow('MQ-3 (Ethanol)', '${reading.mq3.toStringAsFixed(1)} ppm',
          valueColor: reading.mq3 >= _thresholds['mq3_warning']!
              ? const Color(0xFFFFA726) : null),
        _detailRow('MQ-9 (Methane/CO)', '${reading.mq9.toStringAsFixed(1)} ppm',
          valueColor: reading.mq9 >= _thresholds['mq9_warning']!
              ? const Color(0xFFFFA726) : null),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        const SizedBox(height: 4),
        Text(
          reading.freshness == FreshnessLevel.fresh
              ? 'All sensors are within normal range. Your food is safe.'
              : reading.freshness == FreshnessLevel.warning
                  ? 'Some gases are elevated. Consider checking your food soon and using anything that might be going off.'
                  : 'Significant spoilage gases detected. Check your fridge immediately and discard any spoiled items.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
        ),
      ],
    ));
  }

  void _showSensorDetail(String name, String gasName, double value,
      double trend, double warning, double spoiled,
      String description, List<String> foods) {
    final status = value >= spoiled ? 'SPOILED'
        : value >= warning ? 'WARNING' : 'NORMAL';
    final statusColor = value >= spoiled ? const Color(0xFFE53935)
        : value >= warning ? const Color(0xFFFFA726) : const Color(0xFF66BB6A);
    final trendText = trend > 0.1 ? 'Rising (+${trend.toStringAsFixed(2)}/reading)'
        : trend < -0.1 ? 'Falling (${trend.toStringAsFixed(2)}/reading)'
        : 'Stable';

    _showSheet(name, Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Gas', gasName),
        _detailRow('Current', '${value.toStringAsFixed(2)} ppm', valueColor: statusColor),
        _detailRow('Status', status, valueColor: statusColor),
        _detailRow('Trend', trendText),
        _detailRow('Warning threshold', '${warning.toStringAsFixed(2)} ppm'),
        _detailRow('Spoiled threshold', '${spoiled.toStringAsFixed(2)} ppm'),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        Text(description, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: foods.map((f) => Chip(
            label: Text(f, style: const TextStyle(fontSize: 12)),
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    ));
  }

  void _showEnvironmentDetail(SensorReading reading) {
    final s = SettingsService();
    final tempOk = reading.temperature >= s.idealTempMin && reading.temperature <= s.idealTempMax;
    final humOk = reading.humidity >= s.idealHumidityMin && reading.humidity <= s.idealHumidityMax;

    _showSheet('Environment', Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Temperature', '${reading.temperature.toStringAsFixed(1)}°C',
          valueColor: tempOk ? const Color(0xFF66BB6A) : const Color(0xFFFFA726)),
        _detailRow('Ideal range', '${s.idealTempMin.toStringAsFixed(0)} - ${s.idealTempMax.toStringAsFixed(0)}°C'),
        _detailRow('Humidity', '${reading.humidity.toStringAsFixed(1)}%',
          valueColor: humOk ? const Color(0xFF66BB6A) : const Color(0xFFFFA726)),
        _detailRow('Ideal range', '${s.idealHumidityMin.toStringAsFixed(0)} - ${s.idealHumidityMax.toStringAsFixed(0)}%'),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        Text(
          !tempOk && reading.temperature > s.idealTempMax
              ? 'Temperature is too high. Food spoils faster above ${s.idealTempMax.toStringAsFixed(0)}°C.'
              : !tempOk && reading.temperature < s.idealTempMin
                  ? 'Temperature is too low. Below ${s.idealTempMin.toStringAsFixed(0)}°C may affect food quality.'
                  : !humOk && reading.humidity > s.idealHumidityMax
                      ? 'Humidity is high, which can promote mold growth.'
                      : !humOk && reading.humidity < s.idealHumidityMin
                          ? 'Humidity is low. This can dry out uncovered food.'
                          : 'Temperature and humidity are in the ideal range.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
        ),
      ],
    ));
  }

  void _showDeviceDetail(SensorReading reading) {
    final hoursLeft = (reading.battery / 100.0 * 10000 / 600);
    String calibrationText = 'Never calibrated';
    if (_calibrationData != null && _calibrationData!['timestamp'] != null) {
      final calTime = DateTime.fromMillisecondsSinceEpoch(
          (_calibrationData!['timestamp'] as num).toInt() * 1000);
      calibrationText = DateFormat('MMM d, HH:mm').format(calTime);
    }

    _showSheet('Device Status', Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Battery', '${reading.battery.toStringAsFixed(0)}%',
          valueColor: reading.battery > 30 ? const Color(0xFF66BB6A)
              : reading.battery > 15 ? const Color(0xFFFFA726)
              : const Color(0xFFE53935)),
        _detailRow('Estimated runtime', '~${hoursLeft.toStringAsFixed(1)} hours left'),
        _detailRow('Power bank', '10000 mAh @ ~600 mA draw'),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        _detailRow('Last calibration', calibrationText),
        if (_calibrationData != null) ...[
          _detailRow('MQ-135 R0',
              '${(_calibrationData!['mq135_r0'] ?? '-').toString()}'),
          _detailRow('MQ-3 R0',
              '${(_calibrationData!['mq3_r0'] ?? '-').toString()}'),
          _detailRow('MQ-9 R0',
              '${(_calibrationData!['mq9_r0'] ?? '-').toString()}'),
        ],
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        _detailRow('Connection', 'Online', valueColor: const Color(0xFF66BB6A)),
        _detailRow('Device ID', 'ethyleen-001'),
      ],
    ));
  }

  void _showSummaryDetail() {
    final history = _history!;
    if (history.isEmpty) return;

    double peakMq135 = 0, peakMq3 = 0, peakMq9 = 0;
    double minTemp = 999, maxTemp = -999;
    double sumTemp = 0, sumHum = 0;
    double sumMq135 = 0, sumMq3 = 0, sumMq9 = 0;
    int warningCount = 0, spoiledCount = 0;

    for (final r in history) {
      if (r.mq135 > peakMq135) peakMq135 = r.mq135;
      if (r.mq3 > peakMq3) peakMq3 = r.mq3;
      if (r.mq9 > peakMq9) peakMq9 = r.mq9;
      if (r.temperature < minTemp) minTemp = r.temperature;
      if (r.temperature > maxTemp) maxTemp = r.temperature;
      sumTemp += r.temperature;
      sumHum += r.humidity;
      sumMq135 += r.mq135;
      sumMq3 += r.mq3;
      sumMq9 += r.mq9;
      if (r.freshness == FreshnessLevel.warning) warningCount++;
      if (r.freshness == FreshnessLevel.spoiled) spoiledCount++;
    }

    final n = history.length;

    _showSheet('Last 24 Hours', Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow('Total readings', '$n'),
        _detailRow('Warning readings', '$warningCount',
          valueColor: warningCount > 0 ? const Color(0xFFFFA726) : null),
        _detailRow('Spoiled readings', '$spoiledCount',
          valueColor: spoiledCount > 0 ? const Color(0xFFE53935) : null),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        _detailRow('Avg temperature', '${(sumTemp / n).toStringAsFixed(1)}°C'),
        _detailRow('Temp range', '${minTemp.toStringAsFixed(1)} - ${maxTemp.toStringAsFixed(1)}°C'),
        _detailRow('Avg humidity', '${(sumHum / n).toStringAsFixed(0)}%'),
        Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
        _detailRow('MQ-135 avg / peak',
            '${(sumMq135 / n).toStringAsFixed(1)} / ${peakMq135.toStringAsFixed(1)} ppm'),
        _detailRow('MQ-3 avg / peak',
            '${(sumMq3 / n).toStringAsFixed(1)} / ${peakMq3.toStringAsFixed(1)} ppm'),
        _detailRow('MQ-9 avg / peak',
            '${(sumMq9 / n).toStringAsFixed(1)} / ${peakMq9.toStringAsFixed(1)} ppm'),
      ],
    ));
  }

  // ==================== Fridge Environment Card ====================

  Widget _buildEnvironmentCard(SensorReading reading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fridge Environment',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildEnvRow(
            icon: Icons.thermostat,
            label: 'Temperature',
            value: '${reading.temperature.toStringAsFixed(1)}°C',
            current: reading.temperature,
            idealMin: SettingsService().idealTempMin,
            idealMax: SettingsService().idealTempMax,
            absMin: -5,
            absMax: 35,
          ),
          const SizedBox(height: 12),
          _buildEnvRow(
            icon: Icons.water_drop_outlined,
            label: 'Humidity',
            value: '${reading.humidity.toStringAsFixed(0)}%',
            current: reading.humidity,
            idealMin: SettingsService().idealHumidityMin,
            idealMax: SettingsService().idealHumidityMax,
            absMin: 0,
            absMax: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildEnvRow({
    required IconData icon,
    required String label,
    required String value,
    required double current,
    required double idealMin,
    required double idealMax,
    required double absMin,
    required double absMax,
  }) {
    final inRange = current >= idealMin && current <= idealMax;
    final color = inRange
        ? const Color(0xFF66BB6A)
        : (current < idealMin - 5 || current > idealMax + 5)
            ? const Color(0xFFE53935)
            : const Color(0xFFFFA726);
    final range = absMax - absMin;
    final pos = ((current - absMin) / range).clamp(0.0, 1.0);
    final idealStart = ((idealMin - absMin) / range).clamp(0.0, 1.0);
    final idealEnd = ((idealMax - absMin) / range).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(
              inRange ? 'Ideal' : '${idealMin.toInt()}-${idealMax.toInt()} ideal',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(
              size: const Size(double.infinity, 6),
              painter: _RangeBarPainter(
                pos: pos,
                idealStart: idealStart,
                idealEnd: idealEnd,
                dotColor: color,
                bgColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                idealColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== Device Status Card ====================

  Widget _buildDeviceStatusCard(SensorReading reading) {
    final batteryHoursLeft =
        (reading.battery / 100.0 * 10000 / 600).round(); // rough estimate

    String calibrationText = 'Never';
    if (_calibrationData != null && _calibrationData!['timestamp'] != null) {
      final calTime = DateTime.fromMillisecondsSinceEpoch(
          (_calibrationData!['timestamp'] as num).toInt() * 1000);
      final diff = DateTime.now().difference(calTime);
      if (diff.inMinutes < 60) {
        calibrationText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        calibrationText = '${diff.inHours}h ago';
      } else {
        calibrationText = '${diff.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Status',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusItem(
                Icons.battery_std,
                '${reading.battery.toStringAsFixed(0)}%',
                '~${batteryHoursLeft}h left',
                reading.battery > 30
                    ? const Color(0xFF66BB6A)
                    : reading.battery > 15
                        ? const Color(0xFFFFA726)
                        : const Color(0xFFE53935),
              ),
              _buildStatusItem(
                Icons.wifi,
                'Connected',
                'Online',
                const Color(0xFF66BB6A),
              ),
              _buildStatusItem(
                Icons.tune,
                'Calibrated',
                calibrationText,
                const Color(0xFF42A5F5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
      IconData icon, String title, String subtitle, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 11)),
        ],
      ),
    );
  }

  // ==================== Daily Summary Card ====================

  Widget _buildDailySummaryCard() {
    final history = _history!;
    if (history.isEmpty) return const SizedBox.shrink();

    double peakMq135 = 0, peakMq3 = 0, peakMq9 = 0;
    double sumTemp = 0, sumHumidity = 0;
    int warningCount = 0, spoiledCount = 0;

    for (final r in history) {
      if (r.mq135 > peakMq135) peakMq135 = r.mq135;
      if (r.mq3 > peakMq3) peakMq3 = r.mq3;
      if (r.mq9 > peakMq9) peakMq9 = r.mq9;
      sumTemp += r.temperature;
      sumHumidity += r.humidity;
      if (r.freshness == FreshnessLevel.warning) warningCount++;
      if (r.freshness == FreshnessLevel.spoiled) spoiledCount++;
    }

    final avgTemp = sumTemp / history.length;
    final avgHumidity = sumHumidity / history.length;

    final statusText = spoiledCount > 0
        ? '$spoiledCount spoiled readings'
        : warningCount > 0
            ? '$warningCount warning readings'
            : 'All stable';
    final statusColor = spoiledCount > 0
        ? const Color(0xFFE53935)
        : warningCount > 0
            ? const Color(0xFFFFA726)
            : const Color(0xFF66BB6A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 24 Hours',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryItem(
                  'Avg Temp', '${avgTemp.toStringAsFixed(1)}°C'),
              _buildSummaryItem(
                  'Avg Humidity', '${avgHumidity.toStringAsFixed(0)}%'),
              _buildSummaryItem(
                  'Readings', '${history.length}'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSummaryItem(
                  'Peak NH3', '${peakMq135.toStringAsFixed(1)}'),
              _buildSummaryItem(
                  'Peak EtOH', '${peakMq3.toStringAsFixed(1)}'),
              _buildSummaryItem(
                  'Peak CH4', '${peakMq9.toStringAsFixed(1)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 11)),
        ],
      ),
    );
  }

  // ==================== Spoilage Explanation ====================

  Widget _buildSpoilageExplanation(SensorReading reading) {
    final explanations = <String>[];

    if (reading.mq135 >= _thresholds['mq135_warning']!) {
      explanations
          .add('Ammonia levels rising — likely protein breakdown in meat or dairy');
    }
    if (reading.mq3 >= _thresholds['mq3_warning']!) {
      explanations
          .add('Ethanol detected — fermentation in fruits, vegetables, or bread');
    }
    if (reading.mq9 >= _thresholds['mq9_warning']!) {
      explanations
          .add('Methane/CO detected — anaerobic bacteria in sealed food');
    }

    if (explanations.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What does this mean?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

class _LiveTimestamp extends StatefulWidget {
  final DateTime dateTime;
  const _LiveTimestamp({required this.dateTime});

  @override
  State<_LiveTimestamp> createState() => _LiveTimestampState();
}

class _LiveTimestampState extends State<_LiveTimestamp> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(widget.dateTime);
    final String text;
    if (diff.inSeconds < 60) {
      text = 'Updated ${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      text = 'Updated ${diff.inMinutes}m ago';
    } else {
      text = 'Updated ${DateFormat('HH:mm').format(widget.dateTime)}';
    }
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        fontSize: 12,
      ),
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  final double pos;
  final double idealStart;
  final double idealEnd;
  final Color dotColor;
  final Color bgColor;
  final Color idealColor;

  _RangeBarPainter({
    required this.pos,
    required this.idealStart,
    required this.idealEnd,
    required this.dotColor,
    required this.bgColor,
    required this.idealColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = bgColor;
    final idealPaint = Paint()..color = idealColor;
    final dotPaint = Paint()..color = dotColor;

    // Background
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(3)),
        bgPaint);

    // Ideal range
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(idealStart * size.width, 0,
                (idealEnd - idealStart) * size.width, size.height),
            const Radius.circular(3)),
        idealPaint);

    // Current position dot
    final dotX = pos * size.width;
    canvas.drawCircle(Offset(dotX, size.height / 2), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RangeBarPainter old) =>
      pos != old.pos || dotColor != old.dotColor;
}
