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
}
