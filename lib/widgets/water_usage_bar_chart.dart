import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Bar chart for irrigation water usage.
///
/// In 24-hour mode (default for dashboard):
///   - Each bar represents one irrigation event today.
///   - X-axis labels show HH:mm, max 8 labels shown to avoid crowding.
///   - Bars are auto-sized and the chart scrolls horizontally if data > 8.
///
/// Bars are colored by mode:
///   - "ETC_FUZZY" → primary green gradient
///   - "NON_ETC"   → blue gradient
///   - other        → grey
class WaterUsageBarChart extends StatefulWidget {
  const WaterUsageBarChart({
    super.key,
    required this.data,
    this.height = 180,
  });

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

  /// Shorten a timestamp string to "HH:mm".
  String _toHhmm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(11, 16) : raw;
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
                  'Belum ada irigasi hari ini',
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

    final labels = widget.data
        .map((d) => _toHhmm(d['start_time'] as String?))
        .toList();

    // Decide bar width based on count; scroll if too many
    final int count = widget.data.length;
    final double barWidth = count <= 6
        ? 28.0
        : count <= 12
            ? 18.0
            : 12.0;

    // Show label every N bars to avoid crowding (target max ~8 labels)
    final int labelEvery = (count / 8).ceil().clamp(1, 999);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < count; i++) {
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
              width: barWidth,
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

    final interval = maxVol > 0 ? maxVol / 4 : 1.0;

    // Chart content
    final chartWidget = BarChart(
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
              final modeLabel =
                  mode == 'ETC_FUZZY' ? 'ETc+Fuzzy' : 'Non-ETc';
              final timeLabel = labels[group.x];
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)} ml\n$modeLabel'
                '${timeLabel.isNotEmpty ? '\n$timeLabel' : ''}',
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
              reservedSize: 36,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                // Only show every labelEvery-th label
                if (idx % labelEvery != 0) return const SizedBox.shrink();
                return Transform.rotate(
                  angle: -0.785, // -45 degrees in radians
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      labels[idx],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                      ),
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
        // Spacing between bars
        groupsSpace: count > 12 ? 4 : 8,
        alignment: BarChartAlignment.spaceEvenly,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          // Scroll horizontally when there are many bars
          child: count > 12
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: count * (barWidth + 12),
                    height: widget.height - 24,
                    child: chartWidget,
                  ),
                )
              : chartWidget,
        ),
      ),
    );
  }
}
