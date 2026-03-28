import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_reading.dart';

class FirebaseService {
  static const String deviceId = 'ethyleen-001';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Stream of the latest reading (real-time updates)
  Stream<SensorReading?> get latestReadingStream {
    return _db.child('readings/$deviceId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return SensorReading.fromMap(data as Map<dynamic, dynamic>);
    });
  }

  /// Fetch history entries for the past [hours] hours
  Future<List<SensorReading>> getHistory({int hours = 24}) async {
    final cutoff =
        DateTime.now().subtract(Duration(hours: hours)).millisecondsSinceEpoch ~/
            1000;

    final snapshot = await _db
        .child('history/$deviceId')
        .orderByChild('timestamp')
        .startAt(cutoff)
        .get();

    if (!snapshot.exists) return [];

    final List<SensorReading> readings = [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    data.forEach((key, value) {
      if (value is Map) {
        readings.add(SensorReading.fromMap(value));
      }
    });

    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return readings;
  }

  /// Stream of the latest recipe suggestion
  Stream<String?> get recipeStream {
    return _db.child('recipes/$deviceId/recipe').onValue.map((event) {
      return event.snapshot.value as String?;
    });
  }

  /// Send calibration command to the device
  Future<void> startCalibration() async {
    // Clear old calibration result so the stream doesn't fire immediately
    await _db.child('calibration/$deviceId').remove();
    await _db.child('commands/$deviceId/calibrate').set(true);
  }

  /// Stream of calibration status from the device
  Stream<Map<String, dynamic>?> get calibrationStream {
    return _db.child('calibration/$deviceId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    });
  }

  /// Fetch current thresholds from the last calibration
  Future<Map<String, double>> getThresholds() async {
    final snapshot = await _db.child('calibration/$deviceId').get();
    if (!snapshot.exists) {
      return {
        'mq135_warning': 4.0, 'mq135_spoiled': 10.0,
        'mq3_warning': 0.5, 'mq3_spoiled': 2.0,
        'mq9_warning': 1.5, 'mq9_spoiled': 5.0,
      };
    }
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return {
      'mq135_warning': (data['mq135_warning'] ?? 4.0).toDouble(),
      'mq135_spoiled': (data['mq135_spoiled'] ?? 10.0).toDouble(),
      'mq3_warning': (data['mq3_warning'] ?? 0.5).toDouble(),
      'mq3_spoiled': (data['mq3_spoiled'] ?? 2.0).toDouble(),
      'mq9_warning': (data['mq9_warning'] ?? 1.5).toDouble(),
      'mq9_spoiled': (data['mq9_spoiled'] ?? 5.0).toDouble(),
    };
  }

  /// Stream thresholds (updates when calibration completes)
  Stream<Map<String, double>> get thresholdsStream {
    return _db.child('calibration/$deviceId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return {
          'mq135_warning': 4.0, 'mq135_spoiled': 10.0,
          'mq3_warning': 0.5, 'mq3_spoiled': 2.0,
          'mq9_warning': 1.5, 'mq9_spoiled': 5.0,
        };
      }
      final map = Map<String, dynamic>.from(data as Map);
      return {
        'mq135_warning': (map['mq135_warning'] ?? 4.0).toDouble(),
        'mq135_spoiled': (map['mq135_spoiled'] ?? 10.0).toDouble(),
        'mq3_warning': (map['mq3_warning'] ?? 0.5).toDouble(),
        'mq3_spoiled': (map['mq3_spoiled'] ?? 2.0).toDouble(),
        'mq9_warning': (map['mq9_warning'] ?? 1.5).toDouble(),
        'mq9_spoiled': (map['mq9_spoiled'] ?? 5.0).toDouble(),
      };
    });
  }
}
