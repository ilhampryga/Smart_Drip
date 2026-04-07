import 'package:flutter/material.dart';

/// Card showing irrigation information: pump duration and water volume.
class IrrigationInfoCard extends StatelessWidget {
  const IrrigationInfoCard({
    super.key,
    this.durationSeconds = 7.2,
    this.volumeMl = 80,
  });

  final double durationSeconds;
  final double volumeMl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Informasi Penyiraman',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoItem(
                  label: 'Durasi Pompa',
                  value: durationSeconds.toStringAsFixed(1),
                  unit: 'Detik',
                  icon: Icons.timer_outlined,
                ),
                VerticalDivider(
                  color: cs.outlineVariant,
                  thickness: 1,
                  width: 32,
                  indent: 4,
                  endIndent: 4,
                ),
                _InfoItem(
                  label: 'Volume Air',
                  value: volumeMl.toStringAsFixed(0),
                  unit: 'ml',
                  icon: Icons.opacity_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
