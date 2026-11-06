import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset, sharePage, suraLabel;
import '../../data/db.dart';
import '../../data/favorites.dart';
import 'mushaf_screen.dart';
import 'open_quran.dart' show OpenQuranScreen, toArabicDigits;
import 'quran_search_screen.dart';
import 'quran_studio_screen.dart';

/// Original: QurannFragmentActivity — surah list with live search filter.
/// Item 3: the Quran can also be browsed by جوزئی (پارە) — 30 parts, each
/// opening the surah it starts in. Item 20: titles never double the
/// "سوڕەتی" prefix (suraLabel strips every DB spelling).
class QuranTab extends StatefulWidget {
  const QuranTab({super.key});
  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, Object?>> _all = [];
  List<Map<String, Object?>> _filtered = [];
  bool _loading = true;
  bool _byJuz = false; // false = سوورەت, true = پارە (جوزئی)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.surahs();
    if (!mounted) return;
    setState(() { _all = rows; _filtered = rows; _loading = false; });
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((r) {
              final name = (r['name'] ?? '').toString().toLowerCase();
              final id = (r['soraid'] ?? '').toString();
              return name.contains(q) || id == q;
            }).toList();
    });
  }

  /// جوزئی numbers contained in a raw DB value like "جوزئی  3-4".
  List<int> _juzOf(Map<String, Object?> s) {
    final raw = '${s['juz'] ?? ''}'.replaceAll(RegExp(r'[^0-9\-]'), ' ');
    final out = <int>{};
    for (final p in raw.split(RegExp(r'[\s\-]+'))) {
      final n = int.tryParse(p);
      if (n != null && n >= 1 && n <= 30) out.add(n);
    }
    return out.toList()..sort();
  }

  /// The surah in which juz [n] starts (smallest global start ayah).
  Map<String, Object?>? _surahOfJuz(int n) {
    Map<String, Object?>? best;
    var bestStart = 1 << 30;
    for (final s in _all) {
      if (!_juzOf(s).contains(n)) continue;
      final st = (s['sarata'] as num?)?.toInt() ??
          ((s['soraid'] as num?)?.toInt() ?? 0) * 10000;
      if (st < bestStart) { bestStart = st; best = s; }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('قورئانی پیرۆز',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: 'مەشەف',
                icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MushafScreen()))),
            IconButton(
                tooltip: 'ئیدیتی قورئان',
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const QuranStudioScreen()))),
            IconButton(
                tooltip: 'گەڕان لە ناو ئایەتەکان',
                icon: const Icon(Icons.travel_explore_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const QuranSearchScreen()))),
            IconButton(
                tooltip: 'هاوبەشی',
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => sharePage(
                    'قورئانی پیرۆز بە کوردی و تەفسیر و دەنگی قارئەکان',
                    title: 'قورئانی پیرۆز')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    TextField(
                      controller: _search,
                      onChanged: _filter,
                      decoration: InputDecoration(
                        hintText: 'گەڕان بۆ سوورەت...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: dark ? AppColors.nightCard : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Item 3: سوورەت بە پارەش بخوێنرێتەوە.
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.menu_book_rounded, size: 18),
                            label: Text('سوورەت')),
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.auto_stories_rounded, size: 18),
                            label: Text('پارە (جوزئی)')),
                      ],
                      selected: {_byJuz},
                      onSelectionChanged: (s) =>
                          setState(() => _byJuz = s.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        side: WidgetStatePropertyAll(BorderSide(
                            color: dark ? Colors.white12 : Colors.black12)),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: _byJuz
                      ? _juzList(dark, txt)
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset(context)),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final s = _filtered[i];
                            final num = int.tryParse('${s['soraid']}') ?? 0;
                            return Card(
                              color: dark ? AppColors.nightCard : Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                onTap: () => _openSurah(s),
                                leading: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dark ? AppColors.gold.withOpacity(.14)
                                        : AppColors.primaryDark.withOpacity(.08),
                                    border: Border.all(
                                      color: dark ? AppColors.gold.withOpacity(.45)
                                          : AppColors.primaryDark.withOpacity(.2)),
                                  ),
                                  child: Stack(alignment: Alignment.center, children: [
                                    Icon(Icons.auto_stories_rounded, size: 25,
                                      color: dark ? AppColors.gold : AppColors.primaryDark),
                                    Positioned(bottom: 1, right: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: dark ? AppColors.nightCard : Colors.white,
                                          borderRadius: BorderRadius.circular(6)),
                                        child: Text(toArabicDigits(num),
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                            color: dark ? AppColors.gold : AppColors.primaryDark)),
                                      )),
                                  ]),
                                ),
                                // Item 20: سوڕەتی تەنها یەک جار.
                                title: Text(suraLabel('${s['name']}'),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, color: txt)),
                                subtitle: Text(
                                    '${toArabicDigits(int.tryParse('${s['aya']}') ?? 0)} ئایەت • ${s['place']} • ${s['juz']}',
                                    style: TextStyle(
                                        fontSize: 12, color: txt.withOpacity(.6))),
                                trailing: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FavoriteButton(
                                        id: 'surah::$num',
                                        title: suraLabel('${s['name']}'),
                                        content: '${s['place']} • ${s['juz']}',
                                        route: 'surah::$num',
                                        iconSize: 20),
                                      Icon(Icons.chevron_left,
                                          color: txt.withOpacity(.4)),
                                    ]),
                              ),
                            );
                          },
                        ),
                ),
              ]),
      ),
    );
  }

  void _openSurah(Map<String, Object?> s) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => OpenQuranScreen(
            surahId: int.tryParse('${s['soraid']}') ?? 1,
            surahName: '${s['name']}',
            ayaCount: int.tryParse('${s['aya']}') ?? 0,
            place: '${s['place']}',
            juz: '${s['juz']}')));
  }

  /// Item 3: 30 juz cards — each opens the surah the juz starts in.
  Widget _juzList(bool dark, Color txt) => GridView.builder(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset(context)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 1.05),
        itemCount: 30,
        itemBuilder: (context, i) {
          final juz = i + 1;
          final s = _surahOfJuz(juz);
          final surahName = s == null ? '' : '${s['name']}';
          return InkWell(
            onTap: s == null ? null : () => _openSurah(s),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: dark ? AppColors.nightCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: dark ? Colors.white10 : Colors.black12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? AppColors.gold.withOpacity(.14)
                              : AppColors.primaryDark.withOpacity(.08)),
                      child: Text(toArabicDigits(juz),
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: dark ? AppColors.gold : AppColors.primaryDark))),
                    const SizedBox(height: 6),
                    Text('جوزئی $juz',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 12, color: txt)),
                    if (surahName.isNotEmpty)
                      Text(suraLabel(surahName),
                          textAlign: TextAlign.center, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10,
                              color: txt.withOpacity(.55))),
                  ]),
            ),
          );
        },
      );
}
