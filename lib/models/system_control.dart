class SystemControl {
  final String mode; // e.g. "ETC_FUZZY" | "NO_FUZZY_ETC"
  final bool pumpStatus; // true (ON) | false (OFF)
  final double flowRateMlPerSec;

  const SystemControl({
    required this.mode,
    required this.pumpStatus,
    required this.flowRateMlPerSec,
  });

  bool get isPumpOn => pumpStatus;
  bool get isEtcFuzzy => mode == 'ETC_FUZZY';

  factory SystemControl.fromMap(Map<dynamic, dynamic> map) {
    return SystemControl(
      mode: (map['mode'] as String?) ?? 'ETC_FUZZY',
      pumpStatus: (map['pump_status'] as bool?) ?? false,
      flowRateMlPerSec:
          (map['flow_rate_ml_per_sec'] as num?)?.toDouble() ?? 20.0,
    );
  }
}
