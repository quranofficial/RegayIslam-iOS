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
/// Item 21: the second browse mode is لاپەڕە (pages) — 604 page cards that
/// open the real MushafScreen at that page (the old پارە/جوزئی mode kept
/// bouncing back to a list). Item 3: a "continue reading" card always sits
/// on top and returns to the EXACT last-read ayah.
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
  late int _mode; // 0 = سوورەت, 1 = لاپەڕە
  Map<String, Object?>? _lastRead;

  @override
  void initState() {
    super.initState();
    _mode = AppPrefs.I.quranBrowseMode;
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.surahs();
    // Item 3: the last-read surah for the continue-reading card.
    Map<String, Object?>? last;
    final sid = AppPrefs.I.lastReadSurah;
    if (sid > 0) {
      for (final r in rows) {
        if ((r['soraid'] as num?)?.toInt() == sid) {
          last = r;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _all = rows;
      _filtered = rows;
      _lastRead = last;
      _loading = false;
    });
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

  void _setMode(int m) {
    setState(() => _mode = m);
    AppPrefs.I.quranBrowseMode = m;
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
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const MushafScreen()));
                  _load();
                }),
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
                    // Item 21: لاپەڕە (pages) replaces the old پارە (جوزئی)
                    // label — picking a page opens the mushaf itself.
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.menu_book_rounded, size: 18),
                            label: Text('سوورەت')),
                        ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.auto_stories_rounded, size: 18),
                            label: Text('لاپەڕە')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => _setMode(s.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        side: WidgetStatePropertyAll(BorderSide(
                            color: dark ? Colors.white12 : Colors.black12)),
                      ),
                    ),
                  ]),
                ),
                _continueCard(dark, txt),
                Expanded(
                  child: _mode == 1
                      ? _pageGrid(dark, txt)
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

  /// Item 3: the continue-reading card — shown only when there is a saved
  /// reading position; one tap reopens the reader at the EXACT ayah.
  Widget _continueCard(bool dark, Color txt) {
    final s = _lastRead;
    final ayah = AppPrefs.I.lastReadAyah;
    if (s == null || ayah <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Card(
        color: dark ? AppColors.gold.withOpacity(.12) : const Color(0xFFE8F0FE),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: dark
                    ? AppColors.gold.withOpacity(.4)
                    : AppColors.primaryDark.withOpacity(.25))),
        child: ListTile(
          onTap: () => _openSurahAt(s, ayah),
          leading: Icon(Icons.history_edu_rounded,
              color: dark ? AppColors.gold : AppColors.primaryDark, size: 30),
          title: Text('بەردەوامبوونی خوێندنەوە',
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13.5, color: txt)),
          subtitle: Text(
              '${suraLabel('${s['name']}')} • ئایەتی ${toArabicDigits(ayah)}'
              '${AppPrefs.I.lastReadWhen.isEmpty ? '' : '  —  ${AppPrefs.I.lastReadWhen}'}',
              style: TextStyle(fontSize: 12,
                  color: dark ? AppColors.gold : AppColors.primaryDark)),
          trailing: Icon(Icons.play_circle_rounded,
              size: 32, color: dark ? AppColors.gold : AppColors.primaryDark),
        ),
      ),
    );
  }

  void _openSurah(Map<String, Object?> s) => _openSurahAt(s, null);

  void _openSurahAt(Map<String, Object?> s, int? ayah) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => OpenQuranScreen(
            surahId: int.tryParse('${s['soraid']}') ?? 1,
            surahName: '${s['name']}',
            ayaCount: int.tryParse('${s['aya']}') ?? 0,
            place: '${s['place']}',
            juz: '${s['juz']}',
            initialAyah: ayah,
            highlightAyah: ayah))).then((_) => _load());
  }

  /// Item 21: 604 لاپەڕە — tapping a page card opens the real mushaf on
  /// that page (no more bouncing back to a surah list).
  Widget _pageGrid(bool dark, Color txt) => GridView.builder(
        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomInset(context)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 1.0),
        itemCount: 604,
        itemBuilder: (context, i) {
          final page = i + 1;
          final isLast = page == AppPrefs.I.mushafLastPage;
          return InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MushafScreen(startPage: page)));
              _load();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: isLast
                      ? AppColors.gold.withOpacity(.16)
                      : (dark ? AppColors.nightCard : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isLast
                          ? AppColors.gold
                          : (dark ? Colors.white10 : Colors.black12),
                      width: isLast ? 1.6 : 1)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(toArabicDigits(page),
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isLast
                                ? AppColors.gold
                                : (dark ? Colors.white : Colors.black87))),
                    Text('لاپەڕە',
                        style: TextStyle(fontSize: 9.5,
                            color: txt.withOpacity(.45))),
                  ]),
            ),
          );
        },
      );
}
