// Task 5-e regression tests for the tasbih section.
//
// The original bug: SharedPreferences.getStringList hard-casts the stored
// value to List<dynamic>?, so a corrupted/foreign value under the
// "tasbihlist" key (e.g. a String left by the old Sketchware install)
// threw a TypeError inside initState → red ERROR screen on the tasbih tab.
// These tests pin the fix (safeTasbihList) and the counter/list behavior.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:regayislam/core/prefs.dart';
import 'package:regayislam/screens/tasbih/tasbih_counter.dart';
import 'package:regayislam/screens/tasbih/tasbih_list.dart';

Future<void> _initPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await AppPrefs.I.init();
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: Directionality(
      textDirection: TextDirection.rtl, child: screen)));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('list: normal prefs — renders the default zikr cards',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpScreen(tester, const TasbihListScreen());
    expect(find.text('تەسبیح'), findsOneWidget);
    expect(find.text('سوبحان الله'), findsOneWidget);
    expect(find.text('الحمد لله'), findsOneWidget);
  });

  testWidgets('list: corrupted pref (String) — NO crash, defaults shown',
      (tester) async {
    // Before the fix this threw:
    // type 'String' is not a subtype of type 'List<dynamic>?' in type cast
    await _initPrefs(<String, Object>{'tasbihlist': 'not-a-list'});
    await _pumpScreen(tester, const TasbihListScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('سوبحان الله'), findsOneWidget);
    // The broken key is healed back to a proper list.
    expect(AppPrefs.I.tasbihList, isA<List<String>>());
    expect(AppPrefs.I.tasbihList.length, 3);
  });

  testWidgets('list: corrupted pref (int) — NO crash', (tester) async {
    await _initPrefs(<String, Object>{'tasbihlist': 12345});
    await _pumpScreen(tester, const TasbihCounterScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('٠'), findsOneWidget);
  });

  testWidgets('list: add + delete zikr persists', (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpScreen(tester, const TasbihListScreen());
    await tester.enterText(
        find.byType(TextField), 'لا إله إلا الله');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();
    expect(find.text('لا إله إلا الله'), findsOneWidget);
    expect(AppPrefs.I.tasbihList.length, 4);
    // delete one item
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pump();
    expect(AppPrefs.I.tasbihList.length, 3);
  });

  testWidgets('counter: taps count up in Kurdish digits, round completes',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpScreen(tester, const TasbihCounterScreen());
    expect(find.text('٠'), findsOneWidget);
    // tap the big circle 33 times → one full round, back to ٠
    final ring = find.byKey(const ValueKey('tasbih-ring'));
    await tester.tap(ring);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('١'), findsOneWidget);
    for (var i = 0; i < 32; i++) {
      await tester.tap(ring);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('٠'), findsOneWidget); // completed → reset
    expect(find.text('خولەکە تەواو بوو'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600)); // flash timer fires
    await tester.pump(const Duration(milliseconds: 400)); // switcher fades out
    expect(find.text('خولەکە تەواو بوو'), findsNothing);
  });

  testWidgets('counter: target chips 33/99/100 switch the target',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpScreen(tester, const TasbihCounterScreen());
    await tester.tap(find.text('٩٩'));
    await tester.pump();
    expect(find.textContaining('ئامانج: ٩٩'), findsOneWidget);
    await tester.tap(find.text('١٠٠'));
    await tester.pump();
    expect(find.textContaining('ئامانج: ١٠٠'), findsOneWidget);
  });

  testWidgets('counter: no overflow on a small/short screen', (tester) async {
    await _initPrefs(<String, Object>{});
    tester.view.physicalSize = const Size(360, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pumpScreen(tester, const TasbihCounterScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('٠'), findsOneWidget);
  });

  testWidgets('list: no overflow on a small screen', (tester) async {
    await _initPrefs(<String, Object>{});
    tester.view.physicalSize = const Size(360, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pumpScreen(tester, const TasbihListScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('سوبحان الله'), findsOneWidget);
  });
}
