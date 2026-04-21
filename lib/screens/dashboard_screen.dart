import 'package:flutter/material.dart';
import '../widgets/sensor_card.dart';
import '../widgets/pump_card.dart';
import '../widgets/sensor_line_chart.dart';
import '../widgets/water_usage_bar_chart.dart';
import '../widgets/weather_card.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart' show SensorData;
import '../models/system_control.dart' show SystemControl;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _svc = FirebaseService.instance;

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
                      final etcStr = etc > 0 ? etc.toStringAsFixed(1) : '--';

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
                              final lat = (plantSnap.data?['latitude'] as num?)
                                  ?.toDouble();
                              final lon = (plantSnap.data?['longitude'] as num?)
                                  ?.toDouble();
                              return WeatherCard(
                                latitude: lat,
                                longitude: lon,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // ── Sensor history chart ──
                          _ChartCard(
                            title: 'Grafik Suhu & Kelembapan Tanah',
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
                              stream: _svc.sensorHistoryStream,
                              builder: (ctx, snap) => SensorLineChart(
                                data: snap.data ?? [],
                                height: 160,
                                showBothLines: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Water usage chart ──
                          _ChartCard(
                            title: 'Grafik Penggunaan Air',
                            legend: [
                              _LegendItem(
                                color: cs.primary,
                                label: 'Volume (ml)',
                              ),
                            ],
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _svc.irrigationHistoryStream,
                              builder: (ctx, snap) => WaterUsageBarChart(
                                data: snap.data ?? [],
                                height: 160,
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
// Reusable chart card wrapper with title + legend
// ──────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.legend = const [],
  });

  final String title;
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

