import 'package:flutter/material.dart';

import '../services/bmkg_service.dart';

/// Card that displays BMKG weather forecast for the device's current location.
///
/// [latitude] is the plant-field latitude from Firebase (displayed as context).
/// Longitude is fetched internally by [BmkgService] but never shown to the user.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, this.latitude, this.longitude});

  /// Latitude of the plant field (from Firebase plant_config).
  /// Displayed as "Lat lahan: x.xxxx°" for quick reference.
  final double? latitude;
  
  /// Longitude of the plant field (used internally to find BMKG region).
  final double? longitude;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  late Future<WeatherData?> _future;

  @override
  void initState() {
    super.initState();
    _future = BmkgService.instance.fetchWeather(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika koordinat Firebase baru dimuat (sebelumnya null lalu menjadi ada nilainya)
    if (widget.latitude != oldWidget.latitude || widget.longitude != oldWidget.longitude) {
      if (widget.latitude != null && widget.longitude != null) {
        BmkgService.instance.clearCache(); // Force fetch data baru dengan koordinat baru
        setState(() {
          _future = BmkgService.instance.fetchWeather(widget.latitude, widget.longitude);
        });
      }
    }
  }

  void _refresh() {
    BmkgService.instance.clearCache();
    setState(() {
      _future = BmkgService.instance.fetchWeather(widget.latitude, widget.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData?>(
      future: _future,
      builder: (context, snap) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        if (snap.connectionState == ConnectionState.waiting) {
          return _LoadingCard(theme: theme, cs: cs);
        }
        if (snap.hasError || !snap.hasData || snap.data == null) {
          return _ErrorCard(theme: theme, cs: cs, onRetry: _refresh);
        }
        return _WeatherContent(
          theme: theme,
          cs: cs,
          data: snap.data!,
          latitude: widget.latitude,
          onRefresh: _refresh,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading state
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.theme, required this.cs});
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _GradientHeader(
            child: Row(
              children: [
                const Icon(Icons.wb_cloudy_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Prakiraan Cuaca',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Menentukan lokasi & memuat cuaca…',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                  color: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(
      {required this.theme, required this.cs, required this.onRetry});
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _GradientHeader(
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Prakiraan Cuaca',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.signal_wifi_bad_outlined,
                    size: 36, color: cs.error.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data cuaca tidak tersedia',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pastikan titik GPS telah disetting di Konfigurasi Tanaman.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh_rounded, color: cs.primary),
                  tooltip: 'Coba lagi',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main weather content
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({
    required this.theme,
    required this.cs,
    required this.data,
    required this.latitude,
    required this.onRefresh,
  });

  final ThemeData theme;
  final ColorScheme cs;
  final WeatherData data;
  final double? latitude;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (data.hourly.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2E3B5C), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Prakiraan Per Jam (Hari Ini)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E3B5C),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: onRefresh,
              child: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Horizontal list of hours
        SizedBox(
          height: 200, // Reduced height since wind and humidity are removed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.hourly.length,
            itemBuilder: (context, index) {
              final h = data.hourly[index];
              return _HourlyTile(hourly: h);
            },
          ),
        ),
        
        // BMKG Attribution (kept for credit)
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 11, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Sumber data cuaca: Open-Meteo',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.hourly});
  
  final HourlyWeather hourly;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140, // Lebar card
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), // Reduced vertical padding
      decoration: BoxDecoration(
        color: const Color(0xFF334155), // Dark slate blue
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hourly.time,
            style: const TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _weatherEmoji(hourly.weatherCode), 
            style: const TextStyle(fontSize: 38),
          ),
          const SizedBox(height: 6),
          Text(
            '${hourly.temperature} °C',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 22, 
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                hourly.description.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getWindAngle(String dir) {
    // Rough estimate of wind direction icon angle
    switch (dir) {
      case 'U': return 0;
      case 'TL': return 0.785; // 45 deg in rad
      case 'T': return 1.57; // 90 deg
      case 'TG': return 2.356;
      case 'S': return 3.14;
      case 'BD': return 3.926;
      case 'B': return 4.71;
      case 'BL': return 5.497;
      default: return 0;
    }
  }

  /// Maps WMO weather interpretation code → emoji icon.
  /// Reference: https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  String _weatherEmoji(int code) {
    switch (code) {
      // Clear sky
      case 0:  return '☀️';   // Cerah

      // Mostly / Partly clear → Partly cloudy
      case 1:  return '🌤️';  // Sebagian cerah
      case 2:  return '⛅';   // Cerah berawan

      // Overcast
      case 3:  return '☁️';   // Mendung / berawan penuh

      // Fog
      case 45:
      case 48: return '🌫️';  // Berkabut

      // Drizzle (light → dense)
      case 51:
      case 53:
      case 55: return '🌦️';  // Gerimis

      // Freezing drizzle (treat same as drizzle in tropical context)
      case 56:
      case 57: return '🌦️';  // Gerimis beku

      // Rain: slight / moderate / heavy
      case 61: return '🌧️';  // Hujan ringan
      case 63: return '🌧️';  // Hujan sedang
      case 65: return '🌧️';  // Hujan lebat

      // Freezing rain
      case 66:
      case 67: return '🌧️';  // Hujan dingin

      // Rain showers: slight / moderate / heavy
      case 80: return '🌦️';  // Hujan lokal ringan
      case 81: return '🌧️';  // Hujan lokal sedang
      case 82: return '🌧️';  // Hujan lokal lebat

      // Snow / sleet (rare in Indonesia, show cloud)
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86: return '🌨️';  // Salju / es

      // Thunderstorm: slight / moderate / with heavy hail
      case 95: return '⛈️';   // Badai petir
      case 96:
      case 99: return '⛈️';   // Badai petir + hujan es

      default: return '🌤️';  // Fallback
    }
  }
}

/// Gradient banner used as card header for Loading and Error states.
class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.child, this.trailing});

  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            const Color(0xFF0097A7), // teal accent
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ignore_for_file: unused_element, unused_element_parameter

