import 'package:flutter/material.dart';
import '../widgets/sensor_line_chart.dart';
import '../widgets/time_series_line_chart.dart';
import '../widgets/water_usage_line_chart.dart';
import '../widgets/date_picker_field.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart' show SensorData;

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  final _svc = FirebaseService.instance;

  // Key untuk force-rebuild DatePickerField saat reset
  Key _pickerKey = UniqueKey();

  // ── Cached streams — dibuat sekali dan tidak berubah ──────────────────────
  // Default view: sensor hari ini
  late final Stream<List<SensorData>> _sensorTodayStream;
  // Default view: semua riwayat irigasi
  late final Stream<List<Map<String, dynamic>>> _irrigationDefaultStream;
  // Filter view: semua riwayat sensor (history)
  late final Stream<List<SensorData>> _sensorHistoryStream;
  // Filter view: semua riwayat irigasi (history) — untuk filter client-side
  late final Stream<List<Map<String, dynamic>>> _irrigationHistoryStream;
  
  late final Stream<List<Map<String, dynamic>>> _etcHistoryStream;
  late final Stream<Map<String, dynamic>> _plantConfigStream;

  // Stream irigasi khusus filter tanggal tunggal (diperbarui saat filter berubah)
  Stream<List<Map<String, dynamic>>>? _irrigationFilteredStream;
  String? _irrigationFilteredDate; // tanggal yang sedang di-cache

  @override
  void initState() {
    super.initState();
    _sensorTodayStream     = _svc.sensorTodayStream.asBroadcastStream();
    _irrigationDefaultStream = _svc.irrigationHistoryStream.asBroadcastStream();
    _sensorHistoryStream   = _svc.sensorHistoryStream.asBroadcastStream();
    _irrigationHistoryStream = _svc.irrigationHistoryStream.asBroadcastStream();
    _etcHistoryStream = _svc.etcHistoryStream.asBroadcastStream();
    _plantConfigStream = _svc.plantConfigStream.asBroadcastStream();
  }

  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  // Kembalikan stream irigasi untuk filter tanggal tunggal.
  // Cache per-tanggal agar tidak membuat stream baru setiap rebuild.
  Stream<List<Map<String, dynamic>>> _getIrrigationSingleDayStream(String date) {
    if (_irrigationFilteredDate != date || _irrigationFilteredStream == null) {
      _irrigationFilteredDate = date;
      _irrigationFilteredStream = _svc.irrigationForDateStream(date).asBroadcastStream();
    }
    return _irrigationFilteredStream!;
  }

  List<SensorData> _filterSensor(List<SensorData> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((d) {
      if (d.timestamp.isEmpty) return true;
      try {
        final dt = DateTime.parse(d.timestamp);
        if (_startDate != null && dt.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null) {
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
          if (dt.isAfter(end)) {
            return false;
          }
        }
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _filterIrrigation(
      List<Map<String, dynamic>> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((d) {
      final t = (d['timestamp'] as String?) ?? '';
      if (t.isEmpty) return true;
      try {
        final dt = DateTime.parse(t);
        if (_startDate != null && dt.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null) {
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
          if (dt.isAfter(end)) {
            return false;
          }
        }
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<DailyWaterUsage> _calculateDailyWaterUsage(
      List<Map<String, dynamic>> irrigations,
      List<Map<String, dynamic>> etcHistory,
      Map<String, dynamic> plantConfig) {
    
    double parseDoubleSafely(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      return 0.0;
    }

    final fuzzyMap = <String, double>{};
    for (final irrig in irrigations) {
      final t = (irrig['timestamp'] as String?) ?? '';
      if (t.length >= 10) {
        final dateStr = t.substring(0, 10);
        final vol = parseDoubleSafely(irrig['water_volume']);
        fuzzyMap[dateStr] = (fuzzyMap[dateStr] ?? 0.0) + vol;
      }
    }

    final wetArea = parseDoubleSafely(plantConfig['wet_area']);

    final etcMap = <String, double>{};
    for (final etc in etcHistory) {
      final dateStr = etc['calculation_date'] as String?;
      if (dateStr != null) {
        etcMap[dateStr] = parseDoubleSafely(etc['etc_value']);
      }
    }

    final allDates = <String>{...fuzzyMap.keys, ...etcMap.keys};
    final result = <DailyWaterUsage>[];
    
    for (final dateStr in allDates) {
      try {
        final dt = DateTime.parse(dateStr);
        if (_startDate != null && dt.isBefore(_startDate!)) continue;
        if (_endDate != null) {
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
          if (dt.isAfter(end)) continue;
        }
        
        final fuzzyVol = fuzzyMap[dateStr] ?? 0.0;
        final etcVal = etcMap[dateStr] ?? 0.0;
        final pureEtcVol = etcVal * wetArea * 1000.0;
        
        result.add(DailyWaterUsage(
          date: dateStr,
          pureEtcVolume: pureEtcVol,
          fuzzyVolume: fuzzyVol,
        ));
      } catch (_) {}
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  bool get _isSingleDay =>
      _startDate != null &&
      _endDate != null &&
      _dateStr(_startDate!) == _dateStr(_endDate!);

  bool get _isMultiDay =>
      _startDate != null &&
      _endDate != null &&
      !_isSingleDay;

  bool get _isToday {
    final today = _dateStr(DateTime.now());
    if (_isSingleDay) return _dateStr(_startDate!) == today;
    return false;
  }


  void _resetFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      // Force rebuild DatePickerField agar field kosong kembali
      _pickerKey = UniqueKey();
      // Bersihkan cache stream filtered
      _irrigationFilteredStream = null;
      _irrigationFilteredDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool hasFilter = _startDate != null || _endDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Log')),
      body: SafeArea(
        child: hasFilter
            ? _buildWithFilter(context, theme, cs)
            : _buildTodayDefault(context, theme, cs),
      ),
    );
  }

  /// Tampilan default: sensor hari ini + semua riwayat irigasi
  Widget _buildTodayDefault(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    return StreamBuilder<List<SensorData>>(
      key: const ValueKey('default_view'),
      stream: _sensorTodayStream,
      builder: (context, sensorSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _irrigationDefaultStream,
          builder: (context, irrigSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _etcHistoryStream,
              builder: (context, etcSnap) {
                return StreamBuilder<Map<String, dynamic>>(
                  stream: _plantConfigStream,
                  builder: (context, configSnap) {
                    final sensors = sensorSnap.data ?? [];
                    final irrigation = irrigSnap.data ?? [];
                    final etcHistory = etcSnap.data ?? [];
                    final plantConfig = configSnap.data ?? {};

                    final waterUsages = _calculateDailyWaterUsage(irrigation, etcHistory, plantConfig);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDatePickers(context, theme, cs),
                          const SizedBox(height: 8),
                          _InfoChip(
                            icon: Icons.today_outlined,
                            text: 'Sensor: data hari ini · Irigasi: semua riwayat',
                            color: cs.primaryContainer,
                            textColor: cs.onPrimaryContainer,
                          ),
                          const SizedBox(height: 16),
                            _buildCharts(
                              context, theme, cs,
                              sensors: sensors,
                              waterUsages: waterUsages,
                              irrigation: irrigation,
                              use24h: true,
                              useMultiDay: false,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Tampilan dengan filter tanggal aktif
  Widget _buildWithFilter(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    // Pilih stream irigasi yang sesuai — STABIL (tidak buat stream baru setiap rebuild)
    final Stream<List<Map<String, dynamic>>> irrigStream;
    if (_isSingleDay) {
      irrigStream = _getIrrigationSingleDayStream(_dateStr(_startDate!));
    } else {
      // Multi-day atau hanya satu tanggal: pakai history + filter client-side
      irrigStream = _irrigationHistoryStream;
    }

    return StreamBuilder<List<SensorData>>(
      key: const ValueKey('filter_view'),
      stream: _sensorHistoryStream,
      builder: (context, sensorSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: irrigStream,
          builder: (context, irrigSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _etcHistoryStream,
              builder: (context, etcSnap) {
                return StreamBuilder<Map<String, dynamic>>(
                  stream: _plantConfigStream,
                  builder: (context, configSnap) {
                    final allSensors = sensorSnap.data ?? [];
                    final allIrrigation = irrigSnap.data ?? [];
                    final etcHistory = etcSnap.data ?? [];
                    final plantConfig = configSnap.data ?? {};

                    final sensors = _filterSensor(allSensors);
                    final irrigation = _filterIrrigation(allIrrigation);
                    final waterUsages = _calculateDailyWaterUsage(irrigation, etcHistory, plantConfig);

                    final use24h = _isSingleDay;
                    final useMultiDay = _isMultiDay;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDatePickers(context, theme, cs),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _resetFilter,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Reset Filter'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.error,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              if (sensors.isNotEmpty || waterUsages.isNotEmpty)
                                Text(
                                  '${sensors.length} data sensor  •  '
                                  '${waterUsages.length} riwayat irigasi',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (use24h) ...[
                            _InfoChip(
                              icon: Icons.info_outline,
                              text: _isToday
                                  ? 'Menampilkan data hari ini (mode 24 jam)'
                                  : 'Menampilkan data 24 jam pada '
                                      '${_dateStr(_startDate!)}',
                              color: cs.primaryContainer,
                              textColor: cs.onPrimaryContainer,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (useMultiDay) ...[
                            _InfoChip(
                              icon: Icons.multiline_chart,
                              text: 'Menampilkan data rentang waktu secara berkelanjutan — '
                                  'garis putus = ambang batas wajar',
                              color: cs.secondaryContainer,
                              textColor: cs.onSecondaryContainer,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildCharts(
                            context, theme, cs,
                            sensors: sensors,
                            waterUsages: waterUsages,
                            irrigation: irrigation,
                            use24h: use24h,
                            useMultiDay: useMultiDay,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Row date pickers — pakai _pickerKey agar bisa force reset
  Widget _buildDatePickers(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    return Row(
      key: _pickerKey,
      children: [
        DatePickerField(
          label: 'Tanggal Mulai',
          initialDate: _startDate,
          lastDate: _endDate ?? DateTime.now(),
          onDateChanged: (d) => setState(() => _startDate = d),
        ),
        const SizedBox(width: 10),
        DatePickerField(
          label: 'Tanggal Selesai',
          initialDate: _endDate,
          firstDate: _startDate,
          lastDate: DateTime.now(),
          onDateChanged: (d) => setState(() => _endDate = d),
        ),
      ],
    );
  }

  Widget _buildCharts(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs, {
    required List<SensorData> sensors,
    required List<DailyWaterUsage> waterUsages,
    required List<Map<String, dynamic>> irrigation,
    required bool use24h,
    required bool useMultiDay,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chartTitle(context, 'Grafik Penggunaan Air', [
          _dot(Colors.orange.shade700, 'ETc Murni (ml)', theme),
          const SizedBox(width: 8),
          _dot(cs.primary, 'ETc+Fuzzy (ml)', theme),
        ]),
        const SizedBox(height: 6),
        WaterUsageLineChart(data: waterUsages, height: 180),
        const SizedBox(height: 16),

        _chartTitle(
          context,
          'Grafik Suhu',
          useMultiDay ? [] : [_dot(cs.primary, 'Suhu (°C)', theme)],
        ),
        const SizedBox(height: 6),
        if (useMultiDay)
          TimeSeriesLineChart(data: sensors, height: 200, showTemperature: true)
        else
          SensorLineChart(
            data: sensors,
            height: 160,
            showBothLines: false,
            showTemperature: true,
            is24HourMode: use24h,
          ),
        const SizedBox(height: 16),

        _chartTitle(
          context,
          'Grafik Kelembapan Tanah',
          useMultiDay
              ? []
              : [
                  const _LegendDot(
                      color: Colors.blueAccent, label: 'Kelembapan (%)'),
                ],
        ),
        const SizedBox(height: 6),
        if (useMultiDay)
          TimeSeriesLineChart(
            data: sensors,
            height: 200,
            showTemperature: false,
            irrigationData: irrigation,
          )
        else
          SensorLineChart(
            data: sensors,
            height: 160,
            showBothLines: false,
            showTemperature: false,
            is24HourMode: use24h,
            irrigationData: irrigation,
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _chartTitle(
      BuildContext context, String title, List<Widget> legend) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...legend,
      ],
    );
  }

  Widget _dot(Color color, String label, ThemeData theme) =>
      _LegendDot(color: color, label: label);
}

// ──────────────────────────────────────────────────────────────────────────────
// Local widgets
// ──────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
