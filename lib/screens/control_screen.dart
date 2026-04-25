import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Kontrol')),
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
                            await svc.setIrrigationMode('NO_FUZZY_ETC');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const _ScheduleCard(),
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
}

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

  Future<bool> _confirmModeChange(BuildContext context, String modeName) async {

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Ganti Mode'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin mengubah mode irigasi ke "$modeName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

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
              title: 'ETc + Fuzzy',
              subtitle: 'Irigasi berdasar ETc & Fuzzy Logic',
              value: etcFuzzyEnabled,
              onChanged: (val) async {
                if (!val) return; // only allow turning ON (exclusive mode)
                final yes = await _confirmModeChange(
                    context, 'ETc + Fuzzy');
                if (yes) onEtcFuzzyChanged(val);
              },
            ),
            Divider(color: cs.outlineVariant, height: 24),
            _ModeRow(
              title: 'No Fuzzy dan ETc',
              subtitle: 'Irigasi tanpa Fuzzy dan ETc',
              value: nonEtcEnabled,
              onChanged: (val) async {
                if (!val) return;
                final yes =
                    await _confirmModeChange(context, 'No Fuzzy dan ETc');
                if (yes) onNonEtcChanged(val);
              },
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  Future<bool> _confirmAction(BuildContext context, String title, String content) async {
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: cs.primary, size: 26),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _pickTime(BuildContext context, bool currentActive, List<String> currentTimes) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final timeStr = '$hour:$minute';
      
      if (!currentTimes.contains(timeStr)) {
        final yes = await _confirmAction(context, 'Simpan Jadwal', 'Apakah Anda yakin ingin menambahkan jadwal penyiraman pada pukul $timeStr?');
        if (yes) {
          final newTimes = List<String>.from(currentTimes)..add(timeStr);
          await FirebaseService.instance.saveIrrigationSchedule(currentActive, newTimes);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final svc = FirebaseService.instance;

    return StreamBuilder<Map<String, dynamic>>(
      stream: svc.irrigationScheduleStream,
      builder: (context, snap) {
        final data = snap.data ?? {'is_active': false, 'times': <String>[]};
        final isActive = data['is_active'] as bool;
        final times = List<String>.from(data['times'] as List);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jadwal Otomatis',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (val) async {
                        final action = val ? 'mengaktifkan' : 'menonaktifkan';
                        final yes = await _confirmAction(context, 'Konfirmasi Jadwal', 'Apakah Anda yakin ingin $action jadwal otomatis?');
                        if (yes) {
                          await svc.saveIrrigationSchedule(val, times);
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  'Atur jam penyiraman dinamis setiap harinya.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ...times.map(
                      (t) => InputChip(
                        label: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                        avatar: const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                        onDeleted: () async {
                          final yes = await _confirmAction(context, 'Hapus Jadwal', 'Apakah Anda yakin ingin menghapus jadwal jam $t?');
                          if (yes) {
                            final newTimes = List<String>.from(times)..remove(t);
                            await svc.saveIrrigationSchedule(isActive, newTimes);
                          }
                        },
                        deleteIconColor: cs.error,
                      ),
                    ),
                    ActionChip(
                      label: const Text('Tambah Waktu'),
                      avatar: const Icon(Icons.add, size: 16),
                      onPressed: () => _pickTime(context, isActive, times),
                      backgroundColor: cs.primaryContainer,
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// ignore_for_file: use_build_context_synchronously
