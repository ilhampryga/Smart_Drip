import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Beautiful dual-line chart for temperature (primary) and soil moisture
/// (secondary). Supports a clean 24-hour mode where the X-axis represents
/// 0–23 hours regardless of how many data points exist.
class SensorLineChart extends StatefulWidget {
  const SensorLineChart({
    super.key,
    required this.data,
    this.height = 180,
    this.showBothLines = true,
    this.showTemperature = true,
    this.is24HourMode = false,
    this.irrigationData = const [],
  });

  final List<SensorData> data;
  final double height;
  final bool showBothLines;
  final bool showTemperature;
  final bool is24HourMode;
  final List<Map<String, dynamic>> irrigationData;

  @override
  State<SensorLineChart> createState() => _SensorLineChartState();
}

class _SensorLineChartState extends State<SensorLineChart> {
  int _touchedIndex = -1;

  /// Parse hour (0–23) from an ISO-8601 or "YYYY-MM-DD" timestamp.
  double _hourFromTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return dt.hour + dt.minute / 60.0;
    } catch (_) {
      return 0;
    }
  }

  bool _isIrrigationTime(DateTime sensorTime, List<DateTime> irrigationTimes) {
    for (final irrigTime in irrigationTimes) {
      final diffToIrrig = sensorTime.difference(irrigTime).inMinutes.abs();
      if (diffToIrrig <= 15) return true;
    }
    return false;
  }

  List<int> _findDailyMinMaxIndices(List<SensorData> data) {
    if (data.isEmpty) return [];
    final Map<String, List<int>> dailyIndices = {};
    for (int i = 0; i < data.length; i++) {
      final ts = data[i].timestamp;
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
      double minVal = data[minIdx].temperature;
      double maxVal = data[maxIdx].temperature;
      for (final idx in indices) {
        final temp = data[idx].temperature;
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
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final isEmpty = widget.data.isEmpty;

    if (isEmpty) {
      return _buildEmpty(context, theme);
    }

    final tempSpots = <FlSpot>[];
    final moistSpots = <FlSpot>[];

    // Compute X range from actual data when in 24h mode
    double dataMinX = 0;
    double dataMaxX = 23;

    for (int i = 0; i < widget.data.length; i++) {
      final d = widget.data[i];
      final x = widget.is24HourMode
          ? _hourFromTimestamp(d.timestamp)
          : i.toDouble();
      tempSpots.add(FlSpot(x, d.temperature));
      moistSpots.add(FlSpot(x, d.soilMoisture));
    }

    // fl_chart requires spots to be sorted by X to prevent "monotonically increasing" assertion errors.
    tempSpots.sort((a, b) => a.x.compareTo(b.x));
    moistSpots.sort((a, b) => a.x.compareTo(b.x));

    if (widget.is24HourMode && tempSpots.isNotEmpty) {
      dataMinX = tempSpots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      dataMaxX = tempSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      // Add 0.5h padding on each side so first/last point isn't at the edge
      dataMinX = (dataMinX - 0.5).clamp(0.0, 23.0);
      dataMaxX = (dataMaxX + 0.5).clamp(0.0, 24.0);
      // Ensure minimum visible range of 2h
      if ((dataMaxX - dataMinX) < 2) dataMaxX = dataMinX + 2;
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

    // Ensure a minimum range so the chart doesn't look flat
    if ((maxY - minY) < 5) {
      maxY = minY + 5;
    }

    final List<int> targetIndices = [];
    if (!isEmpty) {
      if (widget.showTemperature) {
        targetIndices.addAll(_findDailyMinMaxIndices(widget.data));
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
          for (int i = 0; i < widget.data.length; i++) {
            final d = widget.data[i];
            try {
              final sensorTime = DateTime.parse(d.timestamp);
              if (_isIrrigationTime(sensorTime, irrigationTimes)) {
                targetIndices.add(i);
              }
            } catch (_) {}
          }
        }
      }
    }

    final lines = <LineChartBarData>[];

    if (widget.showBothLines || widget.showTemperature) {
      lines.add(
        _buildLine(
          spots: tempSpots,
          color: cs.primary,
          targetIndices: targetIndices,
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
          targetIndices: targetIndices,
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

    final List<ShowingTooltipIndicators> tooltipIndicators = [];
    if (!isEmpty) {
      final List<int> activeIndices = List<int>.from(targetIndices);

      if (_touchedIndex >= 0 && _touchedIndex < widget.data.length && !activeIndices.contains(_touchedIndex)) {
        activeIndices.add(_touchedIndex);
      }

      final lineIndex = widget.showBothLines ? (widget.showTemperature ? 0 : 1) : 0;
      if (lineIndex < lines.length) {
        final line = lines[lineIndex];
        for (final idx in activeIndices) {
          if (idx >= 0 && idx < line.spots.length) {
            tooltipIndicators.add(
              ShowingTooltipIndicators([
                LineBarSpot(line, lineIndex, line.spots[idx]),
              ]),
            );
          }
        }
      }
    }

    // Build bottom titles configuration
    final SideTitles bottomSideTitles;
    if (widget.is24HourMode) {
      // Dynamic axis range — labels only within actual data range, every 1h
      final int firstHour = dataMinX.ceil();
      final int lastHour = dataMaxX.floor();
      // Decide label interval so max ~8 labels are shown
      final int spanHours = (lastHour - firstHour).clamp(1, 24);
      final int labelInterval = (spanHours / 6).ceil().clamp(1, 6);

      bottomSideTitles = SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: 1, // check every integer hour
        getTitlesWidget: (val, meta) {
          final h = val.toInt();
          if (h < firstHour || h > lastHour) return const SizedBox.shrink();
          if ((h - firstHour) % labelInterval != 0) return const SizedBox.shrink();
          return Transform.rotate(
            angle: -0.785, // -45 degrees in radians
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Legacy index-based axis, show every nth label if many points — rotated 45°
      final labelEvery = (widget.data.length / 6).ceil().clamp(1, 999);
      final labels = <int, String>{};
      for (int i = 0; i < widget.data.length; i++) {
        final ts = widget.data[i].timestamp;
        labels[i] = ts.length >= 16 ? ts.substring(11, 16) : '$i';
      }
      bottomSideTitles = SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: labelEvery.toDouble(),
        getTitlesWidget: (val, meta) {
          final idx = val.toInt();
          if (idx < 0 || idx >= widget.data.length) {
            return const SizedBox.shrink();
          }
          if (idx % labelEvery != 0) return const SizedBox.shrink();
          return Transform.rotate(
            angle: -0.785, // -45 degrees in radians
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                labels[idx] ?? '',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minX: widget.is24HourMode ? dataMinX : null,
              maxX: widget.is24HourMode ? dataMaxX : null,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              showingTooltipIndicators: tooltipIndicators,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: widget.is24HourMode,
                verticalInterval: 1,
                horizontalInterval: (maxY - minY) / 4,
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
                bottomTitles: AxisTitles(sideTitles: bottomSideTitles),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
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
                    return spots.map((s) {
                      final isTemp =
                          s.barIndex == 0 && widget.showBothLines ||
                          (s.barIndex == 0 && widget.showTemperature);
                      
                      final idx = s.spotIndex;
                      String details = '';
                      if (idx == _touchedIndex && idx >= 0 && idx < widget.data.length) {
                        try {
                          final dt = DateTime.parse(widget.data[idx].timestamp);
                          final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                          final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          details = '$dateStr $timeStr\n';
                        } catch (_) {}
                      }

                      return LineTooltipItem(
                        '$details${s.y.toStringAsFixed(1)} ${isTemp ? "°C" : "%"}',
                        TextStyle(
                          color: isTemp ? cs.primary : Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
    required List<int> targetIndices,
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
        checkToShowDot: (spot, barData) {
          final idx = barData.spots.indexOf(spot);
          return targetIndices.contains(idx) || idx == _touchedIndex;
        },
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
                'Belum ada data hari ini',
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
