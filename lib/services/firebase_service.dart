import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';
import '../models/system_control.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Konversi Map Firebase agar aman.
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

  // Data sensor terbaru.
  Stream<SensorData> get sensorDataStream {
    return _db.ref('sensor_data/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return const SensorData(temperature: 0, soilMoisture: 0, timestamp: '');
      }
      return SensorData.fromMap(raw as Map<dynamic, dynamic>);
    });
  }

  // Nilai ETc terbaru.
  Stream<double> get etcStream {
    return _db
        .ref('etc/latest/etc_value')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toDouble() ?? 0.0);
  }

  // Status kontrol sistem.
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

  // Log irigasi terbaru.
  Stream<Map<String, dynamic>> get irrigationLogStream {
    return _db.ref('irrigation_log/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(raw as Map);
    });
  }

  // Riwayat sensor semua tanggal.
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

  // Riwayat sensor beberapa hari terakhir.
  Stream<List<SensorData>> sensorHistoryRecentStream(int pastDays) {
    return _db.ref('sensor_data/history').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final cutoff = todayStart.subtract(Duration(days: pastDays));

      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];

      for (final entry in dateMap.entries) {
        try {
          final entryDate = DateTime.parse(entry.key);
          if (entryDate.isBefore(cutoff)) continue;
          if (!entryDate.isBefore(todayStart)) continue;
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

  // Data sensor hari ini.
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

  // Data sensor harian terbaru.
  Stream<List<SensorData>> sensorDailyLogRecentStream(int days) {
    return _db.ref('sensor_data/daily_log').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <SensorData>[];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final cutoff = todayStart.subtract(Duration(days: days - 1));

      final dateMap = _deepConvert(raw as Map<dynamic, dynamic>);
      final list = <SensorData>[];

      for (final entry in dateMap.entries) {
        try {
          final entryDate = DateTime.parse(entry.key);
          if (entryDate.isBefore(cutoff)) continue;
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

  // Log irigasi hari ini.
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

  // Riwayat irigasi hari ini.
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

  // Data irigasi tanggal tertentu.
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

  // Format tanggal hari ini (YYYY-MM-DD).
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // Pindahkan log lama ke riwayat.
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

        if (dateStr == todayStr) continue;

        if (!_isValidDateKey(dateStr)) continue;

        final data = entry.value;
        if (data is! Map) continue;

        try {
          final updateData = _deepConvert(data);

          await historyRef.child(dateStr).update(updateData);
          await dailyLogRef.child(dateStr).remove();
        } catch (e) {
          // Abaikan error
        }
      }
    }

    await processNode('sensor_data');
    await processNode('irrigation_log');
  }

  // Cek validitas format tanggal.
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

  // Data sensor harian untuk tanggal tertentu.
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

  // Data irigasi harian untuk tanggal tertentu.
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

  // Riwayat irigasi semua tanggal.
  Stream<List<Map<String, dynamic>>> get irrigationHistoryStream {
    return _db.ref('irrigation_log/history').onValue.map((event) {
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

      final dateMap = _deepConvert(safeMap);
      final list = <Map<String, dynamic>>[];
      
      for (final dateEntry in dateMap.values) {
        if (dateEntry is! Map) continue;
        
        for (final record in dateEntry.values) {
          if (record is Map) {
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

  // Riwayat nilai ETc.
  Stream<List<Map<String, dynamic>>> get etcHistoryStream {
    final etcRef = _db.ref('etc/history').onValue;
    final etcCalcRef = _db.ref('etc_calculation/history').onValue;

    return etcRef.asyncMap((etcEvent) async {
      final list = <Map<String, dynamic>>[];

      void processRaw(dynamic raw) {
        if (raw == null) return;
        final safeMap = raw is Map ? raw : <dynamic, dynamic>{};
        final dateMap = _deepConvert(safeMap);
        for (final entry in dateMap.entries) {
          final dateStr = entry.key;
          if (entry.value is Map) {
            final record = Map<String, dynamic>.from(entry.value as Map);
            record['calculation_date'] ??= dateStr;
            list.add(record);
          } else if (entry.value is num) {
            list.add({
              'calculation_date': dateStr,
              'etc_value': (entry.value as num).toDouble(),
            });
          }
        }
      }

      processRaw(etcEvent.snapshot.value);
      
      try {
        final calcEvent = await _db.ref('etc_calculation/history').once();
        processRaw(calcEvent.snapshot.value);
      } catch (_) {}

      final deduplicated = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final date = item['calculation_date'] as String? ?? '';
        if (date.isNotEmpty) deduplicated[date] = item;
      }

      final finalList = deduplicated.values.toList();
      finalList.sort((a, b) =>
          ((a['calculation_date'] ?? '') as String).compareTo(
              (b['calculation_date'] ?? '') as String));
              
      return finalList;
    });
  }

  // Ubah status pompa.
  Future<void> setPumpStatus(bool isOn) async {
    await _db.ref('system_control/pump_status').set(isOn);
  }

  // Ubah mode irigasi.
  Future<void> setIrrigationMode(String mode) async {
    await _db.ref('system_control/mode').set(mode);
  }

  // Pengaturan tanaman terbaru.
  Stream<Map<String, dynamic>> get plantConfigStream {
    return _db.ref('plant_config/latest').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(raw as Map);
    });
  }

  // Simpan pengaturan tanaman.
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

  // Jadwal irigasi.
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
      
      times.sort();
      
      return {
        'is_active': (map['is_active'] as bool?) ?? false,
        'times': times,
      };
    });
  }

  // Simpan jadwal irigasi.
  Future<void> saveIrrigationSchedule(bool isActive, List<String> times) async {
    await _db.ref('system_control/schedule').set({
      'is_active': isActive,
      'times': times,
    });
  }
}
