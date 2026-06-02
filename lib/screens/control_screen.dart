import 'package:flutter/material.dart';
import '../widgets/irrigation_info_card.dart';
import '../services/firebase_service.dart';
import '../models/system_control.dart' show SystemControl;

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService.instance;
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
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: svc.irrigationTodayStream,
                        builder: (context, irrigSnap) {
                          final hasIrrigationToday =
                              (irrigSnap.data ?? []).isNotEmpty;
                          return _ScheduleCard(
                            isNoEtcFuzzy: ctrl != null && !ctrl.isEtcFuzzy,
                            hasIrrigationToday: hasIrrigationToday,
                          );
                        },
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
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({
    required this.isNoEtcFuzzy,
    required this.hasIrrigationToday,
  });

  /// True saat mode aktif adalah NO_FUZZY_ETC.
  /// Jika true, jadwal otomatis di-disable dan UI di-gray-out.
  final bool isNoEtcFuzzy;

  /// True jika sudah ada data irigasi yang tersimpan hari ini.
  /// Jika true, seluruh jadwal dikunci dan tidak dapat diubah.
  final bool hasIrrigationToday;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _disabling = false; // guard agar tidak loop

  Future<bool> _confirmAction(
    BuildContext context,
    String title,
    String content,
  ) async {
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

  /// Returns true if the given "HH:mm" time has already passed today.
  bool _isTimePassed(String timeStr) {
    final now = TimeOfDay.now();
    final parts = timeStr.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    if (now.hour > hour) return true;
    if (now.hour == hour && now.minute >= minute) return true;
    return false;
  }

  Future<void> _pickTime(
    BuildContext context,
    bool currentActive,
    List<String> currentTimes,
  ) async {
    // Batasi maksimal 2 jadwal
    if (currentTimes.length >= 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal sudah penuh! Maksimal 2 jadwal per hari.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    if (!context.mounted) return;

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final timeStr = '$hour:$minute';

      if (!currentTimes.contains(timeStr)) {
        final yes = await _confirmAction(
          context,
          'Simpan Jadwal',
          'Apakah Anda yakin ingin menambahkan jadwal penyiraman pada pukul $timeStr?',
        );
        if (yes) {
          final newTimes = List<String>.from(currentTimes)..add(timeStr);
          await FirebaseService.instance.saveIrrigationSchedule(
            currentActive,
            newTimes,
          );
        }
      }
    }
  }

  /// Jika mode NO_FUZZY_ETC aktif dan jadwal masih ON → paksa OFF ke Firebase.
  Future<void> _autoDisableIfNeeded(bool isActive, List<String> times) async {
    if (widget.isNoEtcFuzzy && isActive && !_disabling) {
      _disabling = true;
      await FirebaseService.instance.saveIrrigationSchedule(false, times);
      _disabling = false;
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

        // Jika mode NO_FUZZY_ETC, paksa is_active = false
        final rawIsActive = data['is_active'] as bool;
        final times = List<String>.from(data['times'] as List);

        // Auto-disable ke Firebase jika perlu (fire-and-forget, hanya sekali)
        _autoDisableIfNeeded(rawIsActive, times);

        // Nilai tampilan: selalu false saat NO_FUZZY_ETC
        final isActive = widget.isNoEtcFuzzy ? false : rawIsActive;

        // Cek apakah ada jadwal yang sudah terlewati hari ini
        final hasPassedTime = times.any(_isTimePassed);

        // Kunci seluruh kartu jika:
        // - Mode NO_FUZZY_ETC aktif, ATAU
        // - Ada data irigasi hari ini
        final isLocked = widget.isNoEtcFuzzy || widget.hasIrrigationToday;
        final isMaxReached = times.length >= 2;

        return Opacity(
          opacity: isLocked ? 0.45 : 1.0,
          child: Card(
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
                        // null = disabled (tidak bisa disentuh)
                        onChanged: isLocked
                            ? null
                            : (val) async {
                                final action = val
                                    ? 'mengaktifkan'
                                    : 'menonaktifkan';
                                final yes = await _confirmAction(
                                  context,
                                  'Konfirmasi Jadwal',
                                  'Apakah Anda yakin ingin $action jadwal otomatis?',
                                );
                                if (yes) {
                                  await svc.saveIrrigationSchedule(val, times);
                                }
                              },
                      ),
                    ],
                  ),

                  // Banner peringatan — urutan prioritas: irigasi hari ini > jadwal terlewati > NO_FUZZY_ETC
                  if (widget.hasIrrigationToday) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jadwal dikunci karena data irigasi sudah tersimpan hari ini.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.isNoEtcFuzzy) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: cs.onErrorContainer,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jadwal dinonaktifkan karena mode "No Fuzzy & ETc" aktif.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    'Atur jam penyiraman dinamis setiap harinya (maks. 2 jadwal).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ...times.map((t) {
                        // Semua chip dikunci setelah isLocked = true
                        return InputChip(
                          label: Text(
                            t,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          avatar: Icon(
                            _isTimePassed(t)
                                ? Icons.check_circle_outline
                                : Icons.access_time,
                            size: 16,
                            color: _isTimePassed(t)
                                ? cs.primary
                                : Colors.blueGrey,
                          ),
                          onDeleted: isLocked
                              ? null
                              : () async {
                                  final yes = await _confirmAction(
                                    context,
                                    'Hapus Jadwal',
                                    'Apakah Anda yakin ingin menghapus jadwal jam $t?',
                                  );
                                  if (yes) {
                                    final newTimes = List<String>.from(times)
                                      ..remove(t);
                                    await svc.saveIrrigationSchedule(
                                      isActive,
                                      newTimes,
                                    );
                                  }
                                },
                          deleteIconColor: cs.error,
                          backgroundColor: _isTimePassed(t)
                              ? cs.surfaceContainerHighest
                              : null,
                        );
                      }),
                      // Tombol tambah hanya muncul jika belum maks dan tidak dikunci
                      if (!isLocked && !isMaxReached)
                        ActionChip(
                          label: const Text('Tambah Waktu'),
                          avatar: const Icon(Icons.add, size: 16),
                          onPressed: () => _pickTime(context, isActive, times),
                          backgroundColor: cs.primaryContainer,
                          side: BorderSide.none,
                        ),
                      if (!isLocked && isMaxReached)
                        Chip(
                          label: const Text('Maks. 2 jadwal tercapai'),
                          avatar: Icon(
                            Icons.info_outline,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          backgroundColor: cs.surfaceContainerHighest,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
