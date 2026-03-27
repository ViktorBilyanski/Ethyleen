import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';

class HistoryChart extends StatelessWidget {
  final List<SensorReading> readings;

  const HistoryChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(
        child: Text(
          'No history data yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _legendDot(const Color(0xFF42A5F5), 'NH3/CO2'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFAB47BC), 'Ethanol'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFFFA726), 'CH4/CO'),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _getTimeInterval(),
                    getTitlesWidget: (value, meta) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                          value.toInt() * 1000);
                      return Text(
                        DateFormat.Hm().format(dt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _line(readings.map((r) => FlSpot(
                    r.timestamp.toDouble(), r.mq135)).toList(),
                    const Color(0xFF42A5F5)),
                _line(readings.map((r) => FlSpot(
                    r.timestamp.toDouble(), r.mq3)).toList(),
                    const Color(0xFFAB47BC)),
                _line(readings.map((r) => FlSpot(
                    r.timestamp.toDouble(), r.mq9)).toList(),
                    const Color(0xFFFFA726)),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: const Color(0xFF2A2A3E),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getTimeInterval() {
    if (readings.length < 2) return 3600;
    final range = readings.last.timestamp - readings.first.timestamp;
    if (range < 3600) return 600; // 10 min
    if (range < 86400) return 3600; // 1 hour
    return 21600; // 6 hours
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
