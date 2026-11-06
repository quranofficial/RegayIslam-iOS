import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/home_widgets.dart';
import '../data/prayer_notifications.dart';
import 'home/home_screen.dart';
import 'quran/quran_tab.dart';
import 'tasbih/tasbih_list.dart';
import 'settings/setting_tab.dart';

/// Original: MainActivity — ViewPager + BottomNavigationView.
/// Tab order from the original code: Home, Quran, Tasbih, Settings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  final PageController _pager = PageController();
  int _position = 0;

  static const _tabs = [
    ('سەرەتا', Icons.home_rounded),
    ('قورئان', Icons.menu_book_rounded),
    ('تەسبیح', Icons.fingerprint_rounded),
    ('ڕێکخستن', Icons.settings_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pager.dispose();
    super.dispose();
  }

  /// Item 3: every time the app comes back to the foreground the adhan
  /// notifications are re-scheduled for the coming days, so the prayer
  /// times never run out even when the phone stayed off for a while.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        PrayerNotifications.I.scheduleAll();
        HomeWidgets.updatePrayer();
        HomeWidgets.pushDailyAyah();
      } catch (_) {}
    }
  }

  void _select(int i) {
    _pager.animateToPage(i,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: PageView(
          controller: _pager,
          onPageChanged: (i) => setState(() => _position = i),
          children: const [
            HomeScreen(),
            QuranTab(),
            TasbihListScreen(),
            SettingTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _position,
          onTap: _select,
          backgroundColor: dark ? AppColors.nightCard : Colors.white,
          selectedItemColor: dark ? AppColors.gold : AppColors.primaryDark,
          unselectedItemColor: dark ? Colors.white54 : Colors.black54,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(
                  icon: Icon(t.$2, size: 24), label: t.$1),
          ],
        ),
      ),
    );
  }
}
