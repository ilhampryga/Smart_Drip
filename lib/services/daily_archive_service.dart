import 'dart:async';
import 'firebase_service.dart';

/// Checks on startup (and optionally periodically) whether the date has
/// changed since the last archive run, and if so archives yesterday's data
/// to the Firebase `daily_log` paths.
///
/// Uses a simple in-memory marker — if the app is killed and restarted on a
/// new day, the archive still runs because `_lastArchivedDate` starts null.
class DailyArchiveService {
  DailyArchiveService._();
  static final DailyArchiveService instance = DailyArchiveService._();

  String? _lastArchivedDate;
  Timer? _midnightTimer;

  /// Call once from [DashboardScreen.initState] (or app init).
  /// Archives data for the *previous* day if not yet done today.
  Future<void> checkAndArchive() async {
    final today = _todayStr();
    if (_lastArchivedDate == today) return; // Already ran today

    // Archive yesterday's data
    final yesterday = _yesterdayStr();
    try {
      await FirebaseService.instance.archiveDailyData(yesterday);
      _lastArchivedDate = today;
    } catch (e) {
      // Silently fail — next app restart will try again
      // ignore: avoid_print
      print('[DailyArchiveService] Archive failed: $e');
    }

    // Schedule a timer for midnight so the archive also runs mid-session
    _scheduleMidnightTimer();
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, () async {
      await checkAndArchive();
    });
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayStr() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _midnightTimer?.cancel();
  }
}
