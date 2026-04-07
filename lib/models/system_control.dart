class SystemControl {
  final String mode; // e.g. "ETC_FUZZY" | "NON_ETC"
  final String pumpStatus; // "ON" | "OFF"
  final double flowRateMlPerSec;

  const SystemControl({
    required this.mode,
    required this.pumpStatus,
    required this.flowRateMlPerSec,
  });

  bool get isPumpOn => pumpStatus == 'ON';
  bool get isEtcFuzzy => mode == 'ETC_FUZZY';

  factory SystemControl.fromMap(Map<dynamic, dynamic> map) {
    return SystemControl(
      mode: (map['mode'] as String?) ?? 'ETC_FUZZY',
      pumpStatus: (map['pump_status'] as String?) ?? 'OFF',
      flowRateMlPerSec:
          (map['flow_rate_ml_per_sec'] as num?)?.toDouble() ?? 20.0,
    );
  }
}
