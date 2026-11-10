import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/db.dart';
import '../data/prayer_notifications.dart';
import '../data/rtdb.dart';
import '../data/home_widgets.dart';
import '../main.dart' show kNavigatorKey;
import 'main_screen.dart';
import 'misc/zikr_detail_screen.dart';

/// Original: SplashActivity — initializes services, shows the admin
/// announcement dialog from Firebase "dialogg/dialog" (once per version),
/// then opens MainActivity.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Item 18: the splash shows ONLY the logo + progress + one fixed line
  /// ("ڕێکخستن...") — no changing status texts, no pickers, nothing else
  /// for the user to read or touch while the app prepares itself.
  static const String _status = 'ڕێکخستن...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Db.I.init();
    } catch (_) {}
    // Item "bang danesh esh nakat": EVERY step is guarded on its own so one
    // failure (e.g. the permission dialog being dismissed, or a network
    // hiccup) can never skip the scheduling of the بانگ alarms.
    try {
      await PrayerNotifications.I.init();
    } catch (_) {}
    try {
      await PrayerNotifications.warmUp(); // find downloaded adhan voices
    } catch (_) {}
    try {
      await PrayerNotifications.I.requestPermission();
    } catch (_) {}
    try {
      await PrayerNotifications.I.scheduleAll();
    } catch (_) {}
    try {
      await HomeWidgets.updatePrayer();
    } catch (_) {}
    // Item 5: the Quran widget always carries one fresh ayah of the day.
    try {
      await HomeWidgets.pushDailyAyah();
    } catch (_) {}
    _checkAdminNotification();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Item 5-d: "continue where I left off" — reopen the same screen the
    // user was on (a zikr detail, or a bottom tab) when the pref is on.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final last = AppPrefs.I.lastRoute;
    final tab = last.startsWith('tab::')
        ? (int.tryParse(last.substring(4)) ?? 0)
        : -1;
    final resume = AppPrefs.I.resumeWhereLeftOff && last.isNotEmpty;
    if (resume && last.startsWith('zikr::')) {
      // The zikr content (name/zkr/vip) is persisted in AppPrefs, so pushing
      // the detail on top of MainScreen restores exactly that zikr.
      nav.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()));
      nav.push(MaterialPageRoute(builder: (_) => const ZikrDetailScreen()));
      _resumeSnack(messenger);
    } else if (resume && tab >= 0) {
      // MainScreen clamps initialTab into the valid tab range.
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => MainScreen(initialTab: tab)));
      _resumeSnack(messenger);
    } else {
      nav.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()));
    }
    _maybeShowDialog().whenComplete(_maybeExactAlarmGuide);
  }

  /// Item 2 fallback — بانگ must never fail silently: if the exact-alarm
  /// permission (Android 12+ "Alarms & reminders") is denied, OEM phones
  /// drop or delay the inexact alarms while the device sleeps and the user
  /// never hears the adhan. Show a dialog guiding them to the system page.
  Future<void> _maybeExactAlarmGuide() async {
    if (!PrayerNotifications.isAndroidDevice) return;
    try {
      // Give the admin announcement dialog (if any) time to appear first.
      await Future.delayed(const Duration(milliseconds: 600));
      final ctx = kNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      if (await PrayerNotifications.I.canScheduleExact()) return;
      if (!ctx.mounted) return;
      await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ئاگادارکردنەوەی بانگ کارا نییە',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            content: const Text(
                'ڕێگەی Exact Alarm نەدرا — بڕۆ ناو ڕێکخستنەکانی مۆبایل و بەخشبێ بە "ئاگادارکردنەوە و وردی زانیاری" بۆ ئەپەکە، تا بانگی نوێژ لە کاتی خۆیدا بە دەنگ بگرێت 🔔',
                style: TextStyle(fontSize: 13.5, height: 1.8)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('دواتر',
                      style: TextStyle(color: AppColors.primaryDark))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(c);
                    final granted = await PrayerNotifications.I
                        .requestExactAlarmPermission();
                    await PrayerNotifications.I.scheduleAll();
                    final ctx2 = kNavigatorKey.currentContext;
                    if (!granted && ctx2 != null && ctx2.mounted) {
                      ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(
                          content: Text(
                              'ڕێگەی Exact Alarm هێشتا نەدرا — بانگ بە شێوەی ئاسایی دادەنرێت')));
                    }
                  },
                  child: const Text('کردنەوەی ڕێکخستنی مۆبایل')),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  /// Item 5-d: short confirmation on the restored screen (2s).
  void _resumeSnack(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(const SnackBar(
        content: Text('گەڕایەوە بۆ دوایین شوێن — بەردەوام بە'),
        duration: Duration(seconds: 2)));
  }

  /// Item 22: the admin panel writes {title, text, date, open} to the
  /// "notification" node; new messages arrive as a real system
  /// notification (no FCM key needed — the app polls on start).
  Future<void> _checkAdminNotification() async {
    try {
      final rows = await Rtdb.I.list('notification');
      if (rows.isEmpty || !mounted) return;
      final n = rows.last;
      if ('${n['open'] ?? ''}'.toLowerCase() == 'false') return;
      final title = '${n['title'] ?? ''}'.trim();
      final text = '${n['text'] ?? ''}'.trim();
      if (title.isEmpty && text.isEmpty) return;
      final stamp = '${n['date'] ?? ''}|$title'.trim();
      if (stamp.isNotEmpty && AppPrefs.I.notifSeen == stamp) return;
      await PrayerNotifications.I.showNow(
          title.isEmpty ? 'ڕێگای ئیسلام' : title,
          text.isEmpty ? 'پەیامێکی نوێ هەیە' : text);
      AppPrefs.I.notifSeen = stamp;
    } catch (_) {}
  }

  /// dialogg/dialog = {open, only, title, text, url, close, ver, random}.
  /// Shown once per unique ver/random so it doesn't nag on every start.
  Future<void> _maybeShowDialog() async {
    try {
      final rows = await Rtdb.I.dialogg();
      if (rows.isEmpty) return;
      final d = rows.first;
      if ('${d['open'] ?? ''}'.toLowerCase() == 'false') return;
      final title = '${d['title'] ?? ''}'.trim();
      final text = '${d['text'] ?? ''}'.trim();
      if (title.isEmpty && text.isEmpty) return;
      final stamp =
          '${d['ver'] ?? ''}|${d['random'] ?? ''}|$title'.hashCode.toString();
      if (AppPrefs.I.dialogSeen == stamp) return;
      final url = '${d['url'] ?? ''}'.trim();
      final closeLabel = '${d['close'] ?? ''}'.trim().isEmpty
          ? 'داخستن'
          : '${d['close']}'.trim();
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title.isEmpty ? 'ئاگادارکردنەوە' : title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(text,
                    style: const TextStyle(fontSize: 13.5, height: 1.8)),
              ),
            ),
            actions: [
              if (url.startsWith('http'))
                TextButton(
                    onPressed: () => launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication),
                    child: const Text('کردنەوەی لینک',
                        style: TextStyle(color: AppColors.primaryDark))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(c),
                  child: Text(closeLabel)),
            ],
          ),
        ),
      );
      AppPrefs.I.dialogSeen = stamp;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Scaffold(
      backgroundColor: dark ? AppColors.nightBg : Colors.white,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/app_icon.png', width: 120, height: 120,
                errorBuilder: (_, __, ___) => const Icon(Icons.mosque,
                    size: 110, color: AppColors.primaryDark)),
            const SizedBox(height: 18),
            Text('ڕێگای ئیسلام',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black)),
            const SizedBox(height: 26),
            SizedBox(
                width: 26, height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: dark ? AppColors.gold : AppColors.primaryDark)),
            const SizedBox(height: 12),
            Text(_status,
                style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white70 : Colors.black54)),
          ]),
        ),
      ),
    );
  }
}
