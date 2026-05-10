import 'package:flutter/material.dart';
import '../widgets/sensor_line_chart.dart';
import '../widgets/water_usage_bar_chart.dart';
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

  /// Returns "YYYY-MM-DD" string from a DateTime.
  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Filter sensor history by selected date range.
  List<SensorData> _filterSensor(List<SensorData> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((d) {
      if (d.timestamp.isEmpty) return true;
      try {
        final dt = DateTime.parse(d.timestamp);
        if (_startDate != null && dt.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            dt.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  /// Filter irrigation history by selected date range.
  List<Map<String, dynamic>> _filterIrrigation(
      List<Map<String, dynamic>> all) {
    if (_startDate == null && _endDate == null) return all;
    return all.where((d) {
      final t = (d['start_time'] as String?) ?? '';
      if (t.isEmpty) return true;
      try {
        final dt = DateTime.parse(t);
        if (_startDate != null && dt.isBefore(_startDate!)) return false;
        if (_endDate != null &&
            dt.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  /// Whether the current filter covers exactly one day.
  bool get _isSingleDay =>
      _startDate != null &&
      _endDate != null &&
      _dateStr(_startDate!) == _dateStr(_endDate!);

  /// Whether the current filter covers today only.
  bool get _isToday {
    final today = _dateStr(DateTime.now());
    if (_startDate == null && _endDate == null) return false;
    if (_isSingleDay) return _dateStr(_startDate!) == today;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log')),
      body: SafeArea(
        child: StreamBuilder<List<SensorData>>(
          stream: _svc.sensorHistoryStream,
          builder: (context, sensorSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _svc.irrigationHistoryStream,
              builder: (context, irrigSnap) {
                final allSensors = sensorSnap.data ?? [];
                final allIrrigation = irrigSnap.data ?? [];

                final sensors = _filterSensor(allSensors);
                final irrigation = _filterIrrigation(allIrrigation);

                // Determine if we should use 24h mode for charts
                // (only when viewing a single specific day)
                final use24h = _isSingleDay;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Date range pickers ──
                      Row(
                        children: [
                          DatePickerField(
                            label: 'Tanggal Mulai',
                            initialDate: _startDate,
                            lastDate: _endDate ?? DateTime.now(),
                            onDateChanged: (date) {
                              setState(() => _startDate = date);
                            },
                          ),
                          const SizedBox(width: 10),
                          DatePickerField(
                            label: 'Tanggal Selesai',
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime.now(),
                            onDateChanged: (date) {
                              setState(() => _endDate = date);
                            },
                          ),
                        ],
                      ),

                      // ── Reset filter button ──
                      if (_startDate != null || _endDate != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _startDate = null;
                                _endDate = null;
                              }),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Reset Filter'),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.error,
                                textStyle:
                                    const TextStyle(fontSize: 12),
                              ),
                            ),
                            const Spacer(),
                            if (sensors.isNotEmpty || irrigation.isNotEmpty)
                              Text(
                                '${sensors.length} data sensor  •  '
                                '${irrigation.length} irigasi',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ── Info chip if viewing single day ──
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

                      // ── Water usage bar chart ──
                      _chartTitle(context, 'Grafik Penggunaan Air', [
                        _dot(cs.primary, 'Volume (ml)', theme),
                      ]),
                      const SizedBox(height: 6),
                      WaterUsageBarChart(data: irrigation, height: 160),
                      const SizedBox(height: 16),

                      // ── Temperature line chart ──
                      _chartTitle(context, 'Grafik Suhu', [
                        _dot(cs.primary, 'Suhu (°C)', theme),
                      ]),
                      const SizedBox(height: 6),
                      SensorLineChart(
                        data: sensors,
                        height: 160,
                        showBothLines: false,
                        showTemperature: true,
                        is24HourMode: use24h,
                      ),
                      const SizedBox(height: 16),

                      // ── Soil moisture line chart ──
                      _chartTitle(context, 'Grafik Kelembapan Tanah', [
                        const _LegendDot(
                          color: Colors.blueAccent,
                          label: 'Kelembapan (%)',
                        ),
                      ]),
                      const SizedBox(height: 6),
                      SensorLineChart(
                        data: sensors,
                        height: 160,
                        showBothLines: false,
                        showTemperature: false,
                        is24HourMode: use24h,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
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

// ──────────────────────────────────────────────
// Widgets
// ──────────────────────────────────────────────

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
