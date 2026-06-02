import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class TimeSeriesLineChart extends StatefulWidget {
  const TimeSeriesLineChart({
    super.key,
    required this.data,
    this.height = 210,
    this.showTemperature = true,
    this.irrigationData = const [],
  });

  final List<SensorData> data;
  final double height;

  /// true  → show temperature (°C)
  /// false → show soil moisture (%) with 60–80 % threshold
  final bool showTemperature;
  final List<Map<String, dynamic>> irrigationData;

  @override
  State<TimeSeriesLineChart> createState() => _TimeSeriesLineChartState();
}

class _TimeSeriesLineChartState extends State<TimeSeriesLineChart> {
  int _touchedIndex = -1;

  bool _isIrrigationTime(DateTime sensorTime, List<DateTime> irrigationTimes) {
    for (final irrigTime in irrigationTimes) {
      final diffToIrrig = sensorTime.difference(irrigTime).inMinutes.abs();
      if (diffToIrrig <= 15) return true;
    }
    return false;
  }

  List<int> _findDailyMinMaxIndices(List<SensorData> sortedData) {
    if (sortedData.isEmpty) return [];
    final Map<String, List<int>> dailyIndices = {};
    for (int i = 0; i < sortedData.length; i++) {
      final ts = sortedData[i].timestamp;
      if (ts.length >= 10) {
        final date = ts.substring(0, 10);
        dailyIndices.putIfAbsent(date, () => []).add(i);
      }
    }
    final List<int> result = [];
    for (final indices in dailyIndices.values) {
      if (indices.isEmpty) continue;
      int minIdx = indices[0];
      int maxIdx = indices[0];
      double minVal = sortedData[minIdx].temperature;
      double maxVal = sortedData[maxIdx].temperature;
      for (final idx in indices) {
        final temp = sortedData[idx].temperature;
        if (temp < minVal) {
          minVal = temp;
          minIdx = idx;
        }
        if (temp > maxVal) {
          maxVal = temp;
          maxIdx = idx;
        }
      }
      result.add(minIdx);
      if (minIdx != maxIdx) {
        result.add(maxIdx);
      }
    }
    return result;
  }

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

    final List<int> targetIndices = [];
    if (!isEmpty) {
      if (widget.showTemperature) {
        targetIndices.addAll(_findDailyMinMaxIndices(sortedData));
      } else {
        if (widget.irrigationData.isNotEmpty) {
          final List<DateTime> irrigationTimes = [];
          for (final irrig in widget.irrigationData) {
            final ts = irrig['timestamp'] as String?;
            if (ts != null && ts.isNotEmpty) {
              try {
                irrigationTimes.add(DateTime.parse(ts));
              } catch (_) {}
            }
          }
          for (int i = 0; i < sortedData.length; i++) {
            try {
              final sensorTime = DateTime.parse(sortedData[i].timestamp);
              if (_isIrrigationTime(sensorTime, irrigationTimes)) {
                targetIndices.add(i);
              }
            } catch (_) {}
          }
        }
      }
    }

    final lines = [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, barData) {
            final idx = barData.spots.indexOf(spot);
            return targetIndices.contains(idx) || idx == _touchedIndex;
          },
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

    final List<ShowingTooltipIndicators> tooltipIndicators = [];
    if (!isEmpty) {
      final List<int> activeIndices = List<int>.from(targetIndices);

      if (_touchedIndex >= 0 && _touchedIndex < sortedData.length && !activeIndices.contains(_touchedIndex)) {
        activeIndices.add(_touchedIndex);
      }

      for (final idx in activeIndices) {
        if (idx >= 0 && idx < spots.length) {
          tooltipIndicators.add(
            ShowingTooltipIndicators([
              LineBarSpot(lines[0], 0, spots[idx]),
            ]),
          );
        }
      }
    }

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
                      showingTooltipIndicators: tooltipIndicators,
                      extraLinesData: ExtraLinesData(horizontalLines: thresholds),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        verticalInterval: 1,
                        horizontalInterval: (maxY - minY) / 5,
                        checkToShowVerticalLine: (value) {
                          final idx = value.round();
                          if (idx <= 0 || idx >= sortedData.length) return false;
                          final prevTs = sortedData[idx - 1].timestamp;
                          final currTs = sortedData[idx].timestamp;
                          if (prevTs.length < 10 || currTs.length < 10) return false;
                          return prevTs.substring(0, 10) != currTs.substring(0, 10);
                        },
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                        getDrawingVerticalLine: (_) =>
                            FlLine(
                              color: Colors.grey.shade400.withValues(alpha: 0.5),
                              strokeWidth: 1.2,
                              dashArray: [4, 4],
                            ),
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
                            interval: 1,
                            getTitlesWidget: (val, _) {
                              if (isEmpty) return const SizedBox.shrink();
                              final idx = val.round();
                              if (idx < 0 || idx >= sortedData.length) return const SizedBox.shrink();
                              
                              bool showTitle = false;
                              if (idx == 0) {
                                showTitle = true;
                              } else {
                                final prevTs = sortedData[idx - 1].timestamp;
                                final currTs = sortedData[idx].timestamp;
                                if (prevTs.length >= 10 && currTs.length >= 10) {
                                  showTitle = prevTs.substring(0, 10) != currTs.substring(0, 10);
                                }
                              }
                              
                              if (!showTitle) return const SizedBox.shrink();
                              
                              try {
                                final dt = DateTime.parse(sortedData[idx].timestamp);
                                String text = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              enabled: true,
                              handleBuiltInTouches: false,
                              touchCallback: (event, response) {
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
                                getTooltipItems: (spots) => spots.map((s) {
                                  final idx = s.spotIndex;
                                  String details = '';
                                  if (idx == _touchedIndex && idx >= 0 && idx < sortedData.length) {
                                    try {
                                      final dt = DateTime.parse(sortedData[idx].timestamp);
                                      final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                                      final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                      details = '$dateStr $timeStr\n';
                                    } catch (_) {}
                                  }
                                  final unit = widget.showTemperature ? '°C' : '%';
                                  return LineTooltipItem(
                                    '$details${s.y.toStringAsFixed(1)} $unit',
                                    TextStyle(
                                      color: widget.showTemperature ? cs.primary : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  );
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
