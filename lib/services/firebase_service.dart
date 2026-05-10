import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';
import '../models/system_control.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Recursively converts a Firebase map (Map<Object?, Object?>) to
  /// Map<String, dynamic> so Dart type casts work on all platforms.
  /// Android Firebase SDK returns nested maps as Map<Object?, Object?>,
  /// while web returns them as Map<String, dynamic>. This normalises both.
  static Map<String, dynamic> _deepConvert(Map<dynamic, dynamic> raw) {
    return Map<String, dynamic>.fromEntries(
      raw.entries.map((e) {
        final key = e.key?.toString() ?? '';
        final val = e.value;
        if (val is Map) {
          return MapEntry(key, _deepConvert(val as Map<dynamic, dynamic>));
        }
        return MapEntry(key, val);
      }),
    );
  }

  /// Latest sensor reading (temperature + soil moisture).
  Stream<SensorData> get sensorDataStream {
    return _db.ref('sensor_data/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return const SensorData(temperature: 0, soilMoisture: 0, timestamp: '');
      }
      return SensorData.fromMap(raw as Map<dynamic, dynamic>);
    });
  }

  /// Latest ETc value.
  Stream<double> get etcStream {
    return _db
        .ref('etc_calculation/latest/etc_value')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toDouble() ?? 0.0);
  }

  /// System control state (mode + pump status).
  Stream<SystemControl> get systemControlStream {
    return _db.ref('system_control').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return const SystemControl(
          mode: 'ETC_FUZZY',
          pumpStatus: false,
          flowRateMlPerSec: 20,
        );
      }
      return SystemControl.fromMap(raw as Map<dynamic, dynamic>);
    });
  }

  /// Latest irrigation log entry.
  Stream<Map<String, dynamic>> get irrigationLogStream {
    return _db.ref('irrigation_log/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(raw as Map);
    });
  }


  /// All sensor history records across all dates, sorted by timestamp ascending.
  /// Structure: sensor_data/history/{YYYY-MM-DD}/{key} → {soil_moisture, temperature, timestamp}
  Stream<List<SensorData>> get sensorHistoryStream {
    return _db.ref('sensor_data/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];
      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];
      for (final dateEntry in dateMap.values) {
        if (dateEntry is! Map) continue;
        final records = _deepConvert(dateEntry as Map<dynamic, dynamic>);
        for (final v in records.values) {
          if (v is Map) {
            list.add(SensorData.fromMap(_deepConvert(v as Map<dynamic, dynamic>)));
          }
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Sensor history for TODAY only — reads directly from
  /// sensor_data/history/{YYYY-MM-DD} for efficiency (no full-scan needed).
  Stream<List<SensorData>> get sensorTodayStream {
    final todayStr = _todayDateString();
    return _db.ref('sensor_data/history/$todayStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];
      final map = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];
      for (final v in map.values) {
        if (v is Map) {
          list.add(SensorData.fromMap(_deepConvert(v as Map<dynamic, dynamic>)));
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Irrigation history for TODAY only — reads directly from
  /// irrigation_log/history/{YYYY-MM-DD} (nested structure, same as sensor).
  Stream<List<Map<String, dynamic>>> get irrigationTodayStream {
    final todayStr = _todayDateString();
    return _db.ref('irrigation_log/history/$todayStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <Map<String, dynamic>>[];
      for (final v in map.values) {
        if (v is Map<String, dynamic>) list.add(v);
      }
      list.sort((a, b) =>
          (a['start_time'] as String).compareTo(b['start_time'] as String));
      return list;
    });
  }

  /// Returns true if [ts] (any ISO-8601 variant) falls on [dateStr] ("YYYY-MM-DD").
  bool _timestampMatchesDate(String ts, String dateStr) {
    if (ts.isEmpty) return false;
    // Timestamps may be "YYYY-MM-DDTHH:mm:ss" or "YYYY-MM-DD HH:mm:ss" or just the date
    return ts.startsWith(dateStr);
  }

  /// Returns today's date as "YYYY-MM-DD" string.
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Archives sensor and irrigation data for [dateStr] ("YYYY-MM-DD") to
  /// daily_log paths in Firebase. Safe to call multiple times.
  ///
  /// Both sensor and irrigation data now use the same nested structure:
  /// history/{dateStr}/{key}, so archiving just copies the subtree.
  Future<void> archiveDailyData(String dateStr) async {
    // --- Sensor archive (nested structure) ---
    final sensorSnap = await _db.ref('sensor_data/history/$dateStr').get();
    if (sensorSnap.value != null) {
      await _db.ref('sensor_data/daily_log/$dateStr').set(sensorSnap.value);
    }

    // --- Irrigation archive (now also nested by date) ---
    final irrigSnap = await _db.ref('irrigation_log/history/$dateStr').get();
    if (irrigSnap.value != null) {
      await _db.ref('irrigation_log/daily_log/$dateStr').set(irrigSnap.value);
    }
  }

  /// Stream of sensor data for a specific date — reads from
  /// sensor_data/history/{dateStr} (new nested structure).
  Stream<List<SensorData>> sensorDailyLogStream(String dateStr) {
    return _db.ref('sensor_data/history/$dateStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];
      final map = Map<String, dynamic>.from(raw as Map);
      return map.values
          .where((v) => v is Map)
          .map((v) => SensorData.fromMap(v as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  /// Stream of irrigation data for a specific date — reads from
  /// irrigation_log/history/{dateStr} (new nested structure).
  Stream<List<Map<String, dynamic>>> irrigationDailyLogStream(String dateStr) {
    return _db.ref('irrigation_log/history/$dateStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = map.values
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) =>
            (a['start_time'] as String).compareTo(b['start_time'] as String));
      return list;
    });
  }

  /// All irrigation log history records across all dates, sorted by start_time ascending.
  /// Structure: irrigation_log/history/{YYYY-MM-DD}/{key} → {duration, mode, start_time, ...}
  Stream<List<Map<String, dynamic>>> get irrigationHistoryStream {
    return _db.ref('irrigation_log/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <Map<String, dynamic>>[];
      for (final dateEntry in dateMap.values) {
        if (dateEntry is! Map) continue;
        final records = dateEntry is Map<String, dynamic>
            ? dateEntry
            : _deepConvert(dateEntry as Map<dynamic, dynamic>);
        for (final v in records.values) {
          if (v is Map<String, dynamic>) list.add(v);
        }
      }
      list.sort((a, b) =>
          (a['start_time'] as String).compareTo(b['start_time'] as String));
      return list;
    });
  }

  /// All ETc history records sorted by calculation_date ascending.
  Stream<List<Map<String, dynamic>>> get etcHistoryStream {
    return _db.ref('etc_calculation/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <Map<String, dynamic>>[];
      }
      final map = Map<String, dynamic>.from(raw as Map);
      final list =
          map.values.map((v) => Map<String, dynamic>.from(v as Map)).toList()
            ..sort(
              (a, b) => (a['calculation_date'] as String).compareTo(
                b['calculation_date'] as String,
              ),
            );
      return list;
    });
  }

  /// Set pump status to true (ON) or false (OFF).
  Future<void> setPumpStatus(bool isOn) async {
    await _db.ref('system_control/pump_status').set(isOn);
  }

  /// Set irrigation mode: "ETC_FUZZY" or "NON_ETC".
  Future<void> setIrrigationMode(String mode) async {
    await _db.ref('system_control/mode').set(mode);
  }

  /// Stream of plant configuration (phase, latitude, etc.).
  Stream<Map<String, dynamic>> get plantConfigStream {
    return _db.ref('plant_config/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(raw as Map);
    });
  }

  /// Save plant configuration data (phase, optional exact age, latitude).
  Future<void> savePlantConfig({
    required String phase,
    required String phaseRange,
    int? exactAge,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{
      'phase': phase,
      'phase_range': phaseRange,
      if (exactAge != null) 'exact_age_days': exactAge,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.ref('plant_config/latest').set(data);
  }

  /// List of scheduled times (e.g., ["08:00", "16:30"]) and its active status.
  Stream<Map<String, dynamic>> get irrigationScheduleStream {
    return _db.ref('system_control/schedule').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <String, dynamic>{'is_active': false, 'times': <String>[]};
      }
      final map = Map<String, dynamic>.from(raw as Map);
      final rawTimes = map['times'];
      List<String> times = [];
      if (rawTimes is List) {
        times = rawTimes.map((e) => e.toString()).toList();
      } else if (rawTimes is Map) {
        times = List<String>.from(rawTimes.values.map((e) => e.toString()));
      }
      
      times.sort(); // Sort times ascending
      
      return {
        'is_active': (map['is_active'] as bool?) ?? false,
        'times': times,
      };
    });
  }

  /// Save schedule configuration.
  Future<void> saveIrrigationSchedule(bool isActive, List<String> times) async {
    await _db.ref('system_control/schedule').set({
      'is_active': isActive,
      'times': times,
    });
  }
}
