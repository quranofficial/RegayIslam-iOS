import 'package:flutter/material.dart';
import 'core/prefs.dart';
import 'screens/splash_screen.dart';

/// Global notifier so theme changes (day/night) rebuild the whole app,
/// mirroring the original "restart SplashActivity" behaviour.
final ValueNotifier<int> kThemeEpoch = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.I.init();
  runApp(const RegayIslamApp());
}

class RegayIslamApp extends StatelessWidget {
  const RegayIslamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: kThemeEpoch,
        builder: (context, _, __) => MaterialApp(
              title: 'ڕێگای ئیسلام',
              debugShowCheckedModeBanner: false,
              theme: AppPrefs.I.theme,
              home: const SplashScreen(),
            ));
  }
}

void toggleDayNight() {
  AppPrefs.I.day = !AppPrefs.I.day;
  kThemeEpoch.value++;
}
