import 'package:flutter/material.dart';
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
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
                          color: Colors.white.withValues(alpha: 0.4),
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
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF42A5F5) : Colors.white54,
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

    for (final r in _readings) {
      avgMq135 += r.mq135;
      avgMq3 += r.mq3;
      avgMq9 += r.mq9;
      if (r.mq135 > maxMq135) maxMq135 = r.mq135;
      if (r.mq3 > maxMq3) maxMq3 = r.mq3;
      if (r.mq9 > maxMq9) maxMq9 = r.mq9;
    }
    avgMq135 /= _readings.length;
    avgMq3 /= _readings.length;
    avgMq9 /= _readings.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary  (${_readings.length} readings)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _statRow('MQ-135', avgMq135, maxMq135),
          _statRow('MQ-3', avgMq3, maxMq3),
          _statRow('MQ-9', avgMq9, maxMq9),
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
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Text(
            'avg ${avg.toStringAsFixed(1)} ppm',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            'peak ${peak.toStringAsFixed(1)} ppm',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
