import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../core/ui.dart' show AudioSetup;
import '../main.dart' show kNavigatorKey;
import 'db.dart';
import 'prayer_notifications.dart';

/// item 9 — "بانگ دانەشێ ئەش نەکات ... دووبارە تەکایە مەزبوتە بکە!!!
/// بە شێوەی notification یان activity ئێستا کاتی نوێژە"
///
/// The scheduled AlarmManager notifications (7-day horizon) cover the app
/// CLOSED. But while the app is OPEN many OEMs delay or silence the
/// notification sound — and the user was sitting in the app when the
/// prayer time came and heard NOTHING.
///
/// BangWatcher closes that gap: every 20 seconds while the app is in the
/// FOREGROUND it checks today's prayer times (with the per-prayer offset)
/// and the moment a prayer time arrives it
///   1. plays the adhan DIRECTLY through the audio player (downloaded
///      voice file → bundled asset sound), full alarm-style volume,
///   2. vibrates,
///   3. raises an in-app "activity"-style full dialog
///      "ئێستا کاتی بانگی … ـە" with a stop button,
///   4. cancels today's scheduled notification for that prayer so the
///      adhan never plays twice (notification keeps covering the
///      background case).
///
/// A per-day+prayer guard in prefs makes it fire exactly once per prayer.
class BangWatcher {
  BangWatcher._();
  static final BangWatcher I = BangWatcher._();

  Timer? _timer;
  bool _checking = false;
  bool _prepared = false;
  DateTime? _dayCache;
  String? _cityCache;
  Map<String, String>? _timesCache;
  final AudioPlayer _player = AudioPlayer();

  static const _windowMs = 45000; // fire inside 45s after the prayer time
  static const _prayers = [
    ('bayani', 'notifFajr', 'بانگی بەیانی'),
    ('niwaro', 'notifDhuhr', 'بانگی نیوەڕۆ'),
    ('asr', 'notifAsr', 'بانگی عەسر'),
    ('eywara', 'notifMaghrib', 'بانگی ئێوارە'),
    ('esha', 'notifIsha', 'بانگی خەوتنان'),
  ];

  /// Start watching — called when MainScreen opens; the timer only runs
  /// while the Flutter engine is alive (foreground), which is exactly the
  /// gap the scheduled notifications cannot reliably cover.
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    try { _player.stop(); } catch (_) {}
  }

  Future<void> _tick() async {
    if (_checking) return;
    _checking = true;
    try {
      final p = AppPrefs.I;
      final now = DateTime.now();
      // refresh the (day, city) prayer-time cache
      if (_timesCache == null ||
          _dayCache != DateTime(now.year, now.month, now.day) ||
          _cityCache != p.cityId) {
        _timesCache = await Db.I.prayerTimes(p.cityId, now);
        _dayCache = DateTime(now.year, now.month, now.day);
        _cityCache = p.cityId;
      }
      final row = _timesCache;
      if (row == null) return;
      final dayKey =
          '${now.year}-${now.month}-${now.day}';
      for (var i = 0; i < _prayers.length; i++) {
        final (key, switchGetter, label) = _prayers[i];
        final enabled = switch (switchGetter) {
          'notifFajr' => p.notifFajr,
          'notifDhuhr' => p.notifDhuhr,
          'notifAsr' => p.notifAsr,
          'notifMaghrib' => p.notifMaghrib,
          _ => p.notifIsha,
        };
        if (!enabled) continue;
        final t = row[key];
        if (t == null || t.isEmpty) continue;
        final parts = t.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        final at = DateTime(now.year, now.month, now.day, h, m)
            .add(Duration(minutes: p.adhanOffset(key)));
        final diff = now.difference(at).inMilliseconds;
        if (diff < 0 || diff > _windowMs) continue;
        final guard = '$dayKey|$key';
        if (AppPrefs.I.bangFired == guard) continue;
        AppPrefs.I.bangFired = guard;
        await _fire(i, label);
      }
    } catch (_) {
      // never crash the app from the watcher
    } finally {
      _checking = false;
    }
  }

  /// Play + vibrate + in-app alert, and drop today's duplicate notification.
  Future<void> _fire(int index, String label) async {
    // 1) the sound — downloaded voice → bundled asset
    try {
      if (!_prepared) {
        await AudioSetup.prepare(_player);
        _prepared = true;
      }
      await _player.stop();
      final vf = PrayerNotifications.downloadedVoiceFile();
      if (vf != null && vf.existsSync() && vf.lengthSync() > 0) {
        await _player.play(DeviceFileSource(vf.path));
      } else {
        await _player.play(AssetSource('sounds/dang.MP3'));
      }
    } catch (_) {}
    // 2) vibration pattern like an alarm
    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(pattern: [0, 900, 350, 900, 350, 900]);
      }
    } catch (_) {}
    // 3) the in-app "activity" — an uncancellable full-screen-style dialog
    _showBangDialog(label);
    // 4) today's scheduled notification for this prayer would double the
    //    sound — cancel it (the other days' alarms stay untouched).
    try {
      await PrayerNotifications.I.cancelTodayBang(index);
    } catch (_) {}
  }

  void _showBangDialog(String label) {
    final ctx = kNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primaryDark.withOpacity(.85),
                    ])),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.notifications_active_rounded,
                  size: 52, color: AppColors.gold),
              const SizedBox(height: 12),
              const Text('ئێستا کاتی بانگە',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('لە ${AppPrefs.I.cityName} — ڕێگای ئیسلام',
                  style: TextStyle(
                      color: Colors.white.withOpacity(.75), fontSize: 12)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    try { _player.stop(); } catch (_) {}
                    try { Vibration.cancel(); } catch (_) {}
                    Navigator.of(c).pop();
                  },
                  icon: const Icon(Icons.stop_circle_rounded),
                  label: const Text('وەستاندنی بانگ',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ).then((_) {
      // dialog closed (or the route changed) — stop any lingering sound
      try { _player.stop(); } catch (_) {}
      try { Vibration.cancel(); } catch (_) {}
    });
  }
}


