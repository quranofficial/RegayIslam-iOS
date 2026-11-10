import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;
import '../quran/open_quran.dart' show toArabicDigits;
import 'tasbih_counter.dart';

/// Original: TasbihFragmentActivity — saved tasbih list with counts.
class TasbihListScreen extends StatefulWidget {
  const TasbihListScreen({super.key});
  @override
  State<TasbihListScreen> createState() => _TasbihListScreenState();
}

class _TasbihListScreenState extends State<TasbihListScreen> {
  late List<String> _items;
  final TextEditingController _add = TextEditingController();

  /// Icon set rotated per zikr — the badge look matches the Quran tab's
  /// circular tinted icons.
  static const _icons = [
    Icons.fingerprint_rounded,
    Icons.self_improvement_rounded,
    Icons.auto_awesome_rounded,
    Icons.favorite_rounded,
    Icons.brightness_high_rounded,
    Icons.all_inclusive_rounded,
    Icons.spa_rounded,
    Icons.star_rounded,
  ];

  @override
  void initState() {
    super.initState();
    // Safe read: never crashes on a corrupted "tasbihlist" pref (see
    // safeTasbihList in the counter screen — that cast was the ERROR).
    _items = [...safeTasbihList()];
  }

  void _persist() {
    AppPrefs.I.tasbihList = _items;
  }

  Future<void> _addItem() async {
    final v = _add.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _items.add('$v|33');
      _add.clear();
    });
    _persist();
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('تەسبیح',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Center(
                  child: Text(
                    '${toArabicDigits(_items.length)} زیکر',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _add,
                  onSubmitted: (_) => _addItem(),
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: txt, fontSize: 14),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: 'زیکرێکی نوێ زیاد بکە...',
                    hintStyle: TextStyle(
                        color: txt.withValues(alpha: .4), fontSize: 14),
                    prefixIcon: Icon(Icons.add_rounded, color: accent),
                    filled: true,
                    fillColor: dark ? AppColors.nightCard : Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: dark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _addItem,
                  child: const Icon(Icons.check_rounded)),
            ]),
          ),
          Expanded(
            child: _items.isEmpty
                ? _emptyState(txt, dark)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(12, 2, 12,
                        bottomInset(context, extra: 16)),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final entry = _items[i];
                      final name = tasbihNameOf(entry);
                      final target = tasbihTargetOf(entry);
                      return Card(
                        color: dark ? AppColors.nightCard : Colors.white,
                        elevation: dark ? 0 : 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const TasbihCounterScreen())),
                          contentPadding: const EdgeInsetsDirectional
                              .only(start: 10, end: 4),
                          leading: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dark
                                  ? AppColors.gold.withValues(alpha: .14)
                                  : AppColors.primaryDark
                                      .withValues(alpha: .08),
                              border: Border.all(
                                  color: dark
                                      ? AppColors.gold.withValues(alpha: .45)
                                      : AppColors.primaryDark
                                          .withValues(alpha: .2)),
                            ),
                            child: Icon(_icons[i % _icons.length],
                                size: 24, color: accent),
                          ),
                          title: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: txt)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                                'ئامانج: ${toArabicDigits(target)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: txt.withValues(alpha: .55))),
                          ),
                          trailing: IconButton(
                              tooltip: 'سڕینەوە',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent),
                              onPressed: () => setState(() {
                                    _items.removeAt(i);
                                    _persist();
                                  })),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState(Color txt, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? AppColors.gold.withValues(alpha: .10)
                  : AppColors.primaryDark.withValues(alpha: .06),
              border: Border.all(
                  color: dark
                      ? AppColors.gold.withValues(alpha: .3)
                      : AppColors.primaryDark.withValues(alpha: .15)),
            ),
            child: Icon(Icons.fingerprint_rounded,
                size: 42,
                color: dark
                    ? AppColors.gold.withValues(alpha: .7)
                    : AppColors.primaryDark.withValues(alpha: .55)),
          ),
          const SizedBox(height: 16),
          Text('هێشتا هیچ زیکرێک زیاد نەکراوە',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: txt.withValues(alpha: .85))),
          const SizedBox(height: 6),
          Text(
              'زیکرەکانەکەت لێرە هەڵدەگیرێن — یەکێک زیاد بکە و ژماردن دەست پێ بکە',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.6,
                  color: txt.withValues(alpha: .5))),
        ]),
      ),
    );
  }
}
