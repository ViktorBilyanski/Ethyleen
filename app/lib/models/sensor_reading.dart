enum FreshnessLevel { fresh, warning, spoiled }

class SensorReading {
  final double mq135;
  final double mq3;
  final double mq9;
  final double temperature;
  final double humidity;
  final double battery;
  final FreshnessLevel freshness;
  final int timestamp;
  final double trendMq135;
  final double trendMq3;
  final double trendMq9;
  final double estHours; // estimated hours until spoiled (-1 = stable)

  SensorReading({
    required this.mq135,
    required this.mq3,
    required this.mq9,
    required this.temperature,
    required this.humidity,
    required this.battery,
    required this.freshness,
    required this.timestamp,
    this.trendMq135 = 0,
    this.trendMq3 = 0,
    this.trendMq9 = 0,
    this.estHours = -1,
  });

  factory SensorReading.fromMap(Map<dynamic, dynamic> map) {
    return SensorReading(
      mq135: (map['mq135'] ?? 0).toDouble(),
      mq3: (map['mq3'] ?? 0).toDouble(),
      mq9: (map['mq9'] ?? 0).toDouble(),
      temperature: (map['temperature'] ?? 0).toDouble(),
      humidity: (map['humidity'] ?? 0).toDouble(),
      battery: (map['battery'] ?? 0).toDouble(),
      freshness: _parseFreshness(map['freshness']),
      timestamp: (map['timestamp'] ?? 0).toInt(),
      trendMq135: (map['trend_mq135'] ?? 0).toDouble(),
      trendMq3: (map['trend_mq3'] ?? 0).toDouble(),
      trendMq9: (map['trend_mq9'] ?? 0).toDouble(),
      estHours: (map['est_hours'] ?? -1).toDouble(),
    );
  }

  static FreshnessLevel _parseFreshness(dynamic value) {
    switch (value?.toString()) {
      case 'warning':
        return FreshnessLevel.warning;
      case 'spoiled':
        return FreshnessLevel.spoiled;
      default:
        return FreshnessLevel.fresh;
    }
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  String get freshnessLabel {
    switch (freshness) {
      case FreshnessLevel.fresh:
        return 'FRESH';
      case FreshnessLevel.warning:
        return 'WARNING';
      case FreshnessLevel.spoiled:
        return 'SPOILED';
    }
  }
}
