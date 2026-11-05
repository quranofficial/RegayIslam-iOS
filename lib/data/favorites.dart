import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../data/downloader.dart';
import '../data/db.dart';
import '../screens/media/video_player_screen.dart';
import '../screens/media/live_screen.dart';
import '../screens/quran/open_quran.dart';
import '../screens/quran/qariakan_screen.dart';
import '../screens/quran/ayat_screen.dart';
import '../screens/ramadan/ramazan_screen.dart';
import '../screens/articles/json_article_screen.dart';

class FavoriteEntry {
  const FavoriteEntry({required this.id, required this.title, required this.content});
  final String id;
  final String title;
  final String content;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'content': content};
  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    content: '${json['content'] ?? ''}',
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

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all()..removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.id, required this.title, required this.content, this.color});
  final String id;
  final String title;
  final String content;
  final Color? color;

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
    icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: widget.color ?? (_saved ? AppColors.gold : null)),
    onPressed: () async {
      final saved = await FavoritesStore.toggle(FavoriteEntry(
        id: widget.id, title: widget.title, content: widget.content));
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved ? 'زیادکرا بۆ دڵخوازەکان' : 'لابرا لە دڵخوازەکان'),
        duration: const Duration(seconds: 1)));
    },
  );
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await FavoritesStore.all();
    if (mounted) setState(() { _items = rows; _loading = false; });
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
        ),
        body: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
            ? Center(child: Text('هیچ بابەتێک لە دڵخوازەکانت نییە',
                style: TextStyle(color: txt.withOpacity(.6))))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final kind = _kindOf(item.id);
                  return Card(
                    color: dark ? AppColors.nightCard : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      onTap: () => _open(context, item),
                      leading: CircleAvatar(
                        backgroundColor:
                            dark ? AppColors.gold.withOpacity(.15) : AppColors.primaryDark.withOpacity(.08),
                        child: Icon(kind.icon,
                            size: 20,
                            color: dark ? AppColors.gold : AppColors.primaryDark)),
                      title: Text(item.title.isEmpty ? kind.label : item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.label,
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: dark ? AppColors.gold : AppColors.primaryDark)),
                            if (item.content.isNotEmpty &&
                                !item.content.startsWith('http'))
                              Text(item.content, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12,
                                    color: txt.withOpacity(.6))),
                          ]),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          await FavoritesStore.remove(item.id);
                          _load();
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Item 17: favorites keep their origin. Tapping one navigates back into
  /// the section it came from (video player, surah, reciter, article...)
  /// instead of showing a raw URL.
  Future<void> _open(BuildContext context, FavoriteEntry item) async {
    final id = item.id;
    final parts = id.split('::');
    if (parts.length >= 2 && parts[0] == 'video') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
              title: item.title, url: Downloader.httpsify(item.content))));
      return;
    }
    if (parts.length >= 3 && parts[0] == 'quran') {
      final surahId = int.tryParse(parts[1]) ?? 1;
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
              juz: s.isNotEmpty ? '${s.first['juz'] ?? ''}' : '')));
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
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const AyatScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'ramadan_section') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const RamazanScreen()));
      return;
    }
    if (parts.length >= 2 && parts[0].endsWith('.json')) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => JsonArticleScreen(file: parts[0], title: item.title)));
      return;
    }
    if (parts.length >= 2 && parts[0] == 'section') {
      // Home sections can't be deep-linked; show the saved description.
      showDialog<void>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(item.title),
            content: SelectableText(item.content),
            actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('داخستن'))],
          )),
      );
      return;
    }
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
      case 'reciter':
        return _FavKind(Icons.mic_rounded, 'دەنگی قورئان — کلیک بکە بۆ قاریەکان');
      case 'live':
        return _FavKind(Icons.wifi_tethering_rounded, 'پەخشی ڕاستەوخۆ — کلیک بکە');
      case 'daily_ayah':
        return _FavKind(Icons.auto_stories_rounded, 'ئایەتی ڕۆژ — کلیک بکە');
      case 'ramadan_section':
        return _FavKind(Icons.dark_mode_rounded, 'مانگی ڕەمەزان — کلیک بکە');
      case 'section':
        return _FavKind(Icons.category_rounded, 'بەش — وردەکاری');
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
