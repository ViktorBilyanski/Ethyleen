import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';
import '../services/firebase_service.dart';
import '../widgets/history_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebase = FirebaseService();
  int _selectedHours = 24;
  List<SensorReading> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final readings = await _firebase.getHistory(hours: _selectedHours);
    setState(() {
      _readings = readings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range selector
          Row(
            children: [
              Text(
                'History',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_readings.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  tooltip: 'Export CSV',
                  onPressed: _exportCsv,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              _timeButton(6, '6h'),
              const SizedBox(width: 8),
              _timeButton(24, '24h'),
              const SizedBox(width: 8),
              _timeButton(72, '3d'),
              const SizedBox(width: 8),
              _timeButton(168, '7d'),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              ),
            )
          else
            Expanded(
              child: _readings.isEmpty
                  ? Center(
                      child: Text(
                        'No data for the selected period',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        HistoryChart(readings: _readings),
                        const SizedBox(height: 20),
                        // Stats summary
                        _buildStats(),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,datetime,mq135,mq3,mq9,temperature,humidity,battery,freshness');
    for (final r in _readings) {
      buffer.writeln(
        '${r.timestamp},${r.dateTime.toIso8601String()},${r.mq135},${r.mq3},'
        '${r.mq9},${r.temperature},${r.humidity},${r.battery},${r.freshnessLabel}');
    }
    // Copy CSV to clipboard
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_readings.length} readings copied to clipboard as CSV'),
          backgroundColor: const Color(0xFF66BB6A),
        ),
      );
    }
  }

  Widget _timeButton(int hours, String label) {
    final selected = _selectedHours == hours;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedHours = hours);
        _loadHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF42A5F5)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF42A5F5) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    if (_readings.isEmpty) return const SizedBox.shrink();

    double avgMq135 = 0, avgMq3 = 0, avgMq9 = 0;
    double maxMq135 = 0, maxMq3 = 0, maxMq9 = 0;
    int peakIndex = 0;
    double peakVal = 0;
    int freshCount = 0, warningCount = 0, spoiledCount = 0;

    for (int i = 0; i < _readings.length; i++) {
      final r = _readings[i];
      avgMq135 += r.mq135;
      avgMq3 += r.mq3;
      avgMq9 += r.mq9;
      if (r.mq135 > maxMq135) maxMq135 = r.mq135;
      if (r.mq3 > maxMq3) maxMq3 = r.mq3;
      if (r.mq9 > maxMq9) maxMq9 = r.mq9;

      // Track peak across all sensors
      final maxOfReading = [r.mq135, r.mq3, r.mq9].reduce((a, b) => a > b ? a : b);
      if (maxOfReading > peakVal) {
        peakVal = maxOfReading;
        peakIndex = i;
      }

      // Count states
      switch (r.freshness) {
        case FreshnessLevel.fresh: freshCount++;
        case FreshnessLevel.warning: warningCount++;
        case FreshnessLevel.spoiled: spoiledCount++;
      }
    }
    avgMq135 /= _readings.length;
    avgMq3 /= _readings.length;
    avgMq9 /= _readings.length;

    final total = _readings.length;
    final freshPct = freshCount / total;
    final warningPct = warningCount / total;
    final spoiledPct = spoiledCount / total;

    // Calculate time in each state (based on reading interval ~30s)
    final intervalSec = total > 1
        ? (_readings.last.timestamp - _readings.first.timestamp) / (total - 1)
        : 30;
    String formatDuration(int count) {
      final totalMin = (count * intervalSec / 60).round();
      if (totalMin < 60) return '${totalMin}m';
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    final peakTime = _readings[peakIndex].dateTime;

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
            'Summary  (${_readings.length} readings)',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Time in each state bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (freshPct > 0)
                    Expanded(
                      flex: (freshPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFF66BB6A)),
                    ),
                  if (warningPct > 0)
                    Expanded(
                      flex: (warningPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFFFA726)),
                    ),
                  if (spoiledPct > 0)
                    Expanded(
                      flex: (spoiledPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFE53935)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // State labels
          Row(
            children: [
              _stateLabel(const Color(0xFF66BB6A), 'Fresh',
                  formatDuration(freshCount)),
              if (warningCount > 0)
                _stateLabel(const Color(0xFFFFA726), 'Warning',
                    formatDuration(warningCount)),
              if (spoiledCount > 0)
                _stateLabel(const Color(0xFFE53935), 'Spoiled',
                    formatDuration(spoiledCount)),
            ],
          ),
          const SizedBox(height: 14),

          // Peak time
          Row(
            children: [
              Icon(Icons.show_chart, size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Highest reading at ${DateFormat.Hm().format(peakTime)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                '(${peakVal.toStringAsFixed(1)} ppm)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sensor stats
          _statRow('MQ-135', avgMq135, maxMq135),
          _statRow('MQ-3', avgMq3, maxMq3),
          _statRow('MQ-9', avgMq9, maxMq9),
        ],
      ),
    );
  }

  Widget _stateLabel(Color color, String label, String duration) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('$label $duration',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statRow(String label, double avg, double peak) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
          ),
          Text(
            'avg ${avg.toStringAsFixed(1)} ppm',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            'peak ${peak.toStringAsFixed(1)} ppm',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
