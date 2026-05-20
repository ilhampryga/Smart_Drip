import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.description,
    required this.windSpeed,
    required this.windDir,
  });

  final String time; // "19:00 WIB"
  final int temperature; // °C
  final int humidity; // %
  final int weatherCode;
  final String description;
  final double windSpeed; // km/h
  final String windDir; // SW
}

class WeatherData {
  const WeatherData({
    required this.locationName,
    required this.hourly,
  });

  final String locationName;
  final List<HourlyWeather> hourly;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class BmkgService {
  BmkgService._();
  static final BmkgService instance = BmkgService._();

  static const _base = 'https://api.bmkg.go.id/publik';
  static const _ttl = Duration(minutes: 30);

  static Future<http.Response> _httpGet(String path) {
    var urlStr = '$_base$path';
    if (kIsWeb) {
      urlStr = 'https://corsproxy.io/?' + Uri.encodeComponent(urlStr);
    }
    return http.get(
      Uri.parse(urlStr),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    );
  }

  WeatherData? _cache;
  DateTime? _cacheAt;

  // Static approximate center coordinates per province (adm1 code → (lat, lon))
  // Used as fallback when the BMKG wilayah API does not include coordinates.
  static const Map<String, (double, double)> _provinceCenters = {
    '11': (-4.69, 96.74), // Aceh
    '12': (2.12, 99.27), // Sumatera Utara
    '13': (-0.62, 101.35), // Sumatera Barat
    '14': (0.29, 101.70), // Riau
    '15': (-1.61, 103.61), // Jambi
    '16': (-4.00, 103.75), // Sumatera Selatan
    '17': (-3.79, 102.26), // Bengkulu
    '18': (-4.56, 105.40), // Lampung
    '19': (-2.09, 106.16), // Kep. Bangka Belitung
    '21': (0.90, 104.44), // Kep. Riau
    '31': (-6.21, 106.85), // DKI Jakarta
    '32': (-7.09, 107.67), // Jawa Barat
    '33': (-7.15, 110.14), // Jawa Tengah
    '34': (-7.80, 110.36), // DI Yogyakarta
    '35': (-7.54, 112.24), // Jawa Timur
    '36': (-6.40, 106.15), // Banten
    '51': (-8.34, 115.09), // Bali
    '52': (-8.65, 117.36), // NTB
    '53': (-8.66, 121.08), // NTT
    '61': (-0.02, 109.33), // Kalimantan Barat
    '62': (-1.68, 113.38), // Kalimantan Tengah
    '63': (-3.09, 115.72), // Kalimantan Selatan
    '64': (0.54, 116.42), // Kalimantan Timur
    '65': (3.07, 116.04), // Kalimantan Utara
    '71': (1.49, 124.84), // Sulawesi Utara
    '72': (-0.90, 121.39), // Sulawesi Tengah
    '73': (-5.14, 119.42), // Sulawesi Selatan
    '74': (-4.14, 122.17), // Sulawesi Tenggara
    '75': (0.54, 123.06), // Gorontalo
    '76': (-2.44, 119.42), // Sulawesi Barat
    '81': (-3.24, 130.19), // Maluku
    '82': (0.84, 127.39), // Maluku Utara
    '91': (-4.27, 138.08), // Papua Barat
    '92': (-2.53, 140.72), // Papua
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches the current weather for the provided coordinates using Open-Meteo.
  /// (Server API Wilayah BMKG saat ini sedang returning 404 Not Found, 
  /// jadi fallback ke Open-Meteo yang langsung mensupport Lat/Lon).
  Future<WeatherData?> fetchWeather(double? lat, double? lon) async {
    if (_isCacheValid()) return _cache;
    if (lat == null || lon == null) return null;

    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m&timezone=Asia%2FJakarta&forecast_days=2';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hourlyObj = data['hourly'] as Map<String, dynamic>?;
      if (hourlyObj == null) return null;

      final times = hourlyObj['time'] as List;
      final temps = hourlyObj['temperature_2m'] as List;
      final hums = hourlyObj['relative_humidity_2m'] as List;
      final codes = hourlyObj['weather_code'] as List;
      final winds = hourlyObj['wind_speed_10m'] as List;
      final dirs = hourlyObj['wind_direction_10m'] as List;

      final now = DateTime.now();
      final List<HourlyWeather> hourlyList = [];

      // Collect ALL 24 hours of today (filtering for display is done at widget level).
      for (int i = 0; i < times.length; i++) {
        final tStr = times[i] as String;
        final t = DateTime.parse(tStr);
        if (t.day == now.day) {
          hourlyList.add(HourlyWeather(
            time: '${t.hour.toString().padLeft(2, '0')}:00 WIB',
            temperature: (temps[i] as num).toInt(),
            humidity: (hums[i] as num).toInt(),
            weatherCode: (codes[i] as num).toInt(),
            description: instance._translateWMO((codes[i] as num).toInt()),
            windSpeed: (winds[i] as num).toDouble(),
            windDir: instance._getWindDirection((dirs[i] as num).toInt()),
          ));
        }
      }

      if (hourlyList.isEmpty) return null;

      final weather = WeatherData(
        locationName: 'Lahan Petani',
        hourly: hourlyList,
      );

      _cache = weather;
      _cacheAt = DateTime.now();
      return weather;
    } catch (_) {
      return null;
    }
  }

  /// Clears the cache so the next [fetchWeather] call hits the network.
  void clearCache() {
    _cache = null;
    _cacheAt = null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isCacheValid() =>
      _cache != null &&
      _cacheAt != null &&
      DateTime.now().difference(_cacheAt!) < _ttl;

  String _translateWMO(int code) {
    switch (code) {
      case 0: return 'Cerah';
      case 1:
      case 2:
      case 3: return 'Berawan';
      case 45:
      case 48: return 'Berkabut';
      case 51:
      case 53:
      case 55: return 'Gerimis';
      case 61: return 'Hujan Ringan';
      case 63: return 'Hujan Sedang';
      case 65: return 'Hujan Lebat';
      case 80:
      case 81:
      case 82: return 'Hujan Basah';
      case 95:
      case 96:
      case 99: return 'Badai Petir';
      default: return 'Cerah Berawan';
    }
  }

  String _getWindDirection(int degree) {
    if (degree >= 337 || degree < 22) return 'U';
    if (degree >= 22 && degree < 67) return 'TL';
    if (degree >= 67 && degree < 112) return 'T';
    if (degree >= 112 && degree < 157) return 'TG';
    if (degree >= 157 && degree < 202) return 'S';
    if (degree >= 202 && degree < 247) return 'BD';
    if (degree >= 247 && degree < 292) return 'B';
    if (degree >= 292 && degree < 337) return 'BL';
    return '–';
  }
}
// ignore_for_file: unused_import, unused_element, unused_field, prefer_interpolation_to_compose_strings
