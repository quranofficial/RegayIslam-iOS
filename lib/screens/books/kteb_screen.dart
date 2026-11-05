import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../pdf/pdf_screen.dart';

/// Original: MeoActivity (کتێبخانە) — the book grid comes from the online
/// ktebakan.json that MainActivity fetches and stores in pref "onlybookme";
/// offline it falls back to the last cached copy, then to the bundled
/// snapshot. Tapping a book opens the BookActivity detail (ناوی کتێب، کورتە،
/// نوسەر، خوێندنەوەی کتێب) and the PDF reader.
class KtebScreen extends StatefulWidget {
  const KtebScreen({super.key});
  @override
  State<KtebScreen> createState() => _KtebScreenState();
}

class _KtebScreenState extends State<KtebScreen> {
  static const onlineUrl =
      'https://github.com/quranofficial/ktebakan/raw/main/ktebakan.json';
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ktebakan.json');
  }

  Future<void> _load() async {
    var rows = <Map<String, dynamic>>[];
    // 1) pref "onlybookme" — the last fetched copy (MainActivity behaviour)
    rows = _parse(AppPrefs.I.libraryJson);
    // 2) file cache, 3) bundled snapshot
    if (rows.isEmpty) {
      try {
        final f = await _cacheFile;
        if (f.existsSync()) rows = _parse(f.readAsStringSync());
      } catch (_) {}
    }
    if (rows.isEmpty) {
      try {
        rows = _parse(await rootBundle.loadString('assets/data/ktebakan.json'));
      } catch (_) {}
    }
    if (mounted) setState(() { _books = rows; _loading = false; });
    // 4) refresh from the network and re-cache
    try {
      final r = await http.get(Uri.parse(onlineUrl),
          headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final fresh = _parse(r.body);
        if (fresh.isNotEmpty && mounted) {
          AppPrefs.I.libraryJson = r.body;
          try {
            final f = await _cacheFile;
            f.writeAsStringSync(r.body, flush: true);
          } catch (_) {}
          setState(() => _books = fresh);
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _parse(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  void _openBook(Map<String, dynamic> b) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _BookDetailScreen(
            book: b, url: '${b['url'] ?? ''}'.trim())));
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
          title: const Text('کتێبخانە',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? Center(child: Text('کتێبێک بەردەست نییە',
                    style: TextStyle(color: txt.withOpacity(.6))))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: .62),
                    itemCount: _books.length,
                    itemBuilder: (context, i) {
                      final b = _books[i];
                      final img = '${b['image'] ?? ''}'.trim();
                      return InkWell(
                        onTap: () => _openBook(b),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                              color: dark ? AppColors.nightCard : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: dark
                                      ? Colors.white10
                                      : Colors.black12)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                    child: img.startsWith('http')
                                        ? Image.network(img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    color: AppColors
                                                        .primaryDark
                                                        .withOpacity(.08),
                                                    child: const Icon(
                                                        Icons.menu_book_rounded,
                                                        size: 40,
                                                        color: AppColors
                                                            .primaryDark)))
                                        : Container(
                                            color: AppColors.primaryDark
                                                .withOpacity(.08),
                                            child: const Icon(
                                                Icons.menu_book_rounded,
                                                size: 40,
                                                color: AppColors.primaryDark)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${b['name'] ?? 'کتێب'}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13, color: txt)),
                                          const Spacer(),
                                          Text('${b['admin'] ?? ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: txt.withOpacity(.55))),
                                        ]),
                                  ),
                                ),
                              ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Original: BookActivity — book detail (ناوی کتێب / کورتە / نوسەر) with the
/// خوێندنەوەی کتێب button opening the PDF reader.
class _BookDetailScreen extends StatelessWidget {
  final Map<String, dynamic> book;
  final String url;
  const _BookDetailScreen({required this.book, required this.url});

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final img = '${book['image'] ?? ''}'.trim();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text('${book['name'] ?? 'کتێب'}',
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                onPressed: () => Share.share(
                    '${book['name'] ?? ''}\n${book['url'] ?? ''}\n\n#ڕێگای ئیسلام'),
                icon: const Icon(Icons.share_rounded, color: Colors.white)),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: AspectRatio(
                  aspectRatio: .72,
                  child: img.startsWith('http')
                      ? Image.network(img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primaryDark.withOpacity(.08),
                              child: const Icon(Icons.menu_book_rounded,
                                  size: 48, color: AppColors.primaryDark)))
                      : Container(
                          color: AppColors.primaryDark.withOpacity(.08),
                          child: const Icon(Icons.menu_book_rounded,
                              size: 48, color: AppColors.primaryDark)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('ناوی کتێب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: txt.withOpacity(.55))),
          const SizedBox(height: 4),
          Text('${book['name'] ?? ''}',
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 17, color: txt)),
          const SizedBox(height: 12),
          Text('کورتە',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: txt.withOpacity(.55))),
          const SizedBox(height: 4),
          Text('${book['about'] ?? 'ئەم کتێبە هیچ کورتەیەکی لەسەر نەنوسراوە'}',
              style: TextStyle(fontSize: 14, height: 1.7, color: txt)),
          const SizedBox(height: 12),
          Text('نوسەر',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: txt.withOpacity(.55))),
          const SizedBox(height: 4),
          Text('${book['admin'] ?? ''}',
              style: TextStyle(fontSize: 14, color: txt)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: url.isEmpty
                ? null
                : () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PdfScreen(
                        title: '${book['name'] ?? 'کتێب'}', url: url))),
            icon: const Icon(Icons.auto_stories_rounded),
            label: const Text('خوێندنەوەی کتێب'),
          ),
          const SizedBox(height: 8),
          if (url.isEmpty)
            Center(child: Text('لینکی کتێب بەردەست نییە',
                style: TextStyle(fontSize: 12, color: txt.withOpacity(.5)))),
        ]),
      ),
    );
  }
}
