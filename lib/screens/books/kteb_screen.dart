import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/downloader.dart';
import '../pdf/pdf_screen.dart';

/// Original: MeoActivity (کتێبخانە) — the book grid comes from the online
/// ktebakan.json that MainActivity fetches and stores in pref "onlybookme";
/// offline it falls back to the last cached copy, then to the bundled
/// snapshot. Tapping a book opens the BookActivity detail (ناوی کتێب، کورتە،
/// نوسەر، خوێندنەوەی کتێب); books can be downloaded for offline reading,
/// filtered to دابگیراوەکان and searched, with the PDF reader opening the
/// local copy first.
class KtebScreen extends StatefulWidget {
  const KtebScreen({super.key});
  @override
  State<KtebScreen> createState() => _KtebScreenState();
}

class _KtebScreenState extends State<KtebScreen> {
  static const onlineUrl =
      'https://github.com/quranofficial/ktebakan/raw/main/ktebakan.json';
  List<Map<String, dynamic>> _books = [];
  final Set<String> _downloadedUrls = {};
  bool _loading = true;
  bool _onlyDownloaded = false;
  String _q = '';

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
    final downloaded = <String>{};
    for (final b in rows) {
      final url = '${b['url'] ?? ''}'.trim();
      final cached = AppPrefs.I.pdfCachePath(url);
      if (cached != null && cached.isNotEmpty && File(cached).existsSync()) {
        downloaded.add(url);
      }
    }
    if (mounted) {
      setState(() {
        _books = rows;
        _downloadedUrls
          ..clear()
          ..addAll(downloaded);
        _loading = false;
      });
    }
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

  List<Map<String, dynamic>> get _filtered {
    var rows = _books;
    if (_onlyDownloaded) {
      rows = rows.where((b) => _downloadedUrls.contains('${b['url'] ?? ''}')).toList();
    }
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((b) =>
              '${b['name'] ?? ''}'.toLowerCase().contains(q) ||
              '${b['admin'] ?? ''}'.toLowerCase().contains(q) ||
              '${b['about'] ?? ''}'.toLowerCase().contains(q))
          .toList();
    }
    return rows;
  }

  void _openBook(Map<String, dynamic> b) async {
    final url = '${b['url'] ?? ''}'.trim();
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => _BookDetailScreen(
            book: b, url: url, downloaded: _downloadedUrls.contains(url))));
    if (mounted) {
      final cached = AppPrefs.I.pdfCachePath(url);
      final isDl = cached != null &&
          cached.isNotEmpty &&
          File(cached).existsSync();
      setState(() {
        if (isDl) {
          _downloadedUrls.add(url);
        } else {
          _downloadedUrls.remove(url);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
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
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v),
                        decoration: InputDecoration(
                          hintText: 'گەڕان لە کتێبەکان (ناو یان نوسەر)...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: card,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(children: [
                        FilterChip(
                            selected: !_onlyDownloaded,
                            label: Text('هەموو کتێبەکان (${_books.length})',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: !_onlyDownloaded ? Colors.white : txt)),
                            selectedColor: AppColors.primaryDark,
                            onSelected: (_) =>
                                setState(() => _onlyDownloaded = false)),
                        const SizedBox(width: 8),
                        FilterChip(
                            selected: _onlyDownloaded,
                            label: Text(
                                'دابگیراوەکان (${_downloadedUrls.length})',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _onlyDownloaded ? Colors.white : txt)),
                            selectedColor: AppColors.primaryDark,
                            onSelected: (_) =>
                                setState(() => _onlyDownloaded = true)),
                      ]),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(child: Text('هیچ کتێبێک نەدۆزرایەوە',
                              style: TextStyle(color: txt.withOpacity(.5))))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: .62),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final b = _filtered[i];
                                final img = '${b['image'] ?? ''}'.trim();
                                final downloaded = _downloadedUrls
                                    .contains('${b['url'] ?? ''}');
                                return InkWell(
                                  onTap: () => _openBook(b),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: card,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: dark
                                                ? Colors.white10
                                                : Colors.black12)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(14)),
                                              child: Stack(fit: StackFit.expand,
                                                  children: [
                                                    img.startsWith('http')
                                                        ? Image.network(img,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __,
                                                                    ___) =>
                                                                Container(
                                                                    color: AppColors
                                                                        .primaryDark
                                                                        .withOpacity(
                                                                            .08),
                                                                    child: const Icon(
                                                                        Icons
                                                                            .menu_book_rounded,
                                                                        size: 40,
                                                                        color: AppColors
                                                                            .primaryDark)))
                                                        : Container(
                                                            color: AppColors
                                                                .primaryDark
                                                                .withOpacity(.08),
                                                            child: const Icon(
                                                                Icons
                                                                    .menu_book_rounded,
                                                                size: 40,
                                                                color: AppColors
                                                                    .primaryDark)),
                                                    if (downloaded)
                                                      Positioned(
                                                          top: 6,
                                                          right: 6,
                                                          child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: AppColors
                                                                    .primaryDark,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: const Icon(
                                                                  Icons
                                                                      .offline_pin_rounded,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .white))),
                                                  ]),
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
                                                    Text(
                                                        '${b['name'] ?? 'کتێب'}',
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: txt)),
                                                    const Spacer(),
                                                    Text('${b['admin'] ?? ''}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: txt
                                                                .withOpacity(
                                                                    .55))),
                                                  ]),
                                            ),
                                          ),
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
}

/// Original: BookActivity — book detail (ناوی کتێب / کورتە / نوسەر) with the
/// خوێندنەوەی کتێب button opening the PDF reader and a داگرتن button that
/// stores the book for offline reading.
class _BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  final String url;
  final bool downloaded;
  const _BookDetailScreen(
      {required this.book, required this.url, this.downloaded = false});
  @override
  State<_BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<_BookDetailScreen> {
  bool _downloading = false;
  int _progress = 0;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _downloaded = widget.downloaded;
  }

  Future<void> _download() async {
    if (_downloading || widget.url.isEmpty) return;
    setState(() { _downloading = true; _progress = 0; });
    try {
      final file = await Downloader.download(
          widget.url, 'ktebakan/${Downloader.safeName(widget.book['name'] ?? 'kteb')}.pdf',
          onProgress: (received, total) {
            if (mounted) {
              setState(() => _progress = (received / total * 100).round());
            }
          });
      AppPrefs.I.setPdfCachePath(widget.url, file.path);
      if (!mounted) return;
      setState(() { _downloaded = true; _downloading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('کتێبەکە دابگیرا — بە بێ ئینتەرنێت دەکرێتەوە ✅')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('داگرتن سەرکەوتوو نەبوو — تکایە دووبارە هەوڵبدەرەوە')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final img = '${widget.book['image'] ?? ''}'.trim();
    final b = widget.book;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text('${b['name'] ?? 'کتێب'}',
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                onPressed: () => Share.share(
                    '${b['name'] ?? ''}\n${b['url'] ?? ''}\n\n#ڕێگای ئیسلام'),
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
          Text('${b['name'] ?? ''}',
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 17, color: txt)),
          const SizedBox(height: 12),
          Text('کورتە',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: txt.withOpacity(.55))),
          const SizedBox(height: 4),
          Text('${b['about'] ?? 'ئەم کتێبە هیچ کورتەیەکی لەسەر نەنوسراوە'}',
              style: TextStyle(fontSize: 14, height: 1.7, color: txt)),
          const SizedBox(height: 12),
          Text('نوسەر',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: txt.withOpacity(.55))),
          const SizedBox(height: 4),
          Text('${b['admin'] ?? ''}',
              style: TextStyle(fontSize: 14, color: txt)),
          const SizedBox(height: 20),
          if (_downloading)
            Column(children: [
              LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor:
                      AppColors.primaryDark.withOpacity(.15),
                  color: AppColors.primaryDark),
              const SizedBox(height: 8),
              Text('داگرتن... $_progress%',
                  style: TextStyle(fontSize: 12, color: txt)),
            ]),
          if (!_downloading)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: BorderSide(
                      color: AppColors.primaryDark.withOpacity(.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11)),
              onPressed: _downloaded ? null : _download,
              icon: Icon(_downloaded
                  ? Icons.offline_pin_rounded
                  : Icons.download_rounded),
              label: Text(_downloaded
                  ? 'دابگیراوە ✓ (بۆ ئۆفلاین)'
                  : 'داگرتن بۆ خوێندنەوەی ئۆفلاین'),
            ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: widget.url.isEmpty
                ? null
                : () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PdfScreen(
                        title: '${b['name'] ?? 'کتێب'}', url: widget.url))),
            icon: const Icon(Icons.auto_stories_rounded),
            label: const Text('خوێندنەوەی کتێب'),
          ),
          const SizedBox(height: 8),
          if (widget.url.isEmpty)
            Center(child: Text('لینکی کتێب بەردەست نییە',
                style: TextStyle(fontSize: 12, color: txt.withOpacity(.5)))),
        ]),
      ),
    );
  }
}
