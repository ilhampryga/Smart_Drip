import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PlantPhaseChart extends StatelessWidget {
  const PlantPhaseChart({
    super.key,
    required this.currentHst,
  });

  final int? currentHst;

  double getKc(int hst) {
    if (hst <= 30) return 0.60;
    if (hst <= 70) return 0.60 + (hst - 30) * ((1.05 - 0.60) / 40);
    if (hst <= 180) return 1.05;
    if (hst <= 210) return 1.05 - (hst - 180) * ((1.05 - 0.90) / 30);
    return 0.90;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final hstVal = currentHst?.clamp(0, 210) ?? 0;
    final currentKc = getKc(hstVal);

    // Generate spots for the 4 segments
    final awalSpots = List.generate(31, (i) => FlSpot(i.toDouble(), getKc(i)));
    final perkemSpots = List.generate(41, (i) => FlSpot((i + 30).toDouble(), getKc(i + 30)));
    final tengahSpots = List.generate(111, (i) => FlSpot((i + 70).toDouble(), getKc(i + 70)));
    final akhirSpots = List.generate(31, (i) => FlSpot((i + 180).toDouble(), getKc(i + 180)));

    final cAwal = Colors.green.shade600;
    final cPerkem = Colors.blue.shade600;
    final cTengah = Colors.orange.shade400;
    final cAkhir = Colors.red.shade600;

    LineChartBarData buildLine(List<FlSpot> spots, Color color) {
      return LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 3,
        isCurved: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.1),
        ),
      );
    }

    return Column(
      children: [
        // Top Indicators (Umur Saat Ini & Kc)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text('Umur Saat Ini', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('$hstVal HST', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text('Nilai Kc', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(currentKc.toStringAsFixed(2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 16, top: 24, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 210,
              minY: 0,
              maxY: 1.4,
              lineTouchData: const LineTouchData(enabled: false), // Static chart, interactive via textfield
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 0.2,
                verticalInterval: 30,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 0.2,
                    getTitlesWidget: (val, _) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          val.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 30,
                    getTitlesWidget: (val, _) {
                      if (val == 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          val.toInt().toString(),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(x: 30, color: Colors.grey.shade400, strokeWidth: 1, dashArray: [4, 4]),
                  VerticalLine(x: 70, color: Colors.grey.shade400, strokeWidth: 1, dashArray: [4, 4]),
                  VerticalLine(x: 180, color: Colors.grey.shade400, strokeWidth: 1, dashArray: [4, 4]),
                  // Indicator for current HST
                  if (currentHst != null && currentHst! <= 210)
                    VerticalLine(
                      x: currentHst!.toDouble(),
                      color: Colors.blue.shade800,
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                      label: VerticalLineLabel(
                        show: true,
                        labelResolver: (_) => '$hstVal HST',
                        alignment: Alignment.topRight,
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                    ),
                ],
              ),
              lineBarsData: [
                buildLine(awalSpots, cAwal),
                buildLine(perkemSpots, cPerkem),
                buildLine(tengahSpots, cTengah),
                buildLine(akhirSpots, cAkhir),
                // Current point
                if (currentHst != null && currentHst! <= 210)
                  LineChartBarData(
                    spots: [FlSpot(hstVal.toDouble(), currentKc)],
                    color: Colors.blue.shade800,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.blue.shade800,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Phase Legends
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _Legend(color: cAwal, label: 'Awal (0-30)'),
            _Legend(color: cPerkem, label: 'Perkembangan (31-70)'),
            _Legend(color: cTengah, label: 'Tengah (71-180)'),
            _Legend(color: cAkhir, label: 'Akhir (181-210)'),
          ],
        )
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
