import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/prefs.dart';
import 'data/prayer_notifications.dart';
import 'screens/splash_screen.dart';

/// Root navigator key: lets the splash's exact-alarm guidance dialog open
/// OVER the main screen after pushReplacement disposed the splash itself.
final GlobalKey<NavigatorState> kNavigatorKey = GlobalKey<NavigatorState>();

/// Global notifier so theme changes (day/night) repaint every screen live —
/// item 12: switching dark mode must NOT restart the app through the Splash
/// anymore; everything (colors, system bars, bottom sections) updates in place.
final ValueNotifier<int> kThemeEpoch = ValueNotifier<int>(0);

/// Item 5-d: tiny "continue where I left off" recorder. Route names are
/// mostly null in this app, so the KEY screens record their place manually
/// (main_screen: 'tab::0..3' on open/tab switch, zikr_detail: 'zikr::…');
/// the Splash reads AppPrefs.I.lastRoute back on the next start and reopens
/// the same screen when resumeWhereLeftOff is on.
class LastRoute {
  static String current = '';
  static void set(String s) {
    current = s;
    AppPrefs.I.lastRoute = s;
  }
}

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

/// Never let a stray exception kill the app or show a raw red/grey error
/// box: log it and keep running (release builds show a friendly message).
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true; // handled
  };
  ErrorWidget.builder = (FlutterErrorDetails d) => kReleaseMode
      ? const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('هەڵەیەک ڕوویدا — بگەڕێوە و دووبارە هەوڵبدەرەوە',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          decoration: TextDecoration.none)))))
      : ErrorWidget(d.exception);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  await AppPrefs.I.init();
  // Item 5: the timezone MUST be ready before anything schedules a بانگ
  // alarm — do it in main(), before runApp, not only inside the splash.
  PrayerNotifications.ensureTimezone();
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
          // Item 12: the theme changes IN PLACE (same MaterialApp, same
          // navigator stack — no restart through the Splash). Screens listen
          // to kThemeEpoch and repaint, so the whole app comes up in the
          // new mode without losing the page the user is on.
          return MaterialApp(
            title: 'ڕێگای ئیسلام',
            debugShowCheckedModeBanner: false,
            navigatorKey: kNavigatorKey,
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
