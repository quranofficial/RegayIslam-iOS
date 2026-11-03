import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/db.dart';
import '../data/prayer_notifications.dart';
import 'main_screen.dart';

/// Original: SplashActivity — initializes services, then opens MainActivity.
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
    } catch (_) {}
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()));
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
