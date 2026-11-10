import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../core/ui.dart' show sharePage, bottomInset;
import '../data/downloader.dart';
import '../data/db.dart';
import '../screens/media/video_player_screen.dart';
import '../screens/media/live_screen.dart';
import '../screens/media/videos_screen.dart';
import '../screens/quran/open_quran.dart';
import '../screens/quran/qariakan_screen.dart';
import '../screens/quran/ayat_screen.dart';
import '../screens/quran/ayatul_kursi_screen.dart';
import '../screens/quran/ayah_range_screen.dart';
import '../screens/quran/quran_search_screen.dart';
import '../screens/quran/name_screen.dart';
import '../screens/quran/quran_studio_screen.dart';
import '../screens/ramadan/ramazan_screen.dart';
import '../screens/articles/json_article_screen.dart';
import '../screens/misc/zikr_detail_screen.dart';
import '../screens/books/kteb_screen.dart';
import '../screens/books/farmwda_screen.dart';
import '../screens/books/tawba_screen.dart';
import '../screens/home/prayer/nwezh_hub.dart';
import '../screens/nwezh/dasalatakan_screen.dart';
import '../screens/nwezh/prayers_month.dart';
import '../screens/nwezh/prayer_times_screen.dart';
import '../screens/nwezh/ruqya_audio_screen.dart';
import '../screens/settings/tawanakanm_screen.dart';
import '../screens/settings/women_screen.dart';
import '../screens/settings/question_screen.dart';
import '../screens/quiz/quiz_screen.dart';
import '../screens/tasbih/tasbih_counter.dart';
import '../screens/qibla_screen.dart';
import '../screens/home/home_reorder_screen.dart';

class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.title,
    required this.content,
    this.route = '',
  });
  final String id;
  final String title;
  final String content;

  /// Deep-link hint: "section::<label>", "surah::<id>", "book::<name>::<url>",
  /// "allahname::<id>", "friday", ... — lets the wishlist jump back to the
  /// exact screen with one click (items 5 + 11).
  final String route;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'content': content, 'route': route};
  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    content: '${json['content'] ?? ''}',
    route: '${json['route'] ?? ''}',
  );
}

class FavoritesStore {
  static const _key = 'regayislam_favorites';

  static Future<List<FavoriteEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) {
      try { return FavoriteEntry.fromJson(jsonDecode(e) as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<FavoriteEntry>().toList();
  }

  static Future<bool> contains(String id) async =>
    (await all()).any((e) => e.id == id);

  static Future<bool> toggle(FavoriteEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all();
    final exists = items.any((e) => e.id == entry.id);
    items.removeWhere((e) => e.id == entry.id);
    if (!exists) items.insert(0, entry);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
    return !exists;
  }

  /// Insert without toggling (used by the mushaf ayah sheet — item 22:
  /// the action is "add to favorites", never silently remove).
  static Future<void> add(FavoriteEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all();
    if (items.any((e) => e.id == entry.id)) return;
    items.insert(0, entry);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all()..removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.id,
    required this.title,
    required this.content,
    this.color,
    this.route,
    this.iconSize,
  });
  final String id;
  final String title;
  final String content;
  final Color? color;
  final String? route;
  final double? iconSize;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    FavoritesStore.contains(widget.id).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _saved ? 'لابردن لە دڵخوازەکان' : 'زیادکردن بۆ دڵخوازەکان',
    iconSize: widget.iconSize,
    visualDensity: widget.iconSize == null ? null : VisualDensity.compact,
    padding: widget.iconSize == null ? null : EdgeInsets.zero,
    constraints: widget.iconSize == null ? null : const BoxConstraints(),
    icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: widget.color ?? (_saved ? AppColors.gold : null)),
    onPressed: () async {
      final saved = await FavoritesStore.toggle(FavoriteEntry(
        id: widget.id, title: widget.title, content: widget.content,
        route: widget.route ?? ''));
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved ? 'زیادکرا بۆ دڵخوازەکان' : 'لابرا لە دڵخوازەکان'),
        duration: const Duration(seconds: 1)));
    },
  );
}

/// Item 11: every screen can save an item to the wishlist, and from the
/// wishlist one click returns to the very same place. This table maps the
/// home section labels to their screens so "section::" favorites jump back.
typedef ScreenBuilder = Widget Function();

/// Items 5 + 11: the full list of main sections — used by the
/// "زیادکردنی بەش" picker inside دڵخوازەکان so any main section can be
/// added to the wishlist directly, and jumps back with one tap.
const List<String> kHomeSections = [
  'دڵخوازەکان',
  'ئیدیتی قورئان',
  'نوێژکردن',
  'ناوەکانی خودای گەورە',
  'ئایەتی کورسی',
  'پرسیار و وەڵام',
  'ڤیدیۆی ئاینی',
  'تاوەنە گەورەکان',
  'کتێبخانە',
  'ڕوقیەی شەرعی',
  'زیکرەکان',
  'فەرموودەکان',
  'مانگی ڕەمەزان',
  'ئافرەتان',
  'دوعا و پاڕانەوە',
  'چۆن تۆبە بکەم',
  'حەج و عومرە',
  'ئەهلی ئاگر',
  'بەهەشت',
  'دۆزەخ',
  'خەونامە',
  'ژیانی پێغەمبەرمان ﷺ',
  'ژیانی پێغەمبەران',
  'هاوەڵانی پێغەمبەر ﷺ',
  'سونەت',
  'زانیاری قورئان',
  'ڕاو بۆچونەکان',
  'وتە و ئامۆژگاری',
  'حەڕام کراوەکان',
  'زیانەکانی گۆرانی',
  'تاوانی غەیبەت',
  'چیرۆکی دەجال',
  'قیبلەنما',
  'دەنگی قورئان',
  'گەڕان لە قورئان',
  'دوعاکانی نوێژ',
  'کاتەکانی مانگ',
  'خوێندنی ئایەتەکان',
  'دروستکردنی ڤیدیۆ و وێنە',
  'ڕێکخستنی بەشەکان',
  'کاتەکانی بانگ',
  'تەسبیح',
  'پەخشی ڕاستەوخۆ',
];

Widget? sectionScreenOf(String label) {
  switch (label) {
    case 'دڵخوازەکان':
      return const FavoritesScreen();
    case 'ئیدیتی قورئان':
    case 'دروستکردنی ڤیدیۆ و وێنە':
      return const QuranStudioScreen();
    case 'نوێژکردن':
      return const NwezhHubScreen();
    case 'ناوەکانی خودای گەورە':
      return const NameScreen();
    case 'ئایەتی کورسی':
      return const AyatulKursiScreen();
    case 'پرسیار و وەڵام':
      return const QuestionScreen();
    case 'ڤیدیۆی ئاینی':
      return const VideosScreen();
    case 'تاوەنە گەورەکان':
    case 'تاوانەگەورەکان': // legacy spelling kept for old favorites
    case 'تاوانەکانم': // legacy spelling kept for old favorites
      return const TawanakanmScreen();
    case 'کتێبخانە':
      return const KtebScreen();
    case 'ڕوقیەی شەرعی':
      return const RuqyaAudioScreen();
    case 'زیکرەکان':
      return const JsonArticleScreen(file: 'assets/data/zikrakan.json', title: 'زیکرەکان');
    case 'فەرموودەکان':
      return const FarmwdaScreen();
    case 'مانگی ڕەمەزان':
      return const RamazanScreen();
    case 'ئافرەتان':
      return const WomenScreen();
    case 'دوعا و پاڕانەوە':
      return const JsonArticleScreen(file: 'assets/data/duha.json', title: 'دوعا و پاڕانەوە');
    case 'چۆن تۆبە بکەم':
      return const TawbaScreen();
    case 'حەج و عومرە':
      return const JsonArticleScreen(file: 'assets/data/hajw.json', title: 'حەج و عومرە');
    case 'ئەهلی ئاگر':
      return const JsonArticleScreen(file: 'assets/data/agr.json', title: 'ئەهلی ئاگر');
    case 'بەهەشت':
      return const JsonArticleScreen(file: 'assets/data/bahasht.json', title: 'بەهەشت');
    case 'دۆزەخ':
      return const JsonArticleScreen(file: 'assets/data/dozax.json', title: 'دۆزەخ');
    case 'خەونامە':
      return const JsonArticleScreen(file: 'assets/data/xawn.json', title: 'خەونامە');
    case 'ژیانی پێغەمبەرمان ﷺ':
      return const JsonArticleScreen(file: 'assets/data/pexambarman.json', title: 'ژیانی پێغەمبەرمان ﷺ');
    case 'ژیانی پێغەمبەران':
      return const JsonArticleScreen(file: 'assets/data/pexambaran.json', title: 'ژیانی پێغەمبەران');
    case 'هاوەڵانی پێغەمبەر ﷺ':
      return const JsonArticleScreen(file: 'assets/data/hawal.json', title: 'هاوەڵانی پێغەمبەر ﷺ');
    case 'سونەت':
      return const JsonArticleScreen(file: 'assets/data/swnat.json', title: 'سونەت');
    case 'زانیاری قورئان':
      return const JsonArticleScreen(file: 'assets/data/zanyaryquran.json', title: 'زانیاری قورئان');
    case 'ڕاو بۆچونەکان':
      return const JsonArticleScreen(file: 'assets/data/rawbochwn.json', title: 'ڕاو بۆچونەکان');
    case 'وتە و ئامۆژگاری':
      return const JsonArticleScreen(file: 'assets/data/wta.json', title: 'وتە و ئامۆژگاری');
    case 'حەڕام کراوەکان':
      return const JsonArticleScreen(file: 'assets/data/haram.json', title: 'حەڕام کراوەکان');
    case 'زیانەکانی گۆرانی':
      return const JsonArticleScreen(file: 'assets/data/zianakanygorani.json', title: 'زیانەکانی گۆرانی');
    case 'تاوانی غەیبەت':
      return const JsonArticleScreen(file: 'assets/data/xaybat.json', title: 'تاوانی غەیبەت');
    case 'چیرۆکی دەجال':
      return const JsonArticleScreen(file: 'assets/data/dajal.json', title: 'چیرۆکی دەجال');
    case 'قیبلەنما':
      return const QiblaScreen();
    case 'دەنگی قورئان':
      return const QariakanScreen();
    case 'گەڕان لە قورئان':
      return const QuranSearchScreen();
    case 'دوعاکانی نوێژ':
      return const DasalatakanScreen();
    case 'کاتەکانی مانگ':
      return const PrayersMonthScreen();
    case 'خوێندنی ئایەتەکان':
      return const AyahRangeScreen();
    case 'ڕێکخستنی بەشەکان':
      return const HomeReorderScreen();
    case 'کاتەکانی بانگ':
      return const PrayerTimesScreen();
    case 'تەسبیح':
      return const TasbihCounterScreen();
    case 'پەخشی ڕاستەوخۆ':
      return const LiveScreen();
    case 'پرسیار و وەڵام (یاری)':
      return const QuizScreen();
    default:
      return null;
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteEntry> _items = [];
  List<FavoriteEntry> _all = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await FavoritesStore.all();
    if (mounted) {
      setState(() { _all = rows; _items = _filter(rows); _loading = false; });
    }
  }

  List<FavoriteEntry> _filter(List<FavoriteEntry> rows) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.content.toLowerCase().contains(q) ||
            _kindOf(e.id).label.toLowerCase().contains(q))
        .toList();
  }

  /// Item 5: add ANY main section to the wishlist from one place —
  /// no need to open the section first to find its bookmark icon.
  Future<void> _addSections() async {
    final saved = <String>{};
    for (final e in _all) {
      if (e.id.startsWith('section::')) saved.add(e.id);
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (c, setD) => AlertDialog(
            title: const Text('زیادکردنی بەشە سەرەکییەکان'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kHomeSections.length,
                itemBuilder: (c, i) {
                  final label = kHomeSections[i];
                  final id = 'section::$label';
                  final has = saved.contains(id);
                  return CheckboxListTile(
                    dense: true,
                    value: has,
                    title: Text(label, style: const TextStyle(fontSize: 13.5)),
                    onChanged: (v) => setD(() {
                      if (v == true) {
                        saved.add(id);
                      } else {
                        saved.remove(id);
                      }
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('لابردن')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('پاشەکەوت')),
            ],
          ),
        ),
      ),
    );
    if (changed != true) return;
    // sync every section favorite with the picked set
    for (final label in kHomeSections) {
      final id = 'section::$label';
      final shouldSave = saved.contains(id);
      final isSaved = _all.any((e) => e.id == id);
      if (shouldSave && !isSaved) {
        await FavoritesStore.toggle(FavoriteEntry(
            id: id, title: label,
            content: 'بەشی $label لە ئەپی ڕێگای ئیسلام', route: id));
      } else if (!shouldSave && isSaved) {
        await FavoritesStore.remove(id);
      }
    }
    _load();
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
          title: const Text('دڵخوازەکان', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
                tooltip: 'زیادکردنی بەشە سەرەکییەکان',
                icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                onPressed: _addSections),
            IconButton(
                tooltip: 'هاوبەشی ئەپ',
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => sharePage('دڵخوازەکانی من لە ئەپی ڕێگای ئیسلام',
                    title: 'دڵخوازەکان')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty && _q.isEmpty
            ? Center(child: Text('هیچ بابەتێک لە دڵخوازەکانت نییە',
                style: TextStyle(color: txt.withOpacity(.6))))
            // Item 7: fixed-height tiles — never overflow or fall apart.
            : Column(children: [
                // Items 5 + 11: search inside the wishlist itself.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _q = v;
                      _items = _filter(_all);
                    }),
                    decoration: InputDecoration(
                      hintText: 'گەڕان لە دڵخوازەکان...',
                      prefixIcon: const Icon(Icons.search_rounded),
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
                Expanded(
                  child: _items.isEmpty
                      ? Center(child: Text('هیچ ئەنجامێک نەدۆزرایەوە',
                          style: TextStyle(color: txt.withOpacity(.6))))
                      : ListView.separated(
                padding: EdgeInsets.fromLTRB(12, 6, 12, bottomInset(context, extra: 16)),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final kind = _kindOf(item.id);
                  return Card(
                    color: dark ? AppColors.nightCard : Colors.white,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _open(context, item),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: dark
                                ? AppColors.gold.withOpacity(.15)
                                : AppColors.primaryDark.withOpacity(.08),
                            child: Icon(kind.icon, size: 20,
                                color: dark ? AppColors.gold : AppColors.primaryDark)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment:
                                CrossAxisAlignment.start, children: [
                              Text(item.title.isEmpty ? kind.label : item.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 13.5, color: txt)),
                              const SizedBox(height: 2),
                              Text(kind.label,
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: dark ? AppColors.gold : AppColors.primaryDark)),
                              if (item.content.isNotEmpty &&
                                  !item.content.startsWith('http')) ...[
                                const SizedBox(height: 4),
                                Text(item.content, maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, height: 1.4,
                                      color: txt.withOpacity(.6))),
                              ],
                            ]),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: () async {
                              await FavoritesStore.remove(item.id);
                              _load();
                            },
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
                ),
              ]),
      ),
    );
  }

  /// Items 5 + 11: favorites keep their origin. One tap navigates straight
  /// back into the screen the item was saved from — never a raw URL.
  Future<void> _open(BuildContext context, FavoriteEntry item) async {
    final id = item.id;
    final route = item.route.isNotEmpty ? item.route : id;
    final parts = route.split('::');

    if (parts.isNotEmpty && parts[0] == 'video') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
              title: item.title, url: Downloader.httpsify(item.content))));
      return;
    }
    if (parts.length >= 3 && parts[0] == 'quran') {
      final surahId = int.tryParse(parts[1]) ?? 1;
      final ayah = int.tryParse(parts[2]) ?? 0;
      final s = (await Db.I.surahs())
          .where((r) => (r['soraid'] as num?)?.toInt() == surahId)
          .toList();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => OpenQuranScreen(
              surahId: surahId,
              surahName: s.isNotEmpty ? '${s.first['name'] ?? ''}' : '',
              ayaCount: s.isNotEmpty ? ((s.first['aya'] as num?)?.toInt() ?? 7) : 7,
              place: s.isNotEmpty ? '${s.first['place'] ?? ''}' : '',
              juz: s.isNotEmpty ? '${s.first['juz'] ?? ''}' : '',
              // Item 12: land on the EXACT ayah and ring it — not the top
              // of the surah.
              initialAyah: ayah > 0 ? ayah : null,
              highlightAyah: ayah > 0 ? ayah : null)));
      return;
    }
    if (parts.length >= 3 && parts[0] == 'ruqya') {
      final surahId = int.tryParse(parts[1]) ?? 1;
      final ayah = int.tryParse(parts[2]) ?? 0;
      final s = (await Db.I.surahs())
          .where((r) => (r['soraid'] as num?)?.toInt() == surahId)
          .toList();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => OpenQuranScreen(
              surahId: surahId,
              surahName: s.isNotEmpty ? '${s.first['name'] ?? ''}' : '',
              ayaCount: s.isNotEmpty ? ((s.first['aya'] as num?)?.toInt() ?? 7) : 7,
              place: s.isNotEmpty ? '${s.first['place'] ?? ''}' : '',
              juz: s.isNotEmpty ? '${s.first['juz'] ?? ''}' : '',
              initialAyah: ayah > 0 ? ayah : null,
              highlightAyah: ayah > 0 ? ayah : null)));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'surah') {
      final surahId = int.tryParse(parts[1]) ?? 1;
      final s = (await Db.I.surahs())
          .where((r) => (r['soraid'] as num?)?.toInt() == surahId)
          .toList();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => OpenQuranScreen(
              surahId: surahId,
              surahName: s.isNotEmpty ? '${s.first['name'] ?? ''}' : item.title,
              ayaCount: s.isNotEmpty ? ((s.first['aya'] as num?)?.toInt() ?? 7) : 7,
              place: s.isNotEmpty ? '${s.first['place'] ?? ''}' : '',
              juz: s.isNotEmpty ? '${s.first['juz'] ?? ''}' : '')));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'book') {
      // content = pdf url, title = book name
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => BookDetailScreen(
              book: {'name': item.title, 'url': item.content},
              url: item.content,
              downloaded: AppPrefs.I.pdfCachePath(item.content) != null &&
                  (AppPrefs.I.pdfCachePath(item.content) ?? '').isNotEmpty)));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'allahname') {
      final id = int.tryParse(parts[1]) ?? 0;
      // Item 12: the name screen opens with THAT name already expanded and
      // scrolled into view — not just the plain list.
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => NameScreen(openId: id > 0 ? id : null)));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'reciter') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const QariakanScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'live') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const LiveScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'daily_ayah') {
      // Item 12: the daily-ayah favorite reopens the Quran at the exact
      // ayah that was saved (parts: daily_ayah::<surahId>::<ayah>).
      final surahId = parts.length >= 3 ? int.tryParse(parts[1]) ?? 0 : 0;
      final ayah = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;
      if (surahId > 0) {
        final s = (await Db.I.surahs())
            .where((r) => (r['soraid'] as num?)?.toInt() == surahId)
            .toList();
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => OpenQuranScreen(
                surahId: surahId,
                surahName: s.isNotEmpty ? '${s.first['name'] ?? ''}' : '',
                ayaCount: s.isNotEmpty
                    ? ((s.first['aya'] as num?)?.toInt() ?? 7) : 7,
                place: s.isNotEmpty ? '${s.first['place'] ?? ''}' : '',
                juz: s.isNotEmpty ? '${s.first['juz'] ?? ''}' : '',
                initialAyah: ayah > 0 ? ayah : null,
                highlightAyah: ayah > 0 ? ayah : null)));
        return;
      }
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const AyatScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'ramadan_section') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const RamazanScreen()));
      return;
    }
    if (route == 'friday') {
      AppPrefs.I.zikrName = 'ڕۆژی هەینی';
      AppPrefs.I.zikrBody =
          '١ - خۆشۆردن\n٢ - خۆبۆنخۆشکردن و سەرچاککردن\n٣ - زوو گەیشتن بە نوێژی هەینی\n٤ - خوێندنی سوورەتی کەهف\n٥ - زۆر سەڵاوات لەسەر پێغەمبەر ﷺ';
      AppPrefs.I.zikrVip = 'سونەتەکانی ڕۆژی هەینی';
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ZikrDetailScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'section') {
      final label = route.substring('section::'.length);
      final screen = sectionScreenOf(label);
      if (screen != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => screen));
      } else {
        _showDetail(context, item);
      }
      return;
    }
    if (parts.length >= 2 && parts[0].endsWith('.json')) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => JsonArticleScreen(file: parts[0], title: item.title)));
      return;
    }
    _showDetail(context, item);
  }

  void _showDetail(BuildContext context, FavoriteEntry item) {
    showDialog<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(item.title),
          content: SingleChildScrollView(child: SelectableText(item.content)),
          actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'))],
        )),
    );
  }

  _FavKind _kindOf(String id) {
    final head = id.split('::').first;
    switch (head) {
      case 'video':
        return _FavKind(Icons.ondemand_video_rounded, 'ڤیدیۆ — کلیک بکە بۆ لێدان');
      case 'quran':
        return _FavKind(Icons.menu_book_rounded, 'ئایەتی قورئان — کلیک بکە بۆ خوێندنەوە');
      case 'surah':
        return _FavKind(Icons.auto_stories_rounded, 'سوورەت — کلیک بکە بۆ خوێندنەوە');
      case 'book':
        return _FavKind(Icons.local_library_rounded, 'کتێب — کلیک بکە بۆ خوێندنەوە');
      case 'allahname':
        return _FavKind(Icons.badge_rounded, 'ناوی خودای گەورە — کلیک بکە');
      case 'reciter':
        return _FavKind(Icons.mic_rounded, 'دەنگی قورئان — کلیک بکە بۆ قاریەکان');
      case 'live':
        return _FavKind(Icons.wifi_tethering_rounded, 'پەخشی ڕاستەوخۆ — کلیک بکە');
      case 'daily_ayah':
        return _FavKind(Icons.auto_stories_rounded, 'ئایەتی ڕۆژ — کلیک بکە');
      case 'ramadan_section':
        return _FavKind(Icons.dark_mode_rounded, 'مانگی ڕەمەزان — کلیک بکە');
      case 'friday':
        return _FavKind(Icons.favorite_rounded, 'ڕۆژی هەینی — کلیک بکە');
      case 'section':
        return _FavKind(Icons.category_rounded, 'بەش — کلیک بکە بۆ کردنەوە');
    }
    if (head.endsWith('.json')) {
      return _FavKind(Icons.article_rounded, 'بابەت — کلیک بکە بۆ کردنەوە');
    }
    return _FavKind(Icons.bookmark_rounded, 'بابەتی پاشەکەوتکراو');
  }
}

class _FavKind {
  final IconData icon;
  final String label;
  const _FavKind(this.icon, this.label);
}
