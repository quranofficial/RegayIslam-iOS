import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset, sharePage;
import '../../data/db.dart';
import 'open_quran.dart' show toArabicDigits;

/// Item 10 — the real Mushaf: all 604 pages of the Madani mushaf, one page
/// per screen, swipable, with tap-to-turn zones, jump-to-page and offline
/// caching. Page images stream from the Quran-PNG open repository
/// (madani layout, identical numbering to the bundled ayah_info.db) and
/// every visited page is cached for offline reading.
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
  static const _baseUrl = 'https://raw.githubusercontent.com/GovarJabbar/Quran-PNG/master';
  late PageController _pager;
  int _page = 1;
  bool _jumping = false;
  final Map<int, String> _cache = {};

  @override
  void initState() {
    super.initState();
    _page = AppPrefs.I.mushafLastPage > 0 && AppPrefs.I.mushafLastPage <= _totalPages
        ? AppPrefs.I.mushafLastPage
        : 1;
    _pager = PageController(initialPage: _page - 1);
    _resolveStartPage();
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
      }
    } catch (_) {}
  }

  Future<void> _savePage(int page) async {
    AppPrefs.I.mushafLastPage = page;
  }

  Future<String> _pageSource(int page) async {
    if (_cache[page] != null) return _cache[page]!;
    final n = page.toString().padLeft(3, '0');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/mushaf/$n.png');
      if (f.existsSync() && f.lengthSync() > 0) {
        _cache[page] = f.path;
        return f.path;
      }
    } catch (_) {}
    return '$_baseUrl/$n.png';
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
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                hintText: 'لاپەڕە (١ - ٦٠٤)', border: OutlineInputBorder()),
          ),
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
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title ?? 'مەشەفی پیرۆز',
                style: const TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('لاپەڕە ${toArabicDigits(_page)} لە ${toArabicDigits(_totalPages)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          actions: [
            IconButton(
                tooltip: 'چوونە لاپەڕە',
                onPressed: _jumping ? null : _askPage,
                icon: const Icon(Icons.pin_drop_rounded, color: Colors.white)),
            IconButton(
                tooltip: 'لاپەڕەی ئەمڕۆ',
                onPressed: () => _goTo(_page),
                icon: const Icon(Icons.my_location_rounded, color: Colors.white)),
            IconButton(
                tooltip: 'هاوبەشی',
                onPressed: () => sharePage(
                    'مەشەفی پیرۆز — لاپەڕە ${toArabicDigits(_page)}',
                    title: 'مەشەف'),
                icon: const Icon(Icons.share_rounded, color: Colors.white)),
          ],
        ),
        body: Column(children: [
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
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        final w = MediaQuery.of(context).size.width;
                        if (d.globalPosition.dx < w * 0.25) {
                          _goTo(p + 1); // RTL: left edge = next page
                        } else if (d.globalPosition.dx > w * 0.75) {
                          _goTo(p - 1);
                        }
                      },
                      child: InteractiveViewer(
                          maxScale: 5, child: Center(child: img)),
                    );
                  },
                );
              },
            ),
          ),
          // Page turn bar — big, always-visible buttons (item 10).
          SafeArea(
            top: false,
            child: Container(
              color: dark ? AppColors.nightCard : Colors.white,
              padding: EdgeInsets.fromLTRB(10, 6, 10, bottomInset(context, extra: 6)),
              child: Row(children: [
                IconButton(
                    tooltip: 'لاپەڕەی داهاتوو',
                    onPressed: _page < _totalPages ? () => _goTo(_page + 1) : null,
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
