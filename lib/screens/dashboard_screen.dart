import 'package:flutter/material.dart';
import '../widgets/sensor_card.dart';
import '../widgets/pump_card.dart';
import '../widgets/dual_temp_line_chart.dart';
import '../widgets/multi_day_line_chart.dart';
import '../widgets/water_usage_bar_chart.dart';
import '../widgets/weather_card.dart';
import '../services/firebase_service.dart';
import '../services/daily_archive_service.dart';
import '../services/bmkg_service.dart';
import '../models/sensor_data.dart' show SensorData;
import '../models/system_control.dart' show SystemControl;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _svc = FirebaseService.instance;

  late final Stream<List<SensorData>> _sensorTodayStream;
  late final Stream<List<SensorData>> _sensorHistoryRecentStream;
  late final Stream<List<Map<String, dynamic>>> _irrigationTodayStream;

  // Weather future — managed at state level to avoid FutureBuilder race conditions.
  Future<WeatherData?> _weatherFuture = Future.value(null);
  double? _lat;
  double? _lon;
  late final _plantSub = _svc.plantConfigStream.listen((config) {
    final lat = (config['latitude'] as num?)?.toDouble();
    final lon = (config['longitude'] as num?)?.toDouble();
    // Only re-fetch when valid coordinates first arrive or change.
    if (lat != null && lon != null && (lat != _lat || lon != _lon)) {
      _lat = lat;
      _lon = lon;
      setState(() {
        _weatherFuture = BmkgService.instance.fetchWeather(lat, lon);
      });
    }
  });

  @override
  void initState() {
    super.initState();
    _sensorTodayStream = _svc.sensorTodayStream;
    _sensorHistoryRecentStream = _svc.sensorHistoryRecentStream(2);
    _irrigationTodayStream = _svc.irrigationTodayStream;
    DailyArchiveService.instance.checkAndArchive();
    BmkgService.instance.clearCache();
    _plantSub; // trigger lazy init
  }

  @override
  void dispose() {
    _plantSub.cancel();
    super.dispose();
  }

  String _formattedToday() {
    final now = DateTime.now();
    const days = [
      'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu',
    ];
    const months = [
      'Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
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
                          // ── Sensor / pump cards ──────────────────────────
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
                                statusStream: _svc.systemControlStream
                                    .map((c) => c.isPumpOn),
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

                          // ── Weather card (Open-Meteo) ────────────────────
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

                          // ── Date badge ───────────────────────────────────
                          _DateBadge(label: _formattedToday()),
                          const SizedBox(height: 10),

                          // ── Temperature chart: sensor + Open-Meteo ───────
                          _ChartCard(
                            title: 'Grafik Suhu Hari Ini',
                            subtitle: 'Sensor ESP8266 vs prakiraan Open-Meteo',
                            legend: [
                              _LegendItem(
                                color: const Color(0xFF6366F1),
                                label: 'Sensor (°C)',
                                dashed: false,
                              ),
                              _LegendItem(
                                color: const Color(0xFFF97316),
                                label: 'Open-Meteo (°C)',
                                dashed: true,
                              ),
                            ],
                            child: FutureBuilder<WeatherData?>(
                              future: _weatherFuture,
                              builder: (ctx, weatherSnap) {
                                final hourly =
                                    weatherSnap.data?.hourly ?? [];
                                return StreamBuilder<List<SensorData>>(
                                  stream: _sensorTodayStream,
                                  builder: (ctx, snap) => DualTempLineChart(
                                    sensorData: snap.data ?? [],
                                    weatherHourly: hourly,
                                    height: 200,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Soil moisture: hari ini (daily_log) + 2 hari lalu (history) ──
                          _ChartCard(
                            title: 'Grafik Kelembapan Tanah',
                            subtitle: '3 hari terakhir + ambang batas wajar 60–80%',
                            legend: const [],
                            child: StreamBuilder<List<SensorData>>(
                              stream: _sensorTodayStream,
                              builder: (ctx, todaySnap) {
                                final todayData = todaySnap.data ?? [];
                                return StreamBuilder<List<SensorData>>(
                                  stream: _sensorHistoryRecentStream,
                                  builder: (ctx, histSnap) {
                                    final histData = histSnap.data ?? [];
                                    // Merge: closed days (history) + today (daily_log)
                                    final combined = [...histData, ...todayData];
                                    combined.sort((a, b) =>
                                        a.timestamp.compareTo(b.timestamp));
                                    return MultiDayLineChart(
                                      data: combined,
                                      height: 200,
                                      showTemperature: false,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Water usage chart — today only ───────────────
                          _ChartCard(
                            title: 'Grafik Penggunaan Air',
                            subtitle: 'Irigasi hari ini',
                            legend: [
                              _LegendItem(
                                color: cs.primary,
                                label: 'Volume (ml)',
                                dashed: false,
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

// ─────────────────────────────────────────────────────────────────────────────
// Date badge
// ─────────────────────────────────────────────────────────────────────────────

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
          Icon(Icons.calendar_today_outlined, size: 14, color: cs.primary),
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

// ─────────────────────────────────────────────────────────────────────────────
// Chart card wrapper
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Legend item (supports dashed line indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Line indicator — solid or dashed
          SizedBox(
            width: 18,
            height: 12,
            child: CustomPaint(painter: _LinePainter(color: color, dashed: dashed)),
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

class _LinePainter extends CustomPainter {
  _LinePainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      const dash = 4.0, gap = 3.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset((x + dash).clamp(0, size.width), size.height / 2),
          paint,
        );
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
