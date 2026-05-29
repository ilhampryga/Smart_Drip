import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Bar chart untuk penggunaan air irigasi.
///
/// - Setiap bar = 1 event irigasi.
/// - Sumbu X: label "dd/MM HH:mm" untuk bar pertama setiap hari,
///   "HH:mm" untuk bar hari yang sama.
/// - Tooltip: tanggal+waktu lengkap, volume, mode.
/// - Scroll horizontal otomatis saat bar > 8.
class WaterUsageBarChart extends StatefulWidget {
  const WaterUsageBarChart({
    super.key,
    required this.data,
    this.height = 180,
  });

  /// Setiap map harus mengandung: 'water_volume' (num), 'timestamp' (String),
  /// dan opsional 'mode' (String: "ETC_FUZZY" | "NON_ETC").
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

  /// Ekstrak "HH:mm" dari timestamp.
  String _toHhmm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(11, 16) : raw;
    }
  }

  /// Ekstrak "dd/MM" dari timestamp.
  String _toDdMm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Format "dd/MM HH:mm" untuk tooltip.
  String _toDateHhmm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length >= 16 ? raw.substring(5, 16) : raw;
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
                Icon(Icons.bar_chart_outlined,
                    size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Belum ada data irigasi',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int count = widget.data.length;
    final timestamps =
        widget.data.map((d) => d['timestamp'] as String? ?? '').toList();

    final volumes = widget.data
        .map((d) => (d['water_volume'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final maxVol =
        volumes.isNotEmpty ? volumes.reduce((a, b) => a > b ? a : b) : 1.0;

    final modes =
        widget.data.map((d) => (d['mode'] as String?) ?? 'ETC_FUZZY').toList();

    // Label sumbu X: "dd/MM\nHH:mm" untuk bar pertama setiap hari, "HH:mm" saja untuk hari yang sama
    final xLabels = List<String>.generate(count, (i) {
      final ts = timestamps[i];
      final ddmm = _toDdMm(ts);
      final hhmm = _toHhmm(ts);
      if (i == 0) return '$ddmm\n$hhmm'; // bar pertama selalu tampilkan tanggal
      final prevDdmm = _toDdMm(timestamps[i - 1]);
      // Tampilkan tanggal hanya saat berganti hari
      return ddmm != prevDdmm ? '$ddmm\n$hhmm' : hhmm;
    });

    // Label tooltip: "dd/MM HH:mm"
    final tooltipLabels = timestamps.map((t) => _toDateHhmm(t)).toList();

    // Warna label: primer saat ada tanggal, abu-abu untuk jam saja
    final xLabelColors = List<Color>.generate(count, (i) {
      final ts = timestamps[i];
      final ddmm = _toDdMm(ts);
      if (i == 0) return cs.primary;
      final prevDdmm = _toDdMm(timestamps[i - 1]);
      return ddmm != prevDdmm ? cs.primary : Colors.grey.shade500;
    });

    final double barWidth = count <= 6
        ? 26.0
        : count <= 12
            ? 18.0
            : 12.0;

    // Build bar groups
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
            getTooltipColor: (_) => cs.inverseSurface.withValues(alpha: 0.88),
            getTooltipItem: (group, _, rod, __) {
              final idx = group.x;
              final modeLabel =
                  modes[idx] == 'ETC_FUZZY' ? 'ETc+Fuzzy' : 'Non-ETc';
              final dtLabel = tooltipLabels[idx].isNotEmpty
                  ? tooltipLabels[idx]
                  : xLabels[idx];
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)} ml\n$modeLabel'
                '${dtLabel.isNotEmpty ? '\n$dtLabel' : ''}',
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
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.grey.shade500, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= count) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    xLabels[idx],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: xLabelColors[idx],
                      fontSize: 9,
                      fontWeight: xLabelColors[idx] == Colors.grey.shade500
                          ? FontWeight.normal
                          : FontWeight.bold,
                      height: 1.2,
                    ),
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        groupsSpace: count > 12 ? 4 : 8,
        alignment: BarChartAlignment.spaceEvenly,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          child: count > 8
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: count * (barWidth + 14),
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
