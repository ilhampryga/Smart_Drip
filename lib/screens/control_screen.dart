import 'package:flutter/material.dart';
import '../widgets/water_usage_bar_chart.dart';
import '../widgets/irrigation_info_card.dart';
import '../services/firebase_service.dart';
import '../models/system_control.dart' show SystemControl;

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService.instance;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kontroll')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<SystemControl>(
            stream: svc.systemControlStream,
            builder: (context, ctrlSnap) {
              final ctrl = ctrlSnap.data;
              final etcFuzzy = ctrl?.isEtcFuzzy ?? true;
              final nonEtc = ctrl != null && !ctrl.isEtcFuzzy;

              return StreamBuilder<Map<String, dynamic>>(
                stream: svc.irrigationLogStream,
                builder: (context, logSnap) {
                  final log = logSnap.data ?? {};
                  final duration = (log['duration'] as num?)?.toDouble() ?? 0.0;
                  final volume =
                      (log['water_volume'] as num?)?.toDouble() ?? 0.0;

                  return Column(
                    children: [
                      _IrrigationModeCard(
                        etcFuzzyEnabled: etcFuzzy,
                        nonEtcEnabled: nonEtc,
                        onEtcFuzzyChanged: (val) async {
                          if (val) {
                            await svc.setIrrigationMode('ETC_FUZZY');
                          }
                        },
                        onNonEtcChanged: (val) async {
                          if (val) {
                            await svc.setIrrigationMode('NON_ETC');
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Water usage bar chart
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Grafik Penggunaan Air',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _legendDot(cs.primary, 'ETc+Fuzzy', theme),
                            const SizedBox(width: 8),
                            _legendDot(Colors.blueAccent, 'Non-ETc', theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: svc.irrigationHistoryStream,
                        builder: (ctx, snap) => WaterUsageBarChart(
                          data: snap.data ?? [],
                          height: 170,
                        ),
                      ),
                      const SizedBox(height: 12),

                      IrrigationInfoCard(
                        durationSeconds: duration,
                        volumeMl: volume,
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private irrigation mode card
// ---------------------------------------------------------------------------

class _IrrigationModeCard extends StatelessWidget {
  const _IrrigationModeCard({
    required this.etcFuzzyEnabled,
    required this.nonEtcEnabled,
    required this.onEtcFuzzyChanged,
    required this.onNonEtcChanged,
  });

  final bool etcFuzzyEnabled;
  final bool nonEtcEnabled;
  final ValueChanged<bool> onEtcFuzzyChanged;
  final ValueChanged<bool> onNonEtcChanged;

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
              'Mode Irigasi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _ModeRow(
              title: 'ETc + Fuzzy Logic Mode',
              subtitle: 'Irigasi berdasar ETc & Fuzzy Logic',
              value: etcFuzzyEnabled,
              onChanged: onEtcFuzzyChanged,
            ),
            Divider(color: cs.outlineVariant, height: 24),
            _ModeRow(
              title: 'Non ETc Mode',
              subtitle: 'Irigasi tanpa kalkulasi ETc',
              value: nonEtcEnabled,
              onChanged: onNonEtcChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
