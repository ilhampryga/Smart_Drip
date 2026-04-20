import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// Card for displaying and toggling the pump ON/OFF state.
/// Optionally pass [statusStream] to drive the UI from a live Firebase stream.
class PumpCard extends StatefulWidget {
  const PumpCard({
    super.key,
    this.initialValue = false,
    this.statusStream,
    this.onChanged,
  });

  final bool initialValue;
  final Stream<bool>? statusStream;
  final ValueChanged<bool>? onChanged;

  @override
  State<PumpCard> createState() => _PumpCardState();
}

class _PumpCardState extends State<PumpCard> {
  late bool _isOn;

  @override
  void initState() {
    super.initState();
    _isOn = widget.initialValue;
  }

  /// Show a yes/no confirmation dialog before toggling the pump.
  Future<bool> _confirm(bool newVal) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              newVal ? Icons.power_settings_new : Icons.power_off_outlined,
              color: newVal ? cs.primary : cs.error,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Konfirmasi Pompa'),
          ],
        ),
        content: Text(
          newVal
              ? 'Apakah Anda yakin ingin menyalakan pompa?'
              : 'Apakah Anda yakin ingin mematikan pompa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newVal ? cs.primary : cs.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _toggle(bool val) async {
    final yes = await _confirm(val);
    if (!yes) return;
    setState(() => _isOn = val);
    await FirebaseService.instance.setPumpStatus(val);
    widget.onChanged?.call(val);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget cardBody(bool isOn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Pompa',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isOn ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  Switch(value: isOn, onChanged: _toggle),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (widget.statusStream != null) {
      return StreamBuilder<bool>(
        stream: widget.statusStream,
        initialData: _isOn,
        builder: (context, snap) {
          final live = snap.data ?? _isOn;
          if (_isOn != live) {
            _isOn = live;
          }
          return cardBody(live);
        },
      );
    }

    return cardBody(_isOn);
  }
}
