import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';

class HistoryChart extends StatefulWidget {
  final List<SensorReading> readings;

  const HistoryChart({super.key, required this.readings});

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  late double _minX;
  late double _maxX;
  late double _fullMinX;
  late double _fullMaxX;

  // For gesture tracking
  double? _scaleStartMinX;
  double? _scaleStartMaxX;
  double? _lastFocalX;
  double _chartWidth = 1;

  @override
  void initState() {
    super.initState();
    _resetZoom();
  }

  @override
  void didUpdateWidget(HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readings != oldWidget.readings) {
      _resetZoom();
    }
  }

  void _resetZoom() {
    if (widget.readings.isEmpty) return;
    _fullMinX = widget.readings.first.timestamp.toDouble();
    _fullMaxX = widget.readings.last.timestamp.toDouble();
    _minX = _fullMinX;
    _maxX = _fullMaxX;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readings.isEmpty) {
      return Center(
        child: Text('No history data yet',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
      );
    }

    final isZoomed = (_maxX - _minX) < (_fullMaxX - _fullMinX) * 0.98;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend + reset zoom
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _legendDot(const Color(0xFF42A5F5), 'NH3/CO2'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFAB47BC), 'Ethanol'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFFFA726), 'CH4/CO'),
              const Spacer(),
              if (isZoomed)
                GestureDetector(
                  onTap: () => setState(() => _resetZoom()),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Reset',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _chartWidth = constraints.maxWidth;
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onDoubleTap: () => setState(() => _resetZoom()),
                child: LineChart(
                  LineChartData(
                    minX: _minX,
                    maxX: _maxX,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getYInterval(),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value < 10
                                ? value.toStringAsFixed(1)
                                : '${value.toInt()}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11),
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
                            final range = _maxX - _minX;
                            final format = range < 3600
                                ? DateFormat.Hms()
                                : range < 86400
                                    ? DateFormat.Hm()
                                    : DateFormat.MMMd();
                            return Text(
                              format.format(dt),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _line(
                          widget.readings
                              .map((r) =>
                                  FlSpot(r.timestamp.toDouble(), r.mq135))
                              .toList(),
                          const Color(0xFF42A5F5)),
                      _line(
                          widget.readings
                              .map((r) =>
                                  FlSpot(r.timestamp.toDouble(), r.mq3))
                              .toList(),
                          const Color(0xFFAB47BC)),
                      _line(
                          widget.readings
                              .map((r) =>
                                  FlSpot(r.timestamp.toDouble(), r.mq9))
                              .toList(),
                          const Color(0xFFFFA726)),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Theme.of(context).colorScheme.surface,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final color = spot.bar.color ?? Colors.white;
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)} ppm',
                              TextStyle(color: color, fontSize: 12),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Zoom hint
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            isZoomed ? 'Pinch to zoom \u2022 Drag to pan \u2022 Double-tap to reset'
                : 'Pinch to zoom in',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), fontSize: 11),
          ),
        ),
      ],
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartMinX = _minX;
    _scaleStartMaxX = _maxX;
    _lastFocalX = details.localFocalPoint.dx;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_scaleStartMinX == null || _scaleStartMaxX == null) return;

    final startRange = _scaleStartMaxX! - _scaleStartMinX!;
    final fullRange = _fullMaxX - _fullMinX;
    final minRange = fullRange * 0.02; // max zoom: 2% of total range

    setState(() {
      if (details.scale != 1.0) {
        // Pinch zoom
        final newRange = (startRange / details.scale).clamp(minRange, fullRange);
        final focalRatio = details.localFocalPoint.dx / _chartWidth;
        final startCenter = _scaleStartMinX! + startRange * focalRatio;
        _minX = startCenter - newRange * focalRatio;
        _maxX = startCenter + newRange * (1 - focalRatio);
      } else {
        // Pan (single finger drag)
        final dx = details.localFocalPoint.dx - _lastFocalX!;
        _lastFocalX = details.localFocalPoint.dx;
        final currentRange = _maxX - _minX;
        final shift = -dx / _chartWidth * currentRange;
        _minX += shift;
        _maxX += shift;
      }

      // Clamp to data bounds
      if (_minX < _fullMinX) {
        _maxX += _fullMinX - _minX;
        _minX = _fullMinX;
      }
      if (_maxX > _fullMaxX) {
        _minX -= _maxX - _fullMaxX;
        _maxX = _fullMaxX;
      }
      _minX = _minX.clamp(_fullMinX, _fullMaxX);
      _maxX = _maxX.clamp(_fullMinX, _fullMaxX);
    });
  }

  double _getTimeInterval() {
    final range = _maxX - _minX;
    if (range < 600) return 60; // 1 min
    if (range < 3600) return 600; // 10 min
    if (range < 21600) return 3600; // 1 hour
    if (range < 86400) return 7200; // 2 hours
    return 21600; // 6 hours
  }

  double _getYInterval() {
    // Find max visible value for better grid
    double maxVal = 1;
    for (final r in widget.readings) {
      if (r.timestamp.toDouble() >= _minX && r.timestamp.toDouble() <= _maxX) {
        if (r.mq135 > maxVal) maxVal = r.mq135;
        if (r.mq3 > maxVal) maxVal = r.mq3;
        if (r.mq9 > maxVal) maxVal = r.mq9;
      }
    }
    if (maxVal < 2) return 0.5;
    if (maxVal < 10) return 2;
    if (maxVal < 50) return 10;
    return 20;
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
      ],
    );
  }
}
