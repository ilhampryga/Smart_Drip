import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../widgets/plant_phase_chart.dart';

/// Possible plant growth phases.
enum PlantPhase {
  awal('Fase Awal', '0–30 Hari', 0, 30),
  perkembangan('Fase Perkembangan', '31–70 Hari', 31, 70),
  tengah('Fase Tengah', '71–180 Hari', 71, 180),
  akhir('Fase Akhir', '181–210 Hari', 181, 210);

  const PlantPhase(this.label, this.range, this.minAge, this.maxAge);
  final String label;
  final String range;
  final int minAge;
  final int maxAge;
}

class PlantConfigScreen extends StatefulWidget {
  const PlantConfigScreen({super.key});

  @override
  State<PlantConfigScreen> createState() => _PlantConfigScreenState();
}

class _PlantConfigScreenState extends State<PlantConfigScreen> {
  final TextEditingController _exactAgeCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _gpsLoading = false;
  String? _gpsError;
  bool _isEditingAge = false;

  int? get _hst => int.tryParse(_exactAgeCtrl.text);

  PlantPhase get _derivedPhase {
    final hst = _hst ?? 0;
    if (hst <= 30) return PlantPhase.awal;
    if (hst <= 70) return PlantPhase.perkembangan;
    if (hst <= 180) return PlantPhase.tengah;
    return PlantPhase.akhir;
  }

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
    _exactAgeCtrl.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadExistingConfig() async {
    try {
      final stream = FirebaseService.instance.plantConfigStream;
      final map = await stream.first;
      if (map.isNotEmpty && mounted) {
        setState(() {
          if (map['latitude'] != null) {
            _latitude = (map['latitude'] as num).toDouble();
          }
          if (map['longitude'] != null) {
            _longitude = (map['longitude'] as num).toDouble();
          }
          if (map['exact_age_days'] != null) {
            final savedAge = (map['exact_age_days'] as num).toInt();
            _exactAgeCtrl.text = savedAge.toString();

            if (map['updated_at'] != null) {
              _checkAutoIncrement(savedAge, map['updated_at'].toString());
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAutoIncrement(int savedAge, String updatedAtStr) async {
    try {
      final updatedAt = DateTime.parse(updatedAtStr);
      final now = DateTime.now();
      final updatedDate = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
      final nowDate = DateTime(now.year, now.month, now.day);
      final diff = nowDate.difference(updatedDate).inDays;

      if (diff > 0) {
        final newAge = savedAge + diff;
        if (mounted) {
          setState(() {
            _exactAgeCtrl.text = newAge.toString();
          });
          // Silent auto-save to ensure database is in sync with displayed age
          await FirebaseService.instance.savePlantConfig(
            phase: _derivedPhase.label,
            phaseRange: _derivedPhase.range,
            exactAge: newAge,
            latitude: _latitude,
            longitude: _longitude,
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _exactAgeCtrl.dispose();
    super.dispose();
  }

  // ── GPS ─────────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });

    try {
      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _gpsError = 'Izin lokasi ditolak. Aktifkan di pengaturan.';
          _gpsLoading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _gpsLoading = false;
      });
    } catch (e) {
      setState(() {
        _gpsError = 'Gagal mendapatkan lokasi: $e';
        _gpsLoading = false;
      });
    }
  }

  // ── Confirmation dialog ──────────────────────────────────────────────────

  Future<bool> _showConfirmDialog() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: cs.primary, size: 26),
            const SizedBox(width: 10),
            const Text('Konfirmasi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menyimpan konfigurasi tanaman berikut?'),
            const SizedBox(height: 12),
            _ConfirmRow(
              label: 'Fase',
              value: '${_derivedPhase.label} (${_derivedPhase.range})',
            ),
            if (_exactAgeCtrl.text.isNotEmpty)
              _ConfirmRow(label: 'Umur Pasti', value: '${_exactAgeCtrl.text} hari (HST)'),
            if (_latitude != null)
              _ConfirmRow(
                label: 'Latitude',
                value: _latitude!.toStringAsFixed(6),
              ),
          ],
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

  // ── Save to Firebase ─────────────────────────────────────────────────────

  Future<void> _onConfirm() async {
    if (_hst == null || _hst! < 0 || _hst! > 210) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan umur yang valid (0–210 hari).'),
        ),
      );
      return;
    }

    final yes = await _showConfirmDialog();
    if (!yes) return;

    try {
      await FirebaseService.instance.savePlantConfig(
        phase: _derivedPhase.label,
        phaseRange: _derivedPhase.range,
        exactAge: _hst,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (mounted) {
        setState(() {
          _isEditingAge = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfigurasi berhasil disimpan!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfigurasi Tanaman')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Plant phase card ──────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_florist_outlined,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Fase Pertumbuhan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih fase pertumbuhan tanaman saat ini.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Exact age input
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Umur Tanaman (HST)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!_isEditingAge)
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isEditingAge = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _exactAgeCtrl,
                              readOnly: !_isEditingAge,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Contoh: 45',
                                hintStyle: TextStyle(
                                    color: cs.onSurfaceVariant),
                                suffixText: 'hari',
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: _isEditingAge 
                                    ? Colors.white 
                                    : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fase otomatis: ${_derivedPhase.label}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      PlantPhaseChart(currentHst: _hst),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── GPS location card ────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Lokasi Kebun',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dapatkan koordinat latitude lokasi penanaman.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Latitude display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.my_location,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Latitude',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _latitude != null
                                        ? _latitude!.toStringAsFixed(6)
                                        : '—',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _latitude != null
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_gpsError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _gpsError!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Get location button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _gpsLoading ? null : _fetchLocation,
                          icon: _gpsLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : const Icon(Icons.gps_fixed),
                          label: Text(
                            _gpsLoading ? 'Mendapatkan lokasi...' : 'Dapatkan Lokasi GPS',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Confirm button ───────────────────────────────────────────
              FilledButton.icon(
                onPressed: _onConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Simpan Konfigurasi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper confirmation row ─────────────────────────────────────────────────

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
