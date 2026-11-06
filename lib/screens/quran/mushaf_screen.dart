import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset, sharePage, suraLabel;
import '../../data/db.dart';
import 'open_quran.dart' show toArabicDigits;

/// Item 10 — the real Mushaf: all 604 pages of the Madani mushaf, one page
/// per screen, swipable, with WORKING tap-to-turn zones, jump-to-page,
/// surah chips per page and offline caching. Page images stream from the
/// Quran-PNG open repository (madani layout, identical numbering to the
/// bundled ayah_info.db); every visited page is ALSO saved to the app
/// documents folder so the mushaf keeps working offline.
///
/// Tap zones (item 10: "لاپەڕەی مەشەف کاش ناکات"):
///   • left third  = next page  (RTL reading order)
///   • right third = previous page
///   • middle third = show/hide the tool bars
class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key, this.surahId, this.ayah, this.title});
  final int? surahId;
  final int? ayah;
  final String? title;

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  static const _totalPages = 604;
  static const _baseUrl =
      'https://raw.githubusercontent.com/GovarJabbar/Quran-PNG/master';
  late PageController _pager;
  int _page = 1;
  bool _showChrome = true;
  List<Map<String, Object?>> _pageSurahs = [];
  final Map<int, String> _cache = {};
  final Set<int> _saving = {};

  @override
  void initState() {
    super.initState();
    _page = AppPrefs.I.mushafLastPage > 0 && AppPrefs.I.mushafLastPage <= _totalPages
        ? AppPrefs.I.mushafLastPage
        : 1;
    _pager = PageController(initialPage: _page - 1);
    _resolveStartPage();
    _loadPageInfo();
  }

  /// When opened from a surah/ayah, jump to the page holding that ayah.
  Future<void> _resolveStartPage() async {
    if (widget.surahId == null) return;
    try {
      final ayah = widget.ayah ?? 1;
      final p = await Db.I.ayahPage(widget.surahId!, ayah);
      if (p != null && p >= 1 && p <= _totalPages && mounted) {
        setState(() => _page = p);
        _pager.jumpToPage(p - 1);
        _savePage(p);
        _loadPageInfo();
      }
    } catch (_) {}
  }

  Future<void> _loadPageInfo() async {
    final s = await Db.I.pageSurahs(_page);
    if (mounted) setState(() => _pageSurahs = s);
  }

  Future<void> _savePage(int page) async {
    AppPrefs.I.mushafLastPage = page;
  }

  /// Resolve the best source for a page: memory cache → offline file →
  /// URL (and persist the download for offline use in the background).
  Future<String> _pageSource(int page) async {
    if (_cache[page] != null) return _cache[page]!;
    final n = page.toString().padLeft(3, '0');
    File? f;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/mushaf');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
      f = File('${cacheDir.path}/$n.png');
      if (f.existsSync() && f.lengthSync() > 0) {
        _cache[page] = f.path;
        return f.path;
      }
    } catch (_) {}
    final url = '$_baseUrl/$n.png';
    // Download once in the background so the page is cached for offline.
    if (f != null && !_saving.contains(page)) {
      _saving.add(page);
      unawaited(() async {
        try {
          final r =
              await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
          if (r.statusCode == 200 && r.bodyBytes.lengthInBytes > 1000) {
            await f!.writeAsBytes(r.bodyBytes, flush: true);
          }
        } catch (_) {}
        _saving.remove(page);
      }());
    }
    return url;
  }

  Future<void> _cacheNeighbours(int page) async {
    for (final p in [page - 1, page + 1]) {
      if (p < 1 || p > _totalPages) continue;
      final url = await _pageSource(p);
      if (url.startsWith('http')) {
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }
    }
  }

  void _goTo(int page) {
    if (page < 1 || page > _totalPages) return;
    _pager.animateToPage(page - 1,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  Future<void> _askPage() async {
    final c = TextEditingController(text: '${_page}');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('چوونە لاپەڕە'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  hintText: 'لاپەڕە (١ - ٦٠٤)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final p in [1, 60, 120, 300, 500, 604])
                ActionChip(
                    label: Text(toArabicDigits(p),
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () => c.text = '$p'),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('لابردن')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    Navigator.pop(d, int.tryParse(c.text.trim())),
                child: const Text('بڕوان')),
          ],
        ),
      ),
    );
    if (v != null) _goTo(v.clamp(1, _totalPages));
  }

  /// Item 10: tap zones that really work — evaluated in RTL page order.
  void _onTap(TapUpDetails d, int page) {
    final w = MediaQuery.of(context).size.width;
    final x = d.globalPosition.dx;
    if (x < w * 0.33) {
      _goTo(page + 1); // left edge = next page (RTL)
    } else if (x > w * 0.67) {
      _goTo(page - 1); // right edge = previous page
    } else {
      setState(() => _showChrome = !_showChrome);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF1A1A17) : const Color(0xFFF6F1E4),
        appBar: _showChrome
            ? AppBar(
                backgroundColor:
                    dark ? AppColors.nightCard : AppColors.primaryDark,
                title: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.title ?? 'مەشەفی پیرۆز',
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(
                      'لاپەڕە ${toArabicDigits(_page)} لە ${toArabicDigits(_totalPages)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
                actions: [
                  IconButton(
                      tooltip: 'چوونە لاپەڕە',
                      onPressed: _askPage,
                      icon: const Icon(Icons.pin_drop_rounded,
                          color: Colors.white)),
                  IconButton(
                      tooltip: 'هاوبەشی',
                      onPressed: () => sharePage(
                          'مەشەفی پیرۆز — لاپەڕە ${toArabicDigits(_page)}',
                          title: 'مەشەف'),
                      icon: const Icon(Icons.share_rounded,
                          color: Colors.white)),
                ],
              )
            : null,
        body: Column(children: [
          // surah chips of the current page (hidden with the chrome)
          if (_showChrome && _pageSurahs.isNotEmpty)
            Container(
              width: double.infinity,
              color: dark ? AppColors.nightCard.withOpacity(.7) : const Color(0xFFEFE7D2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in _pageSurahs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: (dark ? AppColors.gold : AppColors.primaryDark)
                              .withOpacity(.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          '${suraLabel('${s['name'] ?? ''}')} • ئایەتی ${toArabicDigits((s['firstAyah'] as num?)?.toInt() ?? 1)}',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: dark ? AppColors.gold : AppColors.primaryDark)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pager,
              reverse: true,
              itemCount: _totalPages,
              onPageChanged: (i) {
                final p = i + 1;
                setState(() => _page = p);
                _savePage(p);
                _cacheNeighbours(p);
                _loadPageInfo();
              },
              itemBuilder: (context, i) {
                final p = i + 1;
                return FutureBuilder<String>(
                  future: _pageSource(p),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final src = snap.data!;
                    final img = src.startsWith('http')
                        ? Image.network(src,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, w, prog) => prog == null
                                ? w
                                : const Center(
                                    child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => _pageError(p))
                        : Image.file(File(src), fit: BoxFit.contain);
                    // The tap detector wraps the zoom view so single taps
                    // always reach the turn zones; pinch-zoom still works.
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTap(d, p),
                      child: InteractiveViewer(
                          maxScale: 5,
                          child: Center(child: img)),
                    );
                  },
                );
              },
            ),
          ),
          // Page turn bar — big, always-visible buttons (item 10).
          if (_showChrome)
            SafeArea(
              top: false,
              child: Container(
                color: dark ? AppColors.nightCard : Colors.white,
                padding:
                    EdgeInsets.fromLTRB(10, 6, 10, bottomInset(context, extra: 6)),
                child: Row(children: [
                  IconButton(
                      tooltip: 'لاپەڕەی داهاتوو',
                      onPressed:
                          _page < _totalPages ? () => _goTo(_page + 1) : null,
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: dark ? AppColors.gold : AppColors.primaryDark)),
                  Expanded(
                    child: Text('لاپەڕە ${toArabicDigits(_page)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: txt)),
                  ),
                  IconButton(
                      tooltip: 'لاپەڕەی پێشوو',
                      onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                      icon: Icon(Icons.arrow_forward_ios_rounded,
                          size: 20,
                          color: dark ? AppColors.gold : AppColors.primaryDark)),
                ]),
              ),
            ),
          if (!_showChrome)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset(context, extra: 6)),
                child: Center(
                  child: Text('لاپەڕە ${toArabicDigits(_page)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: txt.withOpacity(.55))),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _pageError(int p) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 40,
            color: AppColors.primaryDark.withOpacity(.6)),
        const SizedBox(height: 10),
        Text('لاپەڕە ${toArabicDigits(p)} بارنەبوو — ئینتەرنێت بپشکنە',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('دووبارە هەوڵبدەرەوە')),
      ]));
}
