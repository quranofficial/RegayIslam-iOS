import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/favorites.dart';

/// Original: Tasbih2Activity — tasbih counter with target, vibration and
/// click animation.
class TasbihCounterScreen extends StatefulWidget {
  const TasbihCounterScreen({super.key});
  @override
  State<TasbihCounterScreen> createState() => _TasbihCounterScreenState();
}

class _TasbihCounterScreenState extends State<TasbihCounterScreen> {
  int _count = 0;
  int _target = 33;
  int _round = 0;
  late String _zikr;
  bool _vibrate = true;

  @override
  void initState() {
    super.initState();
    final list = AppPrefs.I.tasbihList;
    _zikr = list.isNotEmpty ? list.first.split('|').first : 'سوبحان الله';
  }

  Future<void> _tap() async {
    setState(() {
      _count++;
      if (_count >= _target) {
        _count = 0;
        _round++;
      }
    });
    if (_vibrate) {
      try { await Vibration.vibrate(duration: 40); } catch (_) {}
    }
  }

  void _reset() => setState(() { _count = 0; _round = 0; });

  Future<void> _pick() async {
    final list = AppPrefs.I.tasbihList;
    final v = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: const Text('زیکر هەڵبژێرە'),
            children: [
              for (final t in list)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, t.split('|').first),
                    child: Text(t.split('|').first)),
            ]));
    if (v != null) setState(() => _zikr = v);
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFF004D7B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(_zikr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            FavoriteButton(id: 'tasbih::$_zikr', title: _zikr,
              content: 'زیکری هەڵبژێردراو: $_zikr', color: Colors.white),
            IconButton(
                onPressed: _pick, icon: const Icon(Icons.playlist_add_rounded)),
            IconButton(
                onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded)),
            IconButton(
                onPressed: () => setState(() => _vibrate = !_vibrate),
                icon: Icon(_vibrate
                    ? Icons.vibration_rounded
                    : Icons.phonelink_erase_rounded)),
          ],
        ),
        body: Column(children: [
          const SizedBox(height: 8),
          Text('دۆخ: $_round • ئامانج: $_target',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _tap,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.08),
                      border: Border.all(color: Colors.white.withOpacity(.25), width: 3)),
                  child: Center(
                    child: Text('$_count',
                        style: const TextStyle(
                            fontSize: 64, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Wrap(spacing: 8, children: [
              for (final t in [33, 100, 500, 1000])
                ChoiceChip(
                    label: Text('$t',
                        style: TextStyle(
                            color: _target == t ? Colors.white : Colors.white70)),
                    selected: _target == t,
                    selectedColor: AppColors.green,
                    backgroundColor: Colors.white.withOpacity(.1),
                    onSelected: (_) => setState(() => _target = t)),
            ]),
          ),
        ]),
      ),
    );
  }
}
