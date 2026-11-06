import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/prefs.dart';
import 'screens/splash_screen.dart';

/// Global notifier so theme changes (day/night) rebuild the whole app,
/// mirroring the original "restart SplashActivity" behaviour.
final ValueNotifier<int> kThemeEpoch = ValueNotifier<int>(0);

/// Draw behind the system bars with a transparent navigation bar and keep
/// the icon brightness in sync with day/night (items 1, 9, 14): bottom
/// sections and audio bars stay visible above the mobile nav buttons.
void applySystemUi(bool dark) {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.I.init();
  applySystemUi(!AppPrefs.I.day);
  runApp(const RegayIslamApp());
}

class RegayIslamApp extends StatelessWidget {
  const RegayIslamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: kThemeEpoch,
        builder: (context, epoch, __) {
          final dark = !AppPrefs.I.day;
          applySystemUi(dark);
          // Item 12: when night/day switches, the whole app restarts
          // through the Splash like the original app, so every screen
          // (colors, cached widgets, sounds) comes up in the new mode.
          return MaterialApp(
            key: ValueKey('regayislam-$epoch'),
            title: 'ڕێگای ئیسلام',
            debugShowCheckedModeBanner: false,
            theme: AppPrefs.I.theme,
            home: const SplashScreen(),
          );
        });
  }
}

void toggleDayNight() {
  AppPrefs.I.day = !AppPrefs.I.day;
  applySystemUi(!AppPrefs.I.day);
  kThemeEpoch.value++;
}
