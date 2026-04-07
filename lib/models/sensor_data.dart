class SensorData {
  final double temperature;
  final double soilMoisture;
  final String timestamp;

  const SensorData({
    required this.temperature,
    required this.soilMoisture,
    required this.timestamp,
  });

  factory SensorData.fromMap(Map<dynamic, dynamic> map) {
    return SensorData(
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (map['soil_moisture'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as String?) ?? '',
    );
  }
}
