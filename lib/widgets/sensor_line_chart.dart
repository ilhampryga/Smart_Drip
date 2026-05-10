import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Beautiful dual-line chart for temperature (primary) and soil moisture
/// (secondary). Supports a clean 24-hour mode where the X-axis represents
/// 0–23 hours regardless of how many data points exist.
class SensorLineChart extends StatefulWidget {
  const SensorLineChart({
    super.key,
    required this.data,
    this.height = 180,
    this.showBothLines = true,
    this.showTemperature = true,
    /// When true, X-axis is fixed to 0–23 (hour of day) for today's chart.
    this.is24HourMode = false,
  });

  /// Ordered sensor history list (oldest → newest).
  final List<SensorData> data;
  final double height;

  /// When true, renders both temperature & soil-moisture lines.
  final bool showBothLines;

  /// When [showBothLines] is false, controls which single line to show.
  final bool showTemperature;

  /// When true, X-axis is fixed 0–23 (hours). Labels shown every 3 h.
  final bool is24HourMode;

  @override
  State<SensorLineChart> createState() => _SensorLineChartState();
}

class _SensorLineChartState extends State<SensorLineChart> {
  int _touchedIndex = -1;

  /// Parse hour (0–23) from an ISO-8601 or "YYYY-MM-DD HH:mm:ss" timestamp.
  double _hourFromTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return dt.hour + dt.minute / 60.0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
      return _buildEmpty(context, theme);
    }

    final tempSpots = <FlSpot>[];
    final moistSpots = <FlSpot>[];

    // Compute X range from actual data when in 24h mode
    double dataMinX = 0;
    double dataMaxX = 23;

    for (int i = 0; i < widget.data.length; i++) {
      final d = widget.data[i];
      final x = widget.is24HourMode
          ? _hourFromTimestamp(d.timestamp)
          : i.toDouble();
      tempSpots.add(FlSpot(x, d.temperature));
      moistSpots.add(FlSpot(x, d.soilMoisture));
    }

    if (widget.is24HourMode && tempSpots.isNotEmpty) {
      dataMinX = tempSpots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      dataMaxX = tempSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      // Add 0.5h padding on each side so first/last point isn't at the edge
      dataMinX = (dataMinX - 0.5).clamp(0.0, 23.0);
      dataMaxX = (dataMaxX + 0.5).clamp(0.0, 24.0);
      // Ensure minimum visible range of 2h
      if ((dataMaxX - dataMinX) < 2) dataMaxX = dataMinX + 2;
    }

    double minY = 0;
    double maxY = 100;
    if (widget.showTemperature || widget.showBothLines) {
      final temps = widget.data.map((d) => d.temperature);
      final minT = temps.reduce((a, b) => a < b ? a : b);
      final maxT = temps.reduce((a, b) => a > b ? a : b);
      minY = (minT - 5).clamp(0, 200).toDouble();
      maxY = (maxT + 5).toDouble();
    }
    if (widget.showBothLines || !widget.showTemperature) {
      final moists = widget.data.map((d) => d.soilMoisture);
      final minM = moists.reduce((a, b) => a < b ? a : b);
      final maxM = moists.reduce((a, b) => a > b ? a : b);
      if (widget.showBothLines) {
        minY = (minM - 5).clamp(0.0, minY).toDouble();
        maxY = maxM + 5 > maxY ? maxM + 5 : maxY;
      } else {
        minY = (minM - 5).clamp(0, 200).toDouble();
        maxY = (maxM + 5).toDouble();
      }
    }

    // Ensure a minimum range so the chart doesn't look flat
    if ((maxY - minY) < 5) {
      maxY = minY + 5;
    }

    final bool showDots = widget.data.length <= 30;

    final lines = <LineChartBarData>[];

    if (widget.showBothLines || widget.showTemperature) {
      lines.add(
        _buildLine(
          spots: tempSpots,
          color: cs.primary,
          isCurved: true,
          showDots: showDots,
          gradient: LinearGradient(
            colors: [cs.primary.withValues(alpha: 0.18), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }

    if (widget.showBothLines || !widget.showTemperature) {
      lines.add(
        _buildLine(
          spots: moistSpots,
          color: Colors.blueAccent,
          isCurved: true,
          showDots: showDots,
          gradient: LinearGradient(
            colors: [
              Colors.blueAccent.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }

    // Build bottom titles configuration
    final SideTitles bottomSideTitles;
    if (widget.is24HourMode) {
      // Dynamic axis range — labels only within actual data range, every 1h
      final int firstHour = dataMinX.ceil();
      final int lastHour = dataMaxX.floor();
      // Decide label interval so max ~8 labels are shown
      final int spanHours = (lastHour - firstHour).clamp(1, 24);
      final int labelInterval = (spanHours / 6).ceil().clamp(1, 6);

      bottomSideTitles = SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: 1, // check every integer hour
        getTitlesWidget: (val, meta) {
          final h = val.toInt();
          if (h < firstHour || h > lastHour) return const SizedBox.shrink();
          if ((h - firstHour) % labelInterval != 0) return const SizedBox.shrink();
          return Transform.rotate(
            angle: -0.785, // -45 degrees in radians
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Legacy index-based axis, show every nth label if many points — rotated 45°
      final labelEvery = (widget.data.length / 6).ceil().clamp(1, 999);
      final labels = <int, String>{};
      for (int i = 0; i < widget.data.length; i++) {
        final ts = widget.data[i].timestamp;
        labels[i] = ts.length >= 16 ? ts.substring(11, 16) : '$i';
      }
      bottomSideTitles = SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: labelEvery.toDouble(),
        getTitlesWidget: (val, meta) {
          final idx = val.toInt();
          if (idx < 0 || idx >= widget.data.length) {
            return const SizedBox.shrink();
          }
          if (idx % labelEvery != 0) return const SizedBox.shrink();
          return Transform.rotate(
            angle: -0.785, // -45 degrees in radians
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                labels[idx] ?? '',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minX: widget.is24HourMode ? dataMinX : null,
              maxX: widget.is24HourMode ? dataMaxX : null,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: widget.is24HourMode,
                verticalInterval: 1,
                horizontalInterval: (maxY - minY) / 4,
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
                    interval: (maxY - minY) / 4,
                    getTitlesWidget: (val, meta) => Text(
                      val.toStringAsFixed(0),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(sideTitles: bottomSideTitles),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        response?.lineBarSpots?.first.spotIndex ?? -1;
                  });
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      cs.inverseSurface.withValues(alpha: 0.88),
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final isTemp =
                          s.barIndex == 0 && widget.showBothLines ||
                          (s.barIndex == 0 && widget.showTemperature);
                      // In 24h mode, show the actual time from data point
                      String timeLabel = '';
                      if (widget.is24HourMode) {
                        final matchIdx = s.spotIndex;
                        if (matchIdx >= 0 && matchIdx < widget.data.length) {
                          final ts = widget.data[matchIdx].timestamp;
                          timeLabel = ts.length >= 16
                              ? '\n${ts.substring(11, 16)}'
                              : '';
                        }
                      }
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} ${isTemp ? "°C" : "%"}$timeLabel',
                        TextStyle(
                          color: cs.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: lines,
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLine({
    required List<FlSpot> spots,
    required Color color,
    bool isCurved = true,
    bool showDots = true,
    LinearGradient? gradient,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: isCurved,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: showDots,
        getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
          radius: idx == _touchedIndex ? 5 : 3,
          color: color,
          strokeColor: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
      belowBarData: gradient != null
          ? BarAreaData(show: true, gradient: gradient)
          : BarAreaData(show: false),
    );
  }

  Widget _buildEmpty(BuildContext context, ThemeData theme) {
    return Card(
      child: SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 40,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada data hari ini',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
