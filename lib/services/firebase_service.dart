import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';
import '../models/system_control.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

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
          pumpStatus: 'OFF',
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


  /// All sensor history records sorted by timestamp ascending.
  Stream<List<SensorData>> get sensorHistoryStream {
    return _db.ref('sensor_data/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <SensorData>[];
      }
      final map = Map<String, dynamic>.from(raw as Map);
      final list =
          map.values
              .map((v) => SensorData.fromMap(v as Map<dynamic, dynamic>))
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// All irrigation log history records sorted by start_time ascending.
  Stream<List<Map<String, dynamic>>> get irrigationHistoryStream {
    return _db.ref('irrigation_log/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <Map<String, dynamic>>[];
      }
      final map = Map<String, dynamic>.from(raw as Map);
      final list =
          map.values.map((v) => Map<String, dynamic>.from(v as Map)).toList()
            ..sort(
              (a, b) => (a['start_time'] as String).compareTo(
                b['start_time'] as String,
              ),
            );
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

  /// Set pump status to ON or OFF.
  Future<void> setPumpStatus(bool isOn) async {
    await _db.ref('system_control/pump_status').set(isOn ? 'ON' : 'OFF');
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
