import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/db.dart';
import '../data/prayer_notifications.dart';
import '../data/rtdb.dart';
import '../data/home_widgets.dart';
import 'main_screen.dart';

/// Original: SplashActivity — initializes services, shows the admin
/// announcement dialog from Firebase "dialogg/dialog" (once per version),
/// then opens MainActivity.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _status = 'ئامادەکردنی داتابەیس...');
    try {
      await Db.I.init();
    } catch (_) {}
    setState(() => _status = 'ڕێکخستنی ئاگادارکردنەوەکان...');
    try {
      await PrayerNotifications.I.init();
      await PrayerNotifications.I.requestPermission();
      await PrayerNotifications.I.scheduleAll();
      await HomeWidgets.updatePrayer();
      // Item 5: the Quran widget always carries one fresh ayah of the day.
      await HomeWidgets.pushDailyAyah();
    } catch (_) {}
    _checkAdminNotification();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()));
    _maybeShowDialog();
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
