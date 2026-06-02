import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DailyWaterUsage {
  final String date; // format: "YYYY-MM-DD"
  final double pureEtcVolume;
  final double fuzzyVolume;

  DailyWaterUsage({
    required this.date,
    required this.pureEtcVolume,
    required this.fuzzyVolume,
  });
}

class WaterUsageLineChart extends StatefulWidget {
  const WaterUsageLineChart({
    super.key,
    required this.data,
    this.height = 210,
  });

  final List<DailyWaterUsage> data;
  final double height;

  @override
  State<WaterUsageLineChart> createState() => _WaterUsageLineChartState();
}

class _WaterUsageLineChartState extends State<WaterUsageLineChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isEmpty = widget.data.isEmpty;
    
    // Ensure chronological sort
    final sortedData = List<DailyWaterUsage>.from(widget.data)
      ..sort((a, b) => a.date.compareTo(b.date));

    final pureEtcSpots = <FlSpot>[];
    final fuzzySpots = <FlSpot>[];
    double minX = 0, maxX = 0, minY = 0, maxY = 100;

    if (!isEmpty) {
      for (int i = 0; i < sortedData.length; i++) {
        final d = sortedData[i];
        pureEtcSpots.add(FlSpot(i.toDouble(), d.pureEtcVolume));
        fuzzySpots.add(FlSpot(i.toDouble(), d.fuzzyVolume));
      }

      minX = 0;
      maxX = (pureEtcSpots.length - 1).toDouble();
      if (maxX < 1) maxX = 1;

      final allVals = [
        ...pureEtcSpots.map((s) => s.y),
        ...fuzzySpots.map((s) => s.y),
      ];

      minY = allVals.reduce((a, b) => a < b ? a : b) - 50;
      if (minY < 0) minY = 0;
      maxY = allVals.reduce((a, b) => a > b ? a : b) * 1.2; // Add 20% top padding
      
      if ((maxY - minY) < 100) maxY = minY + 100;
    }

    final pureColor = Colors.orange.shade700;
    final fuzzyColor = cs.primary;

    final lines = [
      LineChartBarData(
        spots: pureEtcSpots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: pureColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, idx) => FlDotCirclePainter(
            radius: idx == _touchedIndex ? 4 : 2,
            color: pureColor,
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ),
      LineChartBarData(
        spots: fuzzySpots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: fuzzyColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, idx) => FlDotCirclePainter(
            radius: idx == _touchedIndex ? 4 : 2,
            color: fuzzyColor,
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              fuzzyColor.withValues(alpha: 0.25),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ];

    double xInterval = (maxX - minX) / 5;
    if (xInterval < 1) xInterval = 1;

    return Card(
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
                        reservedSize: 42,
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
                        reservedSize: 28,
                        interval: xInterval,
                        getTitlesWidget: (val, _) {
                          if (isEmpty) return const SizedBox.shrink();
                          final idx = val.toInt();
                          if (idx < 0 || idx >= sortedData.length) return const SizedBox.shrink();
                          try {
                            final dt = DateTime.parse(sortedData[idx].date);
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
                  showingTooltipIndicators: isEmpty
                      ? []
                      : List.generate(sortedData.length, (index) {
                          return ShowingTooltipIndicators([
                            LineBarSpot(lines[0], 0, lines[0].spots[index]),
                            LineBarSpot(lines[1], 1, lines[1].spots[index]),
                          ]);
                        }),
                  lineTouchData: LineTouchData(
                    enabled: !isEmpty,
                    handleBuiltInTouches: false,
                    touchCallback: isEmpty
                        ? null
                        : (event, response) {
                            if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null) {
                              setState(() {
                                _touchedIndex = -1;
                              });
                              return;
                            }
                            setState(() {
                              _touchedIndex = response.lineBarSpots!.first.spotIndex;
                            });
                          },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white.withValues(alpha: 0.95),
                      tooltipBorder: BorderSide(color: Colors.grey.shade300, width: 0.5),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      tooltipRoundedRadius: 6,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) {
                        if (spots.isEmpty) return [];
                        return spots.map((s) {
                          final idx = s.spotIndex;
                          String details = '';
                          if (idx == _touchedIndex && idx >= 0 && idx < sortedData.length) {
                            try {
                              final dt = DateTime.parse(sortedData[idx].date);
                              final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                              details = '$dateStr\n';
                            } catch (_) {
                              details = '${sortedData[idx].date}\n';
                            }
                          }
                          final isPure = s.barIndex == 0;
                          final valStr = s.y.toStringAsFixed(0);
                          return LineTooltipItem(
                            '$details$valStr mL',
                            TextStyle(
                              color: isPure ? Colors.orange.shade700 : cs.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
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
                      'Belum ada data riwayat air',
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
    );
  }
}
