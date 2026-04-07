import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Beautiful dual-line chart for temperature (primary) and soil moisture
/// (secondary). Uses smooth cubic bezier curves, gradient fill, and animated
/// tooltips from fl_chart.
class SensorLineChart extends StatefulWidget {
  const SensorLineChart({
    super.key,
    required this.data,
    this.height = 180,
    this.showBothLines = true,
    this.showTemperature = true,
  });

  /// Ordered sensor history list (oldest → newest).
  final List<SensorData> data;
  final double height;

  /// When true, renders both temperature & soil-moisture lines.
  final bool showBothLines;

  /// When [showBothLines] is false, controls which single line to show.
  final bool showTemperature;

  @override
  State<SensorLineChart> createState() => _SensorLineChartState();
}

class _SensorLineChartState extends State<SensorLineChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
      return _buildEmpty(context, theme);
    }

    final tempSpots = <FlSpot>[];
    final moistSpots = <FlSpot>[];
    final labels = <String>[];

    for (int i = 0; i < widget.data.length; i++) {
      final d = widget.data[i];
      tempSpots.add(FlSpot(i.toDouble(), d.temperature));
      moistSpots.add(FlSpot(i.toDouble(), d.soilMoisture));
      // label: HH:mm from timestamp
      final ts = d.timestamp;
      labels.add(ts.length >= 16 ? ts.substring(11, 16) : '$i');
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

    final lines = <LineChartBarData>[];

    if (widget.showBothLines || widget.showTemperature) {
      lines.add(
        _buildLine(
          spots: tempSpots,
          color: cs.primary,
          isCurved: true,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
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
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[idx],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} ${isTemp ? "°C" : "%"}',
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
        show: true,
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
                'Belum ada data',
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
