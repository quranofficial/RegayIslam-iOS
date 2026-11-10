import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;
import '../../data/favorites.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Original: Tasbih2Activity — tasbih counter with target, vibration and
/// click animation.
class TasbihCounterScreen extends StatefulWidget {
  const TasbihCounterScreen({super.key});
  @override
  State<TasbihCounterScreen> createState() => _TasbihCounterScreenState();
}

/// FIX (the red ERROR screen on the tasbih tab): SharedPreferences
/// `getStringList` hard-casts the stored value to `List<dynamic>?`, so any
/// non-list value under the "tasbihlist" key (a String/int left by an old
/// install of the original Sketchware app, or a corrupted write) threw
///   type 'String' is not a subtype of type 'List<dynamic>?' in type cast
/// right inside initState → ERROR widget. Reading through this helper never
/// crashes, filters empty entries and HEALS the broken key once by writing
/// back a valid list.
List<String> safeTasbihList() {
  const fallback = <String>['سوبحان الله|33', 'الحمد لله|33', 'الله أكبر|34'];
  try {
    final raw = AppPrefs.I.tasbihList;
    final clean = <String>[];
    for (final e in raw) {
      final s = e.trim();
      if (s.isNotEmpty) clean.add(s);
    }
    return clean;
  } catch (_) {
    try {
      AppPrefs.I.tasbihList = fallback; // heal the corrupted pref value
    } catch (_) {}
    return List<String>.from(fallback);
  }
}

/// "سوبحان الله|33" → "سوبحان الله" (never empty).
String tasbihNameOf(String entry) {
  final i = entry.indexOf('|');
  final n = (i < 0 ? entry : entry.substring(0, i)).trim();
  return n.isEmpty ? 'زیکر' : n;
}

/// "سوبحان الله|33" → 33 (guarded against junk / 0).
int tasbihTargetOf(String entry) {
  final parts = entry.split('|');
  if (parts.length > 1) {
    final t = int.tryParse(parts[1].trim()) ?? 33;
    if (t > 0) return t;
  }
  return 33;
}

class _TasbihCounterScreenState extends State<TasbihCounterScreen>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _target = 33;
  int _round = 0;
  late String _zikr;
  bool _vibrate = true;
  bool _justFinished = false;

  /// Bump pulse on every tap: scale = 1 + 0.06·sin(π·t) grows and settles
  /// back in one 180 ms pass — no reverse step needed.
  late final AnimationController _bump = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180));
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    final list = safeTasbihList();
    String name = '';
    for (final e in list) {
      final n = tasbihNameOf(e);
      if (n != 'زیکر') {
        name = n;
        break;
      }
    }
    _zikr = name.isNotEmpty ? name : 'سوبحان الله';
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _bump.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    var finished = false;
    setState(() {
      _count++;
      if (_count >= _target) {
        _count = 0;
        _round++;
        finished = true;
        _justFinished = true;
      }
      _bump.forward(from: 0);
    });
    if (finished) {
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _justFinished = false);
      });
    }
    if (_vibrate) {
      try {
        await Vibration.vibrate(duration: finished ? 150 : 40);
      } catch (_) {}
    }
  }

  void _reset() {
    _flashTimer?.cancel();
    setState(() {
      _count = 0;
      _round = 0;
      _justFinished = false;
    });
  }

  Future<void> _pick() async {
    final list = safeTasbihList();
    final seen = <String>{};
    final v = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: const Text('زیکر هەڵبژێرە'),
            children: [
              if (list.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'هیچ زیکرێک زیاد نەکراوە — لە تابی تەسبیح زیاد بکە')),
              for (final t in list)
                if (seen.add(tasbihNameOf(t)))
                  SimpleDialogOption(
                      onPressed: () =>
                          Navigator.pop(context, tasbihNameOf(t)),
                      child: Row(children: [
                        Icon(
                            tasbihNameOf(t) == _zikr
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: tasbihNameOf(t) == _zikr
                                ? AppColors.gold
                                : Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(tasbihNameOf(t),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ])),
            ]));
    if (!mounted) return;
    if (v != null && v.isNotEmpty) setState(() => _zikr = v);
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final progress = _target > 0 ? (_count / _target).clamp(0.0, 1.0) : 0.0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : AppColors.primaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(_zikr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            FavoriteButton(
                id: 'tasbih::$_zikr',
                title: _zikr,
                content: 'زیکری هەڵبژێردراو: $_zikr',
                color: Colors.white),
            IconButton(
                tooltip: 'زیکر هەڵبژێرە',
                onPressed: _pick,
                icon: const Icon(Icons.playlist_add_rounded)),
            IconButton(
                tooltip: _vibrate ? 'لەکارخستنی لەرزین' : 'کاراکردنی لەرزین',
                onPressed: () => setState(() => _vibrate = !_vibrate),
                icon: Icon(_vibrate
                    ? Icons.vibration_rounded
                    : Icons.phonelink_erase_rounded)),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [AppColors.nightBg, AppColors.nightBg]
                  : [AppColors.primaryDark, const Color(0xFF003A5C)],
            ),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Text(
                'خول: ${toArabicDigits(_round)} • ئامانج: ${toArabicDigits(_target)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _bump,
                  builder: (context, child) => Transform.scale(
                    scale: 1.0 + 0.06 * math.sin(math.pi * _bump.value),
                    child: child,
                  ),
                  // FittedBox: the ring scales down instead of overflowing on
                  // very short screens (landscape / small phones).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GestureDetector(
                      key: const ValueKey('tasbih-ring'),
                      onTap: _tap,
                      child: SizedBox(
                        width: 252,
                        height: 252,
                        child: CustomPaint(
                          painter: _ProgressRing(
                            progress: progress,
                            track: Colors.white.withValues(alpha: .14),
                            fill: AppColors.gold,
                          ),
                          child: Center(
                            child: Container(
                              width: 208,
                              height: 208,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: .14),
                                    Colors.white.withValues(alpha: .05),
                                  ],
                                ),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: .18)),
                              ),
                              child: Center(
                                child: Text(toArabicDigits(_count),
                                    style: const TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // progress line — flashes "خولەکە تەواو بوو" when a round completes
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _justFinished
                  ? const Text('خولەکە تەواو بوو',
                      key: ValueKey('done'),
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold))
                  : Text(
                      '${toArabicDigits(_count)} لە ${toArabicDigits(_target)}',
                      key: const ValueKey('count'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + bottomInset(context, extra: 0)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in [33, 99, 100]) _targetChip(t, dark),
                    ]),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: .35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  label: const Text('سفرکردن',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _targetChip(int t, bool dark) {
    final selected = _target == t;
    return ChoiceChip(
        label: Text(toArabicDigits(t),
            style: TextStyle(
                color: selected
                    ? (dark ? Colors.black : AppColors.primaryDark)
                    : Colors.white70,
                fontWeight: FontWeight.bold)),
        selected: selected,
        selectedColor: dark ? AppColors.gold : Colors.white,
        backgroundColor: Colors.white.withValues(alpha: .10),
        side: BorderSide(
            color: selected
                ? (dark ? AppColors.gold : Colors.white)
                : Colors.white.withValues(alpha: .2)),
        onSelected: (_) => setState(() {
              _target = t;
              if (_count >= _target) _count = 0;
            }));
  }
}

/// Thin progress ring around the big circular counter: track circle +
/// rounded clockwise arc from the top showing count / target.
class _ProgressRing extends CustomPainter {
  _ProgressRing({
    required this.progress,
    required this.track,
    required this.fill,
  });
  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * p,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = fill);
    }
  }

  @override
  bool shouldRepaint(_ProgressRing oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
