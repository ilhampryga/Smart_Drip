import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/bmkg_service.dart';

/// Dual-line temperature chart for the dashboard.
/// Line 1: Today's ESP8266 sensor temperature (from Firebase).
/// Line 2: Open-Meteo hourly temperature forecast.
/// X-axis = hour of day (0–23).
class DualTempLineChart extends StatelessWidget {
  const DualTempLineChart({
    super.key,
    required this.sensorData,
    required this.weatherHourly,
    this.height = 200,
  });

  final List<SensorData> sensorData;
  final List<HourlyWeather> weatherHourly;
  final double height;

  double _hourFromTs(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return dt.hour + dt.minute / 60.0;
    } catch (_) {
      return 0;
    }
  }

  double _hourFromTimeStr(String timeStr) {
    // "07:00 WIB" → 7.0
    try {
      return double.parse(timeStr.split(':')[0]);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sensorSpots = sensorData
        .map((d) => FlSpot(_hourFromTs(d.timestamp), d.temperature))
        .toList();

    final weatherSpots = weatherHourly
        .map((h) =>
            FlSpot(_hourFromTimeStr(h.time), h.temperature.toDouble()))
        .toList();

    if (sensorSpots.isEmpty && weatherSpots.isEmpty) {
      return _empty(theme);
    }

    // Y range from both sources
    final allTemps = [
      ...sensorData.map((d) => d.temperature),
      ...weatherHourly.map((h) => h.temperature.toDouble()),
    ];
    double minY =
        (allTemps.isNotEmpty ? allTemps.reduce((a, b) => a < b ? a : b) : 15)
            .clamp(0, 15)
            .toDouble();
    double maxY =
        allTemps.isNotEmpty ? allTemps.reduce((a, b) => a > b ? a : b) + 5 : 40;
    if ((maxY - minY) < 10) maxY = minY + 10;

    const sensorColor = Color(0xFF6366F1); // indigo
    const weatherColor = Color(0xFFF97316); // orange

    final lines = <LineChartBarData>[];

    if (sensorSpots.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: sensorSpots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: sensorColor,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: sensorSpots.length <= 48,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 2.5,
            color: sensorColor,
            strokeColor: Colors.white,
            strokeWidth: 1.2,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              sensorColor.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ));
    }

    if (weatherSpots.isNotEmpty) {
      lines.add(LineChartBarData(
        spots: weatherSpots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: weatherColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dashArray: [7, 4],
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 3,
            color: weatherColor,
            strokeColor: Colors.white,
            strokeWidth: 1.2,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    final interval = (maxY - minY) / 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 23,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                verticalInterval: 3,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    FlLine(color: Colors.grey.shade100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: interval,
                    getTitlesWidget: (val, _) => Text(
                      val.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 3,
                    getTitlesWidget: (val, _) {
                      final h = val.toInt();
                      if (h % 3 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      cs.inverseSurface.withValues(alpha: 0.88),
                  getTooltipItems: (spots) => spots.map((s) {
                    final isWeather = s.barIndex == 1 ||
                        (sensorSpots.isEmpty && s.barIndex == 0);
                    final label = isWeather ? 'Open-Meteo' : 'Sensor';
                    // Reconstruct HH:MM from x (hour as float)
                    final h = s.x.toInt();
                    final m = ((s.x - s.x.floorToDouble()) * 60).round();
                    final timeStr = '${h.toString().padLeft(2, '0')}:'
                        '${m.toString().padLeft(2, '0')}';
                    return LineTooltipItem(
                      '$label  $timeStr\n${s.y.toStringAsFixed(1)} °C',
                      TextStyle(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: lines,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(ThemeData theme) => Card(
        child: SizedBox(
          height: height,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.show_chart, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Menunggu data suhu…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      );
}
