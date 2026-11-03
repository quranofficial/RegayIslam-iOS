import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
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

class _MainScreenState extends State<MainScreen> {
  final PageController _pager = PageController();
  int _position = 0;

  static const _tabs = [
    ('سەرەتا', Icons.home_rounded),
    ('قورئان', Icons.menu_book_rounded),
    ('تەسبیح', Icons.fingerprint_rounded),
    ('ڕێکخستن', Icons.settings_rounded),
  ];

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
