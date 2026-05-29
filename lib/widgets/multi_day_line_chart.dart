import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Multi-day line chart: one colored line per calendar date.
/// Adds dashed threshold lines (ambang batas wajar).
class MultiDayLineChart extends StatefulWidget {
  const MultiDayLineChart({
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
  State<MultiDayLineChart> createState() => _MultiDayLineChartState();
}

class _MultiDayLineChartState extends State<MultiDayLineChart> {
  // Palette — up to 10 distinct day-colors
  static const _palette = [
    Color(0xFF6366F1), // indigo
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFF06B6D4), // cyan
    Color(0xFFEC4899), // pink
    Color(0xFF84CC16), // lime
    Color(0xFFF97316), // orange
    Color(0xFF14B8A6), // teal
  ];

  Map<String, List<SensorData>> _groupByDate(List<SensorData> data) {
    final map = <String, List<SensorData>>{};
    for (final d in data) {
      final key =
          d.timestamp.length >= 10 ? d.timestamp.substring(0, 10) : 'unknown';
      map.putIfAbsent(key, () => []).add(d);
    }
    return map;
  }

  double _hour(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return dt.hour + dt.minute / 60.0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isEmpty = widget.data.isEmpty;
    final grouped = isEmpty ? <String, List<SensorData>>{} : _groupByDate(widget.data);
    final dates = grouped.keys.toList()..sort();

    // ── Build one LineChartBarData per date ──────────────────────────────────
    final lines = <LineChartBarData>[];
    final colorMap = <String, Color>{};

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final color = _palette[i % _palette.length];
      colorMap[date] = color;

      final dayData = grouped[date]!
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final spots = dayData
          .map((d) => FlSpot(
                _hour(d.timestamp),
                widget.showTemperature ? d.temperature : d.soilMoisture,
              ))
          .toList();

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: dayData.length <= 30,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 2.5,
            color: color,
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    // ── Y range — default values when no data ────────────────────────────────
    double minY, maxY;
    if (isEmpty) {
      minY = 0;
      maxY = widget.showTemperature ? 45 : 90;
    } else {
      final vals = widget.data
          .map((d) => widget.showTemperature ? d.temperature : d.soilMoisture)
          .toList();
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

    // ── Threshold dashed lines ────────────────────────────────────────────
    final thresholds = <HorizontalLine>[];
    if (!widget.showTemperature) {
      thresholds.add(_hline(60, Colors.green.shade500, 'Min 60%'));
      thresholds.add(_hline(80, Colors.green.shade700, 'Max 80%'));
    }
    // Temperature: no threshold lines

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-line legend (only when there is actual data)
        if (!isEmpty) _Legend(dates: dates, colorMap: colorMap, theme: theme),
        const SizedBox(height: 8),
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
                      minX: 0,
                      maxX: 23,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),
                      extraLinesData:
                          ExtraLinesData(horizontalLines: thresholds),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        verticalInterval: 3,
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
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 9),
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
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 9),
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
                      lineTouchData: isEmpty
                          ? const LineTouchData(enabled: false)
                          : LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) =>
                                    cs.inverseSurface.withValues(alpha: 0.9),
                                getTooltipItems: (spots) => spots.map((s) {
                                  final date = s.barIndex < dates.length
                                      ? dates[s.barIndex]
                                      : '';
                                  final shortDate = date.length >= 10
                                      ? date.substring(5)
                                      : date;
                                  final unit =
                                      widget.showTemperature ? '°C' : '%';
                                  // Reconstruct HH:MM from x (hour as float)
                                  final h = s.x.toInt();
                                  final m =
                                      ((s.x - s.x.floorToDouble()) * 60)
                                          .round();
                                  final timeStr =
                                      '${h.toString().padLeft(2, '0')}:'
                                      '${m.toString().padLeft(2, '0')}';
                                  return LineTooltipItem(
                                    '$shortDate  $timeStr\n'
                                    '${s.y.toStringAsFixed(1)} $unit',
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
                // Empty-state overlay
                if (isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_outlined,
                            size: 18, color: Colors.grey.shade400),
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
        // Threshold legend (only shown for soil moisture)
        if (!widget.showTemperature)
          _ThresholdLegend(showTemperature: widget.showTemperature),
      ],
    );
  }

  HorizontalLine _hline(double y, Color color, String label) =>
      HorizontalLine(
        y: y,
        color: color,
        strokeWidth: 1.5,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      );

}

// ── Legend widgets ─────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.dates,
      required this.colorMap,
      required this.theme});
  final List<String> dates;
  final Map<String, Color> colorMap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: dates.map((d) {
        final color = colorMap[d]!;
        final label = d.length >= 10 ? d.substring(5) : d;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.grey.shade600, fontSize: 10)),
          ],
        );
      }).toList(),
    );
  }
}

class _ThresholdLegend extends StatelessWidget {
  const _ThresholdLegend({required this.showTemperature});
  final bool showTemperature;

  @override
  Widget build(BuildContext context) {
    final items = showTemperature
        ? <(Color, String)>[]
        : [
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
              style: TextStyle(
                  color: item.$1,
                  fontSize: 9,
                  fontWeight: FontWeight.w600),
            ),
          ],
        );
      }).toList(),
    );
  }
}
