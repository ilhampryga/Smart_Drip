import 'package:flutter/material.dart';

/// A card that serves as a placeholder for a chart.
///
/// Renders a title and a lightweight custom-painted line-chart silhouette
/// to visually represent where a real chart (e.g., fl_chart) will go.
class ChartPlaceholder extends StatelessWidget {
  const ChartPlaceholder({super.key, required this.title, this.height = 160.0});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(primaryColor: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.primaryColor});
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Axis lines
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h), Offset(w, h), axisPaint); // x-axis
    canvas.drawLine(Offset(0, 0), Offset(0, h), axisPaint); // y-axis

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 3; i++) {
      final y = h * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Line 1 – primary color (main sensor)
    final points1 = _buildPoints(w, h, const [
      0.1,
      0.25,
      0.4,
      0.55,
      0.45,
      0.65,
      0.8,
      0.9,
    ]);
    _drawLine(canvas, points1, primaryColor, 2.5);
    _drawFill(canvas, points1, primaryColor.withValues(alpha: 0.12), h);

    // Line 2 – secondary (lighter tone, e.g., soil moisture companion)
    final points2 = _buildPoints(w, h, const [
      0.05,
      0.15,
      0.3,
      0.35,
      0.3,
      0.5,
      0.6,
      0.75,
    ]);
    _drawLine(canvas, points2, Colors.grey.shade400, 1.8);

    // Dots on primary line
    final dotPaint = Paint()..color = primaryColor;
    for (final p in points1) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  List<Offset> _buildPoints(double w, double h, List<double> yFractions) {
    final step = w / (yFractions.length - 1);
    return List.generate(
      yFractions.length,
      (i) => Offset(i * step, h * (1 - yFractions[i])),
    );
  }

  void _drawLine(Canvas canvas, List<Offset> pts, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      path.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawFill(Canvas canvas, List<Offset> pts, Color color, double h) {
    final path = Path()..moveTo(pts.first.dx, h);
    path.lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      path.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    path.lineTo(pts.last.dx, h);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor;
}
