import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';
import '../models/system_control.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Recursively converts a Firebase map (`Map<Object?, Object?>`) to
  /// `Map<String, dynamic>` so Dart type casts work on all platforms.
  /// Android Firebase SDK returns nested maps as `Map<Object?, Object?>`,
  /// while web returns them as `Map<String, dynamic>`. This normalises both.
  static Map<String, dynamic> _deepConvert(Map<dynamic, dynamic> raw) {
    return Map<String, dynamic>.fromEntries(
      raw.entries.map((e) {
        final key = e.key?.toString() ?? '';
        final val = e.value;
        if (val is Map) {
          return MapEntry(key, _deepConvert(val));
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
        .ref('etc/latest/etc_value')
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
        final records = _deepConvert(dateEntry);
        for (final v in records.values) {
          if (v is Map) {
            list.add(SensorData.fromMap(_deepConvert(v)));
          }
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Sensor history from sensor_data/history filtered to the last [pastDays]
  /// CLOSED calendar days (i.e. days before today — today is in daily_log).
  /// E.g. pastDays=2 → yesterday and day-before-yesterday.
  Stream<List<SensorData>> sensorHistoryRecentStream(int pastDays) {
    return _db.ref('sensor_data/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      // cutoff = start of (today - pastDays)
      final cutoff = todayStart.subtract(Duration(days: pastDays));

      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];

      for (final entry in dateMap.entries) {
        try {
          final entryDate = DateTime.parse(entry.key);
          // Only include past days within range (exclude today and older than cutoff)
          if (entryDate.isBefore(cutoff)) continue;
          if (!entryDate.isBefore(todayStart)) continue; // skip today
        } catch (_) {
          continue;
        }
        if (entry.value is! Map) continue;
        final records = _deepConvert(entry.value as Map<dynamic, dynamic>);
        for (final v in records.values) {
          if (v is Map) {
            list.add(SensorData.fromMap(_deepConvert(v)));
          }
        }
      }

      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }


  /// Sensor history for TODAY only — reads directly from
  /// sensor_data/daily_log/{YYYY-MM-DD} (entries stored directly under date node).
  Stream<List<SensorData>> get sensorTodayStream {
    final todayStr = _todayDateString();
    return _db.ref('sensor_data/daily_log/$todayStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];
      final map = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];
      for (final v in map.values) {
        if (v is Map) {
          list.add(SensorData.fromMap(_deepConvert(v)));
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Sensor data from sensor_data/daily_log for the last [days] calendar days.
  /// E.g. days=3 → today, yesterday, and the day before.
  /// All date nodes within the range are merged into a single sorted list.
  Stream<List<SensorData>> sensorDailyLogRecentStream(int days) {
    return _db.ref('sensor_data/daily_log').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      // Inclusive cutoff: start of (today - (days-1))
      final cutoff = todayStart.subtract(Duration(days: days - 1));

      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];

      for (final entry in dateMap.entries) {
        // entry.key must be "YYYY-MM-DD"
        try {
          final entryDate = DateTime.parse(entry.key);
          if (entryDate.isBefore(cutoff)) continue; // too old
        } catch (_) {
          continue;
        }
        if (entry.value is! Map) continue;
        final records = _deepConvert(entry.value as Map<dynamic, dynamic>);
        for (final v in records.values) {
          if (v is Map) {
            list.add(SensorData.fromMap(_deepConvert(v)));
          }
        }
      }

      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }


  Stream<List<Map<String, dynamic>>> get irrigationDailyLogTodayStream {
    final todayStr = _todayDateString();
    return _db.ref('irrigation_log/daily_log/$todayStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];

      Map<dynamic, dynamic> safeMap;
      if (raw is List) {
        safeMap = raw.asMap();
      } else if (raw is Map) {
        safeMap = raw;
      } else {
        return <Map<String, dynamic>>[];
      }

      final map = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      for (final v in map.values) {
        if (v is Map) list.add(Map<String, dynamic>.from(v));
      }
      list.sort((a, b) =>
          ((a['timestamp'] ?? '') as String)
              .compareTo((b['timestamp'] ?? '') as String));
      return list;
    });
  }

  /// Irrigation for TODAY — reads from irrigation_log/history/{YYYY-MM-DD}.
  Stream<List<Map<String, dynamic>>> get irrigationTodayStream {
    final todayStr = _todayDateString();
    return _db.ref('irrigation_log/history/$todayStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];

      Map<dynamic, dynamic> safeMap;
      if (raw is List) {
        safeMap = raw.asMap();
      } else if (raw is Map) {
        safeMap = raw;
      } else {
        return <Map<String, dynamic>>[];
      }

      final map = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      for (final v in map.values) {
        if (v is Map) list.add(Map<String, dynamic>.from(v));
      }
      list.sort((a, b) =>
          ((a['timestamp'] ?? '') as String)
              .compareTo((b['timestamp'] ?? '') as String));
      return list;
    });
  }

  /// Irrigation data untuk tanggal spesifik.
  /// - Jika [dateStr] == hari ini → baca dari irrigation_log/daily_log/{dateStr}
  /// - Selain itu             → baca dari irrigation_log/history/{dateStr}
  Stream<List<Map<String, dynamic>>> irrigationForDateStream(String dateStr) {
    final todayStr = _todayDateString();
    final path = dateStr == todayStr
        ? 'irrigation_log/daily_log/$dateStr'
        : 'irrigation_log/history/$dateStr';
    return _db.ref(path).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];

      Map<dynamic, dynamic> safeMap;
      if (raw is List) {
        safeMap = raw.asMap();
      } else if (raw is Map) {
        safeMap = raw;
      } else {
        return <Map<String, dynamic>>[];
      }

      final map = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      for (final v in map.values) {
        if (v is Map) list.add(Map<String, dynamic>.from(v));
      }
      list.sort((a, b) =>
          ((a['timestamp'] ?? '') as String)
              .compareTo((b['timestamp'] ?? '') as String));
      return list;
    });
  }

  /// Returns today's date as "YYYY-MM-DD" string.
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Moves old (not today) daily_log data to history for both sensor and irrigation logs.
  Future<void> moveOldDailyLogsToHistory() async {
    final todayStr = _todayDateString();

    Future<void> processNode(String basePath) async {
      final dailyLogRef = _db.ref('$basePath/daily_log');
      final historyRef = _db.ref('$basePath/history');

      final snap = await dailyLogRef.get();
      if (snap.value == null || snap.value is! Map) return;

      final dailyMap = _deepConvert(snap.value as Map<dynamic, dynamic>);

      for (final entry in dailyMap.entries) {
        final dateStr = entry.key;

        // Jangan pindahkan data hari ini.
        if (dateStr == todayStr) continue;

        // Pastikan key adalah format tanggal YYYY-MM-DD.
        if (!_isValidDateKey(dateStr)) continue;

        final data = entry.value;
        if (data is! Map) continue;

        try {
          final updateData = _deepConvert(data);

          // Salin dulu ke history.
          await historyRef.child(dateStr).update(updateData);

          // Hapus daily_log hanya setelah copy berhasil.
          await dailyLogRef.child(dateStr).remove();
        } catch (e) {
          // ignore: avoid_print
          print('[FirebaseService] Failed to move $basePath daily_log $dateStr: $e');
        }
      }
    }

    await processNode('sensor_data');
    await processNode('irrigation_log');
  }

  bool _isValidDateKey(String value) {
    try {
      final parsed = DateTime.parse(value);
      return value.length == 10 &&
          value[4] == '-' &&
          value[7] == '-' &&
          parsed.year > 2000;
    } catch (_) {
      return false;
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
          .whereType<Map<dynamic, dynamic>>()
          .map((v) => SensorData.fromMap(v))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  /// Irrigation data untuk tanggal spesifik — baca dari history/{dateStr}.
  Stream<List<Map<String, dynamic>>> irrigationDailyLogStream(String dateStr) {
    return _db.ref('irrigation_log/history/$dateStr').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <Map<String, dynamic>>[];
      for (final v in map.values) {
        if (v is Map) list.add(_deepConvert(v));
      }
      list.sort((a, b) =>
          ((a['timestamp'] ?? '') as String)
              .compareTo((b['timestamp'] ?? '') as String));
      return list;
    });
  }

  /// Semua riwayat irigasi dari semua tanggal, diurutkan berdasarkan 'timestamp'.
  /// Struktur: irrigation_log/history/{YYYY-MM-DD}/{key} → {duration, mode, timestamp, water_volume, ...}
  Stream<List<Map<String, dynamic>>> get irrigationHistoryStream {
    return _db.ref('irrigation_log/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      
      Map<dynamic, dynamic> safeMap;
      if (raw is List) {
        // Jika Firebase terpaksa mengubahnya jadi List
        safeMap = raw.asMap();
      } else if (raw is Map) {
        safeMap = raw;
      } else {
        return <Map<String, dynamic>>[];
      }

      final dateMap = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      
      for (final dateEntry in dateMap.values) {
        if (dateEntry is! Map) continue;
        
        // Iterasi melalui record irigasi di dalam tanggal tersebut (data_001, data_002, dst)
        for (final record in dateEntry.values) {
          if (record is Map) {
            // Konversi aman memastikan tipe datanya Map<String, dynamic>
            list.add(Map<String, dynamic>.from(record));
          }
        }
      }
      
      list.sort((a, b) =>
          ((a['timestamp'] ?? '') as String)
              .compareTo((b['timestamp'] ?? '') as String));
      return list;
    });
  }

  /// All ETc history records sorted by calculation_date ascending.
  Stream<List<Map<String, dynamic>>> get etcHistoryStream {
    return _db.ref('etc/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <Map<String, dynamic>>[];
      }
      
      Map<dynamic, dynamic> safeMap;
      if (raw is Map) {
        safeMap = raw;
      } else {
        return <Map<String, dynamic>>[];
      }

      final dateMap = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      
      for (final entry in dateMap.entries) {
        final dateStr = entry.key;
        if (entry.value is Map) {
          final record = Map<String, dynamic>.from(entry.value as Map);
          record['calculation_date'] ??= dateStr;
          list.add(record);
        }
      }
      
      list.sort((a, b) =>
          ((a['calculation_date'] ?? '') as String).compareTo(
              (b['calculation_date'] ?? '') as String));
              
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
    await _db.ref('plant_config/latest').update(data);
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
