import 'package:flutter/material.dart';
import '../widgets/sensor_card.dart';
import '../widgets/pump_card.dart';
import '../widgets/sensor_line_chart.dart';
import '../widgets/water_usage_bar_chart.dart';
import '../widgets/weather_card.dart';
import '../services/firebase_service.dart';
import '../services/daily_archive_service.dart';
import '../models/sensor_data.dart' show SensorData;
import '../models/system_control.dart' show SystemControl;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _svc = FirebaseService.instance;

  // Cached streams — must be stable object references for StreamBuilder.
  // Creating them inside build() causes re-subscription on every parent rebuild.
  late final Stream<List<SensorData>> _sensorTodayStream;
  late final Stream<List<Map<String, dynamic>>> _irrigationTodayStream;

  @override
  void initState() {
    super.initState();
    _sensorTodayStream = _svc.sensorTodayStream;
    _irrigationTodayStream = _svc.irrigationTodayStream;
    // Trigger daily archive check on dashboard open
    DailyArchiveService.instance.checkAndArchive();
  }

  /// Returns formatted date string: e.g. "Sabtu, 2 Mei 2026"
  String _formattedToday() {
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<SensorData>(
            stream: _svc.sensorDataStream,
            builder: (context, sensorSnap) {
              return StreamBuilder<double>(
                stream: _svc.etcStream,
                builder: (context, etcSnap) {
                  return StreamBuilder<SystemControl>(
                    stream: _svc.systemControlStream,
                    builder: (context, ctrlSnap) {
                      final sensor = sensorSnap.data;
                      final etc = etcSnap.data ?? 0.0;
                      final ctrl = ctrlSnap.data;

                      final tempStr = sensor != null
                          ? sensor.temperature.toStringAsFixed(1)
                          : '--';
                      final moistStr = sensor != null
                          ? sensor.soilMoisture.toStringAsFixed(1)
                          : '--';
                      final etcStr =
                          etc > 0 ? etc.toStringAsFixed(1) : '--';

                      return Column(
                        children: [
                          // ── sensor / pump cards ──
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.1,
                            children: [
                              SensorCard(
                                label: 'Suhu',
                                value: tempStr,
                                unit: '°C',
                                icon: Icons.thermostat_outlined,
                              ),
                              SensorCard(
                                label: 'Kelembapan Tanah',
                                value: moistStr,
                                unit: '%',
                                icon: Icons.water_outlined,
                              ),
                              PumpCard(
                                initialValue: ctrl?.isPumpOn ?? false,
                                statusStream: _svc.systemControlStream.map(
                                  (c) => c.isPumpOn,
                                ),
                              ),
                              SensorCard(
                                label: 'ETc Hari Ini',
                                value: etcStr,
                                unit: 'mm/day',
                                icon: Icons.eco_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Weather card (BMKG) ──
                          StreamBuilder<Map<String, dynamic>>(
                            stream: _svc.plantConfigStream,
                            builder: (ctx, plantSnap) {
                              final lat =
                                  (plantSnap.data?['latitude'] as num?)
                                      ?.toDouble();
                              final lon =
                                  (plantSnap.data?['longitude'] as num?)
                                      ?.toDouble();
                              return WeatherCard(
                                latitude: lat,
                                longitude: lon,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // ── Date badge ──
                          _DateBadge(label: _formattedToday()),
                          const SizedBox(height: 10),

                          // ── Sensor history chart — today only ──
                          _ChartCard(
                            title: 'Grafik Suhu & Kelembapan Tanah',
                            subtitle: 'Data hari ini (00:00–23:59)',
                            legend: [
                              _LegendItem(
                                color: cs.primary,
                                label: 'Suhu (°C)',
                              ),
                              const _LegendItem(
                                color: Colors.blueAccent,
                                label: 'Kelembapan (%)',
                              ),
                            ],
                            child: StreamBuilder<List<SensorData>>(
                              stream: _sensorTodayStream,
                              builder: (ctx, snap) => SensorLineChart(
                                data: snap.data ?? [],
                                height: 180,
                                showBothLines: true,
                                is24HourMode: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Water usage chart — today only ──
                          _ChartCard(
                            title: 'Grafik Penggunaan Air',
                            subtitle: 'Irigasi hari ini',
                            legend: [
                              _LegendItem(
                                color: cs.primary,
                                label: 'Volume (ml)',
                              ),
                            ],
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _irrigationTodayStream,
                              builder: (ctx, snap) => WaterUsageBarChart(
                                data: snap.data ?? [],
                                height: 180,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Date badge widget
// ──────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Reusable chart card wrapper with title + legend
// ──────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.legend = const [],
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<_LegendItem> legend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ...legend,
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
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
      ),
    );
  }
}
