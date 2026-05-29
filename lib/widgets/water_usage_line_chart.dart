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
          show: sortedData.length <= 40,
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
          show: sortedData.length <= 40,
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
                            getTooltipItems: (spots) {
                              if (spots.isEmpty) return [];
                              final idx = spots.first.spotIndex;
                              if (idx < 0 || idx >= sortedData.length) return [];
                              
                              final data = sortedData[idx];
                              String dateStr = data.date;
                              try {
                                final dt = DateTime.parse(data.date);
                                dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                              } catch (_) {}

                              // We return tooltip items corresponding to each line
                              // spots is sorted by line index
                              return spots.map((s) {
                                final isPure = s.barIndex == 0;
                                final label = isPure ? 'ETc Murni' : 'ETc+Fuzzy';
                                final valStr = s.y.toStringAsFixed(0);
                                
                                // Only show date on the first item to avoid repetition
                                final prefix = isPure ? '$dateStr\n' : '';
                                
                                return LineTooltipItem(
                                  '$prefix$label: $valStr mL',
                                  TextStyle(
                                    color: isPure ? Colors.orange.shade300 : Colors.blue.shade200,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
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
