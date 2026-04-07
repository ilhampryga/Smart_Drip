import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Bar chart for irrigation water usage history.
///
/// Each bar represents one irrigation event, height = water volume (ml).
/// Bars are colored by mode:
///   - "ETC_FUZZY" → primary green gradient
///   - "NON_ETC"   → blue gradient
///   - other        → grey
class WaterUsageBarChart extends StatefulWidget {
  const WaterUsageBarChart({super.key, required this.data, this.height = 180});

  /// Ordered irrigation history list (oldest → newest).
  /// Each map must contain: 'water_volume' (num), 'start_time' (String),
  /// and optionally 'mode' (String: "ETC_FUZZY" | "NON_ETC").
  final List<Map<String, dynamic>> data;
  final double height;

  @override
  State<WaterUsageBarChart> createState() => _WaterUsageBarChartState();
}

class _WaterUsageBarChartState extends State<WaterUsageBarChart> {
  int _touchedIndex = -1;

  static List<Color> _gradientForMode(String mode, Color primary) {
    switch (mode) {
      case 'ETC_FUZZY':
        return [
          primary.withValues(alpha: 0.90),
          primary.withValues(alpha: 0.40),
        ];
      case 'NON_ETC':
        return [
          Colors.blueAccent.withValues(alpha: 0.90),
          Colors.blueAccent.withValues(alpha: 0.35),
        ];
      default:
        return [Colors.grey.shade400, Colors.grey.shade200];
    }
  }

  static List<Color> _gradientTouched(String mode, Color primary) {
    switch (mode) {
      case 'ETC_FUZZY':
        return [primary, primary.withValues(alpha: 0.70)];
      case 'NON_ETC':
        return [Colors.blueAccent, Colors.blueAccent.withValues(alpha: 0.65)];
      default:
        return [Colors.grey.shade600, Colors.grey.shade300];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
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

    final volumes = widget.data
        .map((d) => (d['water_volume'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final maxVol = volumes.isNotEmpty
        ? volumes.reduce((a, b) => a > b ? a : b)
        : 1.0;

    final modes = widget.data
        .map((d) => (d['mode'] as String?) ?? 'ETC_FUZZY')
        .toList();

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < widget.data.length; i++) {
      final isTouched = i == _touchedIndex;
      final mode = modes[i];
      final gradColors = isTouched
          ? _gradientTouched(mode, cs.primary)
          : _gradientForMode(mode, cs.primary);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: volumes[i],
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
          showingTooltipIndicators: isTouched ? [0] : [],
        ),
      );
    }

    // shortened time labels: "HH:mm"
    final labels = widget.data.map((d) {
      final t = (d['start_time'] as String?) ?? '';
      return t.length >= 16 ? t.substring(11, 16) : t;
    }).toList();

    final interval = maxVol > 0 ? maxVol / 4 : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          child: BarChart(
            BarChartData(
              maxY: maxVol * 1.25,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      cs.inverseSurface.withValues(alpha: 0.88),
                  getTooltipItem: (group, _, rod, __) {
                    final mode = modes[group.x];
                    final modeLabel = mode == 'ETC_FUZZY'
                        ? 'ETc+Fuzzy'
                        : 'Non-ETc';
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(0)} ml\n$modeLabel',
                      TextStyle(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
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
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }
}
