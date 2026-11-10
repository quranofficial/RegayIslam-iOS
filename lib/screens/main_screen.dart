import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/home_widgets.dart';
import '../data/prayer_notifications.dart';
import '../main.dart' show kThemeEpoch, LastRoute;
import 'home/home_screen.dart';
import 'quran/quran_tab.dart';
import 'tasbih/tasbih_list.dart';
import 'settings/setting_tab.dart';

/// Original: MainActivity — ViewPager + BottomNavigationView.
/// Tab order from the original code: Home, Quran, Tasbih, Settings.
///
/// Item 12: dark mode switches IN PLACE — MainScreen listens to
/// kThemeEpoch and remounts the four tabs with fresh colors (no restart
/// through the Splash anymore).
class MainScreen extends StatefulWidget {
  /// Item 5-d: optional initialTab so the Splash can reopen the app on the
  /// tab the user was last on ("continue where I left off").
  const MainScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  late final PageController _pager;
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
    final t = widget.initialTab;
    _position = (t >= 0 && t < _tabs.length) ? t : 0;
    _pager = PageController(initialPage: _position);
    // Item 5-d: remember the tab the app was opened on; switching tabs
    // below keeps this fresh, so the next start reopens the same tab.
    LastRoute.set('tab::$_position');
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ValueListenableBuilder<int>(
        valueListenable: kThemeEpoch,
        builder: (context, epoch, __) {
          final d2 = !AppPrefs.I.day;
          return Scaffold(
            body: PageView(
              controller: _pager,
              onPageChanged: (i) {
                setState(() => _position = i);
                LastRoute.set('tab::$i');
              },
              // Fresh instances (keyed by the theme epoch) so the tabs
              // repaint immediately when day/night switches.
              children: [
                HomeScreen(key: ValueKey('home-$epoch')),
                QuranTab(key: ValueKey('quran-$epoch')),
                TasbihListScreen(key: ValueKey('tasbih-$epoch')),
                SettingTab(key: ValueKey('settings-$epoch')),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _position,
              onTap: _select,
              backgroundColor: d2 ? AppColors.nightCard : Colors.white,
              selectedItemColor: d2 ? AppColors.gold : AppColors.primaryDark,
              unselectedItemColor: d2 ? Colors.white54 : Colors.black54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: [
                for (final t in _tabs)
                  BottomNavigationBarItem(
                      icon: Icon(t.$2, size: 24), label: t.$1),
              ],
            ),
          );
        },
      ),
    );
  }
}
