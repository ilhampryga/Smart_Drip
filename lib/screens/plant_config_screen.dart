import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';

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
  PlantPhase _selectedPhase = PlantPhase.awal;
  final TextEditingController _exactAgeCtrl = TextEditingController();
  double? _latitude;
  bool _gpsLoading = false;
  String? _gpsError;

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
              value: '${_selectedPhase.label} (${_selectedPhase.range})',
            ),
            if (_selectedPhase == PlantPhase.perkembangan &&
                _exactAgeCtrl.text.isNotEmpty)
              _ConfirmRow(label: 'Umur Pasti', value: '${_exactAgeCtrl.text} hari'),
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
    // Validate exact age for Perkembangan phase
    if (_selectedPhase == PlantPhase.perkembangan) {
      final val = int.tryParse(_exactAgeCtrl.text);
      if (val == null ||
          val < _selectedPhase.minAge ||
          val > _selectedPhase.maxAge) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Masukkan umur yang valid (31–70 hari) untuk Fase Perkembangan.',
            ),
          ),
        );
        return;
      }
    }

    final yes = await _showConfirmDialog();
    if (!yes) return;

    try {
      final age = _selectedPhase == PlantPhase.perkembangan
          ? int.tryParse(_exactAgeCtrl.text)
          : null;

      await FirebaseService.instance.savePlantConfig(
        phase: _selectedPhase.label,
        phaseRange: _selectedPhase.range,
        exactAge: age,
        latitude: _latitude,
      );

      if (mounted) {
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
              // ── Header card ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.eco_rounded,
                          color: cs.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Tanaman',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Atur fase tumbuh dan lokasi tanaman cabe Anda.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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

                      // Dropdown
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.outline),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PlantPhase>(
                            value: _selectedPhase,
                            isExpanded: true,
                            icon: Icon(Icons.expand_more,
                                color: cs.onSurfaceVariant),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurface),
                            items: PlantPhase.values.map((phase) {
                              return DropdownMenuItem<PlantPhase>(
                                value: phase,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(phase.label),
                                    Text(
                                      phase.range,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPhase = val;
                                  if (val != PlantPhase.perkembangan) {
                                    _exactAgeCtrl.clear();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      // Exact age input — only for Perkembangan
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _selectedPhase == PlantPhase.perkembangan
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Umur Pasti Tanaman (hari)',
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _exactAgeCtrl,
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
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Masukkan umur antara 31 dan 70 hari.',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
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
