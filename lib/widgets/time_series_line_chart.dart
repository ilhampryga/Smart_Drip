import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class TimeSeriesLineChart extends StatefulWidget {
  const TimeSeriesLineChart({
    super.key,
    required this.data,
    this.height = 210,
    this.showTemperature = true,
  });

  final List<SensorData> data;
  final double height;

  /// true  → show temperature (°C)
  /// false → show soil moisture (%) with 60–80 % threshold
  final bool showTemperature;

  @override
  State<TimeSeriesLineChart> createState() => _TimeSeriesLineChartState();
}

class _TimeSeriesLineChartState extends State<TimeSeriesLineChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isEmpty = widget.data.isEmpty;
    
    // Sort data chronologically just in case
    final sortedData = List<SensorData>.from(widget.data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = <FlSpot>[];
    double minX = 0, maxX = 0, minY = 0, maxY = 100;

    if (!isEmpty) {
      for (int i = 0; i < sortedData.length; i++) {
        final d = sortedData[i];
        spots.add(FlSpot(i.toDouble(), widget.showTemperature ? d.temperature : d.soilMoisture));
      }

      if (spots.isNotEmpty) {
        minX = 0;
        maxX = (spots.length - 1).toDouble();
        if (maxX < 1) maxX = 1;

        final vals = spots.map((s) => s.y).toList();
        minY = vals.reduce((a, b) => a < b ? a : b) - 5;
        maxY = vals.reduce((a, b) => a > b ? a : b) + 5;

        if (!widget.showTemperature) {
          minY = minY.clamp(0, 50).toDouble();
          maxY = maxY < 90 ? 90 : maxY;
        } else {
          minY = minY.clamp(0, 15).toDouble();
          maxY = maxY < 40 ? 40 : maxY;
        }
        if ((maxY - minY) < 10) maxY = minY + 10;
      }
    } else {
      minY = 0;
      maxY = widget.showTemperature ? 45 : 90;
    }

    final color = widget.showTemperature ? cs.primary : Colors.blueAccent;

    final lines = [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: spots.length <= 40,
          getDotPainter: (_, __, ___, idx) => FlDotCirclePainter(
            radius: idx == _touchedIndex ? 4 : 2,
            color: color,
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      )
    ];

    final thresholds = <HorizontalLine>[];
    if (!widget.showTemperature) {
      thresholds.add(_hline(60, Colors.green.shade500, 'Min 60%'));
      thresholds.add(_hline(80, Colors.green.shade700, 'Max 80%'));
    }

    double xInterval = (maxX - minX) / 5;
    if (xInterval < 1) xInterval = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: widget.height,
                  child: LineChart(
                    LineChartData(
                      minX: isEmpty ? 0 : minX,
                      maxX: isEmpty ? 1 : maxX,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),
                      extraLinesData: ExtraLinesData(horizontalLines: thresholds),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        verticalInterval: xInterval,
                        horizontalInterval: (maxY - minY) / 5,
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
                            interval: (maxY - minY) / 5,
                            getTitlesWidget: (val, _) => Text(
                              val.toStringAsFixed(0),
                              style: const TextStyle(color: Colors.grey, fontSize: 9),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: xInterval,
                            getTitlesWidget: (val, _) {
                              if (isEmpty) return const SizedBox.shrink();
                              final idx = val.toInt();
                              if (idx < 0 || idx >= sortedData.length) return const SizedBox.shrink();
                              try {
                                final dt = DateTime.parse(sortedData[idx].timestamp);
                                String text = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey, fontSize: 9, height: 1.2),
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineTouchData: isEmpty
                          ? const LineTouchData(enabled: false)
                          : LineTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  _touchedIndex = response?.lineBarSpots?.first.spotIndex ?? -1;
                                });
                              },
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => cs.inverseSurface.withValues(alpha: 0.9),
                                getTooltipItems: (spots) => spots.map((s) {
                                  final idx = s.x.toInt();
                                  if (idx < 0 || idx >= sortedData.length) {
                                    return LineTooltipItem('', const TextStyle());
                                  }
                                  try {
                                    final dt = DateTime.parse(sortedData[idx].timestamp);
                                    final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                                    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    final unit = widget.showTemperature ? '°C' : '%';
                                    return LineTooltipItem(
                                      '$dateStr $timeStr\n${s.y.toStringAsFixed(1)} $unit',
                                      TextStyle(
                                        color: cs.onInverseSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    );
                                  } catch (_) {
                                    return LineTooltipItem('${s.y.toStringAsFixed(1)}', const TextStyle());
                                  }
                                }).toList(),
                              ),
                            ),
                      lineBarsData: lines,
                    ),
                  ),
                ),
                if (isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_outlined, size: 18, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Belum ada data',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (!widget.showTemperature)
          const _ThresholdLegend(showTemperature: false),
      ],
    );
  }

  HorizontalLine _hline(double y, Color color, String label) => HorizontalLine(
        y: y,
        color: color,
        strokeWidth: 1.5,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      );
}

class _ThresholdLegend extends StatelessWidget {
  const _ThresholdLegend({required this.showTemperature});
  final bool showTemperature;

  @override
  Widget build(BuildContext context) {
    if (showTemperature) return const SizedBox.shrink();
    
    final items = [
      (Colors.green.shade500, 'Ambang Min 60%'),
      (Colors.green.shade700, 'Ambang Max 80%'),
    ];
    return Wrap(
      spacing: 12,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: item.$1,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$2,
              style: TextStyle(color: item.$1, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ],
        );
      }).toList(),
    );
  }
}
