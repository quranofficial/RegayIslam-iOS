import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show AudioSetup, bottomInset, copyPage, sharePage, showRepeatCountSheet, suraLabel;
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'open_quran.dart' show OpenQuranScreen, toArabicDigits;
import 'reciter_picker.dart';

/// Item 10 + item 22 — the real Mushaf: all 604 pages of the Madani mushaf,
/// one page per screen, swipable, with working tap-to-turn zones,
/// jump-to-page, surah chips per page and offline caching.
///
/// Item 22 ("دەست لە ئایەتەکان بدە و لێدانی بدە + نیشانکردنی ئایەتی لە
/// کاتی لێدان + مەشەفی جوان و فول سکرین + دۆخی شەوان دیار"):
///   • tapping ON a verse selects it (hit-tested through the real glyph
///     boxes of ayah_info.db mapped onto the page image);
///   • the selected verse can be recited from (reciter + timings, with a
///     golden highlight box that follows the recitation over the image);
///   • full-screen mode (immersive, no system bars), and in dark mode the
///     page image is inverted so the text glows white on near-black.
///   • taps OUTSIDE any verse keep the page-turn zones:
///     left third = next page (RTL), right third = previous page.
class MushafScreen extends StatefulWidget {
  const MushafScreen(
      {super.key, this.surahId, this.ayah, this.title, this.startPage});
  final int? surahId;
  final int? ayah;
  final String? title;
  final int? startPage;

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  static const _totalPages = 604;
  static const _baseUrl =
      'https://raw.githubusercontent.com/GovarJabbar/Quran-PNG/master';
  /// The page images are 2600 × 4206 while ayah_info.db stores line boxes
  /// in the 1246 × 2031 mushaf space — verified against the real pages.
  static const _imgW = 2600.0, _imgH = 4206.0;
  static const _dbW = 1246.0, _dbH = 2031.0;
  static const _sx = _imgW / _dbW, _sy = _imgH / _dbH;

  late PageController _pager;
  late TransformationController _transform;
  int _page = 1;
  bool _showChrome = true;
  bool _fullscreen = false;
  List<Map<String, Object?>> _pageSurahs = [];
  List<Map<String, Object?>> _pageLines = [];
  final Map<int, String> _cache = {};
  final Set<int> _saving = {};
  final Map<int, String> _surahNames = {};
  final Map<int, int> _surahAyat = {};

  // selected / reciting ayah on the CURRENT page
  int? _selSurah;
  int? _selAyah;
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Map<String, int> _timings = {};
  bool _ayahByAyah = false;
  String? _reciterLabel;

  // --- playback robustness (the mushaf recitation used to look "stuck" on
  // one page: streams died mid-surah, the highlight vanished when the
  // recitation crossed to the next page and nothing ever recovered).
  // Now: readiness-wait before seek, watchdog + premature-stop recovery
  // that downloads the file and continues, and AUTO PAGE-FLIP — when the
  // recited verse lives on another page the mushaf turns itself there and
  // the golden highlight keeps following.
  int _lastPosMs = 0;
  int _lastDurMs = 0;
  DateTime _lastAdvance = DateTime.now();
  bool _recovering = false;
  bool _postChecking = false;
  int _recoverTries = 0;
  Timer? _stall;
  // item 12: repeat each ayah 1/3/5/10 times before moving on
  int _repeatLeft = 1;
  bool _reseeking = false;
  bool _flipping = false; // auto page-flip in progress

  // item 10: bulk download of the 604 mushaf pages for offline use.
  bool _dlPages = false;
  int _dlDone = 0;
  bool _dlCancel = false;

  @override
  void initState() {
    super.initState();
    final sp = widget.startPage ?? 0;
    _page = (sp >= 1 && sp <= _totalPages)
        ? sp
        : (AppPrefs.I.mushafLastPage > 0 &&
                AppPrefs.I.mushafLastPage <= _totalPages
            ? AppPrefs.I.mushafLastPage
            : 1);
    _transform = TransformationController();
    _pager = PageController(initialPage: _page - 1);
    AudioSetup.prepare(_player);
    _loadSurahMeta();
    _resolveStartPage();
    _loadPageInfo();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if ((s == PlayerState.completed || s == PlayerState.stopped) &&
          !_ayahByAyah && !_recovering) {
        _postStopCheck(); // natural end vs premature death
      }
    });
    _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _lastDurMs = d.inMilliseconds;
    });
    _player.onPositionChanged.listen((p) {
      if (p.inMilliseconds > _lastPosMs) {
        _lastPosMs = p.inMilliseconds;
        _lastAdvance = DateTime.now();
      }
      _followTimings(p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      // per-ayah fallback: repeat, then advance to the next verse
      if (_ayahByAyah && _selAyah != null && _selSurah != null) {
        if (_repeatLeft > 1) {
          _repeatLeft--;
          _playAyahFile(_selAyah!);
          return;
        }
        _repeatLeft = AppPrefs.I.ayahRepeat;
        final next = _selAyah! + 1;
        final maxAyah = _surahAyat[_selSurah] ?? 0;
        if (maxAyah == 0 || next <= maxAyah) {
          _playAyahFile(next);
          return;
        }
      }
      setState(() => _state = PlayerState.stopped);
    });
    _stall = Timer.periodic(const Duration(seconds: 4), (_) => _watchdogTick());
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

  Future<void> _loadPageInfo({(int, int)? keep}) async {
    final s = await Db.I.pageSurahs(_page);
    final l = await Db.I.pageAyahLines(_page);
    if (!mounted) return;
    setState(() {
      _pageSurahs = s;
      _pageLines = l;
      // keep = auto page-flip while reciting — the selection survives the
      // page change so the golden highlight continues on the new page.
      _selSurah = keep?.$1;
      _selAyah = keep?.$2;
    });
    _timings = await Db.I.timings(AppPrefs.I.qariId);
    _reciterLabel = AppPrefs.I.qariName;
  }

  Future<void> _loadSurahMeta() async {
    try {
      final rows = await Db.I.surahs();
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          final id = (r['soraid'] as num?)?.toInt() ?? 0;
          _surahNames[id] = suraLabel('${r['name'] ?? ''}');
          _surahAyat[id] = (r['aya'] as num?)?.toInt() ?? 0;
        }
      });
    } catch (_) {}
  }

  String _surahLabel(int id) => _surahNames[id] ?? 'سورە $id';

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
      if (url.startsWith('http') && mounted) {
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

  // ---------------------------------------------------------------------
  // item 10: داگرتنی لاپەڕەکانی مەشەف بۆ ئۆفلاین — the whole 604-page
  // mushaf (~75 MB) downloaded into the same cache dir the viewer already
  // reads, with progress + cancel. Pages already on disk are skipped, so
  // an interrupted run resumes where it stopped.
  // ---------------------------------------------------------------------

  Future<int> _cachedPageCountAsync() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/mushaf');
      if (!d.existsSync()) return 0;
      return d
          .listSync()
          .whereType<File>()
          .where((f) => f.lengthSync() > 1000)
          .length;
    } catch (_) {
      return 0;
    }
  }

  /// The download sheet: shows how many pages are already offline, a start
  /// button, live progress (n/604 + bar) and a cancel that stops safely.
  Future<void> _downloadPagesDialog() async {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    var have = await _cachedPageCountAsync();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (d, setD) => AlertDialog(
            title: Row(children: [
              Icon(Icons.download_for_offline_rounded, size: 22, color: accent),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('داگرتنی لاپەڕەکانی مەشەف',
                      style: TextStyle(fontSize: 16, color: txt))),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  _dlPages
                      ? 'دەداگیرێت… ${toArabicDigits(_dlDone)} لە ${toArabicDigits(_totalPages)}'
                      : 'لاپەڕە داگیراوەکان: ${toArabicDigits(have)} لە '
                          '${toArabicDigits(_totalPages)}\n'
                          'پاش داگرتن مەشەف بێ ئینتەرنێت کاردەکات.',
                  style: TextStyle(fontSize: 13, height: 1.8, color: txt)),
              const SizedBox(height: 12),
              if (_dlPages) ...[
                LinearProgressIndicator(
                    value: _totalPages > 0 ? _dlDone / _totalPages : 0,
                    color: accent,
                    backgroundColor: txt.withOpacity(.1)),
                const SizedBox(height: 8),
                Text('${((_dlDone / _totalPages) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.bold, color: accent)),
              ] else
                Text('~٧٥ مێگابایت — پەیوەندی WiFi پێشنیار کراوە',
                    style: TextStyle(
                        fontSize: 11.5, color: txt.withOpacity(.6))),
            ]),
            actions: [
              if (!_dlPages)
                TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('لابردن')),
              if (_dlPages)
                TextButton(
                    onPressed: () => _dlCancel = true,
                    child: const Text('وەستان')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: dark ? Colors.black : Colors.white),
                onPressed: _dlPages
                    ? null
                    : () async {
                        setD(() => _dlPages = true);
                        _dlCancel = false;
                        _dlDone = have;
                        final failed = await _downloadAllPages(
                            onProgress: (done) {
                          _dlDone = done;
                          setD(() {});
                        }, shouldStop: () => _dlCancel);
                        _dlPages = false;
                        if (!d.mounted) return;
                        Navigator.pop(d);
                        have = await _cachedPageCountAsync();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(_dlCancel
                                ? 'داگرتن وەستێنرا — ${toArabicDigits(have)} لاپەڕە داگیراوە'
                                : failed > 0
                                    ? 'تەواو — ${toArabicDigits(have)} داگیراو، '
                                        '${toArabicDigits(failed)} نەهاتن — دووبارە هەوڵبدەرەوە'
                                    : 'تەواو بوو ✅ ${toArabicDigits(have)} '
                                        'لاپەڕە بەردەستن بۆ ئۆفلاین')));
                      },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(have >= _totalPages
                    ? 'پشکنینەوە'
                    : 'داگرتنی هەموو لاپەڕەکان'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Downloads every missing page (4 in parallel, already-downloaded pages
  /// skipped). Returns the number of pages that could not be fetched.
  Future<int> _downloadAllPages(
      {void Function(int done)? onProgress,
      bool Function()? shouldStop}) async {
    final dir = await getApplicationDocumentsDirectory();
    final cache = Directory('${dir.path}/mushaf');
    if (!cache.existsSync()) cache.createSync(recursive: true);
    final missing = <int>[];
    for (var p = 1; p <= _totalPages; p++) {
      final f = File('${cache.path}/${p.toString().padLeft(3, '0')}.png');
      if (!f.existsSync() || f.lengthSync() < 1000) missing.add(p);
    }
    var done = _totalPages - missing.length;
    var failed = 0;
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (shouldStop?.call() ?? false) return;
        final i = cursor++;
        if (i >= missing.length) return;
        final p = missing[i];
        try {
          await Downloader.download('$_baseUrl/${p.toString().padLeft(3, '0')}.png',
              'mushaf/${p.toString().padLeft(3, '0')}.png',
              timeout: const Duration(seconds: 60));
        } catch (_) {
          failed++;
        }
        done++;
        onProgress?.call(done);
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    return failed;
  }

  // ---------------------------------------------------------------------------
  // item 22: tap → ayah hit-testing on the real glyph boxes
  // ---------------------------------------------------------------------------

  /// Convert a tap (local position inside the viewer) into the mushaf db
  /// space, then find the verse whose line box contains it.
  (int, int)? _hitAyah(Offset local, Size viewport) {
    if (_pageLines.isEmpty) return null;
    // 1) undo the InteractiveViewer zoom/pan
    final m = Matrix4.inverted(_transform.value);
    final childPt = MatrixUtils.transformPoint(m, local);
    // 2) the image is centered with BoxFit.contain inside the viewport
    final scale = math.min(viewport.width / _imgW,
        viewport.height / _imgH);
    final fittedW = _imgW * scale, fittedH = _imgH * scale;
    final dx = (viewport.width - fittedW) / 2;
    final dy = (viewport.height - fittedH) / 2;
    final imgX = (childPt.dx - dx) / scale;
    final imgY = (childPt.dy - dy) / scale;
    if (imgX < 0 || imgY < 0 || imgX > _imgW || imgY > _imgH) {
      return null;
    }
    // 3) image pixels → mushaf db space
    final dbX = imgX / _sx, dbY = imgY / _sy;
    // 4) hit-test the line boxes (a little padding for easy tapping)
    const pad = 26.0;
    (int, int)? best;
    double bestDist = double.infinity;
    for (final l in _pageLines) {
      final x0 = (l['min_x'] as num).toDouble() - pad;
      final x1 = (l['max_x'] as num).toDouble() + pad;
      final y0 = (l['min_y'] as num).toDouble() - pad;
      final y1 = (l['max_y'] as num).toDouble() + pad;
      if (dbX >= x0 && dbX <= x1 && dbY >= y0 && dbY <= y1) {
        // inside this box — prefer the box whose centre is closest
        final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
        final ddx = dbX - cx, ddy = dbY - cy;
        final dist = ddx * ddx + ddy * ddy;
        if (dist < bestDist) {
          bestDist = dist;
          best = ((l['surah_id'] as num).toInt(),
              (l['verse_id'] as num).toInt());
        }
      }
    }
    return best;
  }

  void _onTap(TapUpDetails d, int page, Size viewport) {
    final hit = _hitAyah(d.localPosition, viewport);
    if (hit != null) {
      setState(() { _selSurah = hit.$1; _selAyah = hit.$2; });
      _showAyahActions(hit.$1, hit.$2);
      return;
    }
    final w = viewport.width;
    final x = d.globalPosition.dx;
    if (x < w * 0.30) {
      _goTo(page + 1); // left edge = next page (RTL)
    } else if (x > w * 0.70) {
      _goTo(page - 1); // right edge = previous page
    } else {
      setState(() => _showChrome = !_showChrome);
    }
  }

  /// The action sheet for a tapped verse (item 22).
  Future<void> _showAyahActions(int surahId, int ayah) async {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    await showModalBottomSheet(
      context: context,
      backgroundColor: dark ? AppColors.nightCard : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                  '${_surahLabel(surahId)} — ئایەتی ${toArabicDigits(ayah)}',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: txt)),
              const SizedBox(height: 6),
              Text('ئایەتەکە هەڵبژێردرا — چی بکەم؟',
                  style: TextStyle(fontSize: 12,
                      color: txt.withOpacity(.55))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _action(c, Icons.play_circle_rounded, 'لێدان لەم ئایەتەوە',
                    dark, () async {
                  Navigator.pop(c);
                  await _reciteFromAyah(surahId, ayah);
                }),
                _action(c, Icons.menu_book_rounded, 'خوێندنەوە', dark, () async {
                  Navigator.pop(c);
                  await _openInReader(surahId, ayah);
                }),
                _action(c, Icons.bookmark_rounded, 'دڵخواز', dark, () async {
                  Navigator.pop(c);
                  _favoriteAyah(surahId, ayah);
                }),
                _action(c, Icons.copy_rounded, 'کۆپی', dark, () async {
                  Navigator.pop(c);
                  _copyAyah(surahId, ayah);
                }),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext c, IconData icon, String label, bool dark,
      VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 28,
                color: dark ? AppColors.gold : AppColors.primaryDark),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11,
                color: dark ? Colors.white : Colors.black87)),
          ]),
        ),
      );

  /// item 1+6: the mushaf recite bar repeat — same count sheet as the
  /// reader's ayah rows. 0 = بێسنوور (infinite).
  Future<void> _pickRepeatCount() async {
    final dark = !AppPrefs.I.day;
    final n = await showRepeatCountSheet(context,
        dark: dark,
        title: 'دووبارەکردنەوەی هەر ئایەتێک',
        subtitle: 'هەر ئایەتێک ئەم ژمارەیە دووبارە دەکرێتەوە پێش چوون بۆ داهاتوو');
    if (n == null || !mounted) return;
    setState(() {
      _repeatLeft = n == 0 ? (1 << 30) : n;
      if (n >= 1) AppPrefs.I.ayahRepeat = n;
    });
  }

  String _repeatBadge() {
    if (_repeatLeft >= (1 << 29)) return '∞';
    if (_repeatLeft > 1) return '${toArabicDigits(_repeatLeft)}×';
    return '';
  }

  /// Recite from the tapped verse: prefer the selected reciter's own surah
  /// audio seeked through its timings db (the highlight follows position);
  /// fall back to per-ayah files (each verse highlighted in turn).
  Future<void> _reciteFromAyah(int surahId, int ayah) async {
    final startMs = _timings['$surahId:$ayah'];
    if (startMs != null && startMs > 0) {
      setState(() { _ayahByAyah = false; _selAyah = ayah; _selSurah = surahId; });
      // stream first (instant) — the seek waits for the source to be ready;
      // if that fails, the fully downloaded file is bullet-proof.
      final ok = await _playSurahStreamed(surahId, startMs);
      if (ok) return;
      final local = await _playSurahLocal(surahId, startMs, notify: true);
      if (local) return;
    }
    setState(() { _ayahByAyah = true; _selAyah = ayah; _selSurah = surahId; });
    _repeatLeft = AppPrefs.I.ayahRepeat;
    await _playAyahFile(ayah);
  }

  /// Streamed surah playback with a readiness wait before the seek —
  /// seeking a still-buffering network source used to kill playback after
  /// 2-3 ayahs.
  Future<bool> _playSurahStreamed(int surahId, int startMs) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(Downloader.httpsify(_surahAudioUrl(surahId))));
      var dur = 0;
      for (var i = 0; i < 16 && dur <= 0; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try { dur = (await _player.getDuration())?.inMilliseconds ?? 0; }
        catch (_) { dur = 0; }
      }
      await _player.seek(Duration(milliseconds: startMs));
      if (!mounted) return true;
      _lastPosMs = startMs;
      _lastDurMs = dur;
      _lastAdvance = DateTime.now();
      _recoverTries = 0;
      _repeatLeft = AppPrefs.I.ayahRepeat;
      setState(() {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bullet-proof local playback — download the full mp3 first, then play
  /// and seek. Local files never stall mid-stream.
  Future<bool> _playSurahLocal(int surahId, int startMs, {bool notify = false}) async {
    try {
      File? f = await _cachedSurahAudio(surahId);
      if (f == null) {
        if (notify && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('دەنگ داگیر دەکرێت — چەند چرکەیەک...'),
              duration: Duration(seconds: 2)));
        }
        f = await Downloader.download(
            Downloader.httpsify(_surahAudioUrl(surahId)),
            'quran_audio/${Downloader.safeName(AppPrefs.I.qariId)}_'
            '${surahId.toString().padLeft(3, '0')}.mp3',
            timeout: const Duration(minutes: 5));
      }
      await _player.stop();
      await _player.play(DeviceFileSource(f.path));
      await _player.seek(Duration(milliseconds: startMs));
      if (!mounted) return true;
      _lastPosMs = startMs;
      _lastDurMs = 0;
      _lastAdvance = DateTime.now();
      _recoverTries = 0;
      _repeatLeft = AppPrefs.I.ayahRepeat;
      setState(() {});
      return true;
    } catch (_) {
      return false;
    }
  }

  String _surahAudioUrl(int surahId) {
    final base = AppPrefs.I.qariUrl;
    final n = surahId.toString().padLeft(3, '0');
    return base.endsWith('/') ? '$base$n.mp3' : '$base/$n.mp3';
  }

  Future<File?> _cachedSurahAudio(int surahId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/quran_audio/'
          '${Downloader.safeName(AppPrefs.I.qariId)}_'
          '${surahId.toString().padLeft(3, '0')}.mp3');
      if (f.existsSync() && f.lengthSync() > 0) {
        // partial downloads die at the same spot forever — drop tiny files
        if (f.lengthSync() < 150000) {
          try { f.deleteSync(); } catch (_) {}
          return null;
        }
        return f;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playAyahFile(int ayah) async {
    if (_selSurah == null || ayah <= 0) return;
    try {
      await _player.stop();
      if (mounted) setState(() => _selAyah = ayah);
      final g = await Db.I.globalAyah(_selSurah!, ayah);
      final url = Downloader.httpsify(
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3');
      await _player.play(UrlSource(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە پەخشکردنی دەنگی ئەم ئایەتە')));
      }
    }
  }

  Future<void> _openInReader(int surahId, int ayah) async {
    try {
      final s = (await Db.I.surahs())
          .where((r) => (r['soraid'] as num?)?.toInt() == surahId)
          .toList();
      if (!mounted || s.isEmpty) return;
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => OpenQuranScreen(
              surahId: surahId,
              surahName: '${s.first['name'] ?? ''}',
              ayaCount: (s.first['aya'] as num?)?.toInt() ?? 7,
              place: '${s.first['place'] ?? ''}',
              juz: '${s.first['juz'] ?? ''}',
              initialAyah: ayah,
              highlightAyah: ayah)));
    } catch (_) {}
  }

  Future<void> _favoriteAyah(int surahId, int ayah) async {
    try {
      final rows = await Db.I.ayat(surahId, AppPrefs.I.tafsir);
      final row = rows
          .where((r) => (r['ayah'] as num?)?.toInt() == ayah)
          .toList();
      final text = row.isEmpty ? '' : '${row.first['text'] ?? ''}';
      final tafsir = row.isEmpty ? '' : '${row.first[AppPrefs.I.tafsir] ?? ''}';
      await FavoritesStore.add(FavoriteEntry(
          id: 'quran::$surahId::$ayah',
          title: '${_surahLabel(surahId)} • ئایەتی ${toArabicDigits(ayah)}',
          content: '$text\n\n$tafsir',
          route: 'quran::$surahId::$ayah'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('زیادکرا بۆ دڵخوازەکان ❤️')));
    } catch (_) {}
  }

  Future<void> _copyAyah(int surahId, int ayah) async {
    try {
      final rows = await Db.I.ayat(surahId, AppPrefs.I.tafsir);
      final row = rows
          .where((r) => (r['ayah'] as num?)?.toInt() == ayah)
          .toList();
      final text = row.isEmpty ? '' : '${row.first['text'] ?? ''}';
      await copyPage(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('کۆپی کرا')));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // highlight boxes of the reciting verse (item 22)
  // ---------------------------------------------------------------------------

  /// All line boxes of verse [ayah] of [surahId] on the current page, in
  /// image-pixel space — painted as translucent golden rects over the page.
  List<Rect> _highlightRects(int surahId, int ayah) {
    final out = <Rect>[];
    for (final l in _pageLines) {
      if ((l['surah_id'] as num).toInt() != surahId) continue;
      if ((l['verse_id'] as num).toInt() != ayah) continue;
      final x0 = (l['min_x'] as num).toDouble() * _sx;
      final x1 = (l['max_x'] as num).toDouble() * _sx;
      final y0 = (l['min_y'] as num).toDouble() * _sy;
      final y1 = (l['max_y'] as num).toDouble() * _sy;
      out.add(Rect.fromLTRB(x0, y0, x1, y1));
    }
    return out;
  }

  /// While the reciter's whole-surah audio plays, follow the position
  /// through the timings, move the highlight box and — the big fix —
  /// AUTO-FLIP the mushaf page when the recitation crosses to a verse on
  /// the next page (e.g. Al-Baqarah ayah 5 → 6 lives on page 3). The old
  /// code only scanned the CURRENT page's lines, so the highlight went
  /// blank and the page never turned.
  void _followTimings(Duration p) {
    if (_ayahByAyah || _timings.isEmpty || _selSurah == null) return;
    final ms = p.inMilliseconds;
    final prefix = '$_selSurah:';
    int? cur;
    for (final e in _timings.entries) {
      if (!e.key.startsWith(prefix)) continue;
      final vid = int.tryParse(e.key.substring(prefix.length));
      if (vid != null && e.value <= ms && (cur == null || vid > cur)) {
        cur = vid;
      }
    }
    if (cur == null || cur == _selAyah || !mounted) return;
    // item 12: the finished ayah repeats 1/3/5/10 times — seek back to its
    // own start instead of moving to the next verse.
    if (_repeatLeft > 1 && !_reseeking && _selAyah != null) {
      _repeatLeft--;
      final again = _timings['$_selSurah:$_selAyah'] ?? 0;
      if (again > 0) {
        _reseeking = true;
        _player.seek(Duration(milliseconds: again)).whenComplete(() {
          _reseeking = false;
        });
        return;
      }
    }
    _repeatLeft = AppPrefs.I.ayahRepeat;
    setState(() => _selAyah = cur);
    _ensureAyahVisible(_selSurah!, cur);
  }

  /// When the recited verse lives on another mushaf page, turn there and
  /// keep the selection + golden highlight alive across the flip.
  Future<void> _ensureAyahVisible(int surahId, int ayah) async {
    if (_flipping) return;
    try {
      final p = await Db.I.ayahPage(surahId, ayah);
      if (p == null || p < 1 || p > _totalPages || p == _page || !mounted) {
        return;
      }
      _flipping = true;
      try {
        setState(() => _page = p);
        _savePage(p);
        await _pager.animateToPage(p - 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut);
        await _loadPageInfo(keep: (surahId, ayah));
        _cacheNeighbours(p);
      } finally {
        _flipping = false;
      }
    } catch (_) {}
  }

  // ---------- playback recovery ----------

  /// Watchdog: frozen position 10s while "playing" = stalled stream.
  Future<void> _watchdogTick() async {
    if (!mounted || _recovering || _postChecking) return;
    if (_ayahByAyah) return;
    if (_state != PlayerState.playing) return;
    final idle = DateTime.now().difference(_lastAdvance).inMilliseconds;
    if (idle < 10000) return;
    await _recoverSurah();
  }

  /// stopped/completed — surah finished naturally, or died early?
  Future<void> _postStopCheck() async {
    if (_postChecking || !mounted || _ayahByAyah) return;
    if (_selSurah == null || _lastPosMs < 3000) return;
    _postChecking = true;
    try {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || _recovering) return;
      if (_state == PlayerState.playing || _state == PlayerState.paused) return;
      final dur = _lastDurMs;
      if (dur > 0 && _lastPosMs >= dur - 4000) {
        // natural end of the surah audio
        setState(() => _state = PlayerState.stopped);
        _lastPosMs = 0;
        return;
      }
      await _recoverSurah();
    } finally {
      _postChecking = false;
    }
  }

  /// Premature stop — resume from the last position via the local file.
  Future<void> _recoverSurah() async {
    if (_recovering || !mounted) return;
    final resumeAt = _lastPosMs;
    final sid = _selSurah;
    if (resumeAt < 3000 || sid == null) return;
    _recovering = true;
    try {
      if (_recoverTries >= 3) {
        if (mounted) setState(() => _state = PlayerState.stopped);
        return;
      }
      _recoverTries++;
      try { await _player.resume(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted || _state == PlayerState.playing) return; // recovered
      final ok = await _playSurahLocal(sid, resumeAt);
      if (!ok && mounted) setState(() => _state = PlayerState.stopped);
    } finally {
      _recovering = false;
    }
  }

  @override
  void dispose() {
    _stall?.cancel();
    _player.dispose();
    _transform.dispose();
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
        backgroundColor: dark ? const Color(0xFF101010) : const Color(0xFFF6F1E4),
        appBar: _fullscreen ? null : _appBar(dark, txt),
        body: Column(children: [
          // surah chips of the current page (hidden with the chrome)
          if (_showChrome && !_fullscreen && _pageSurahs.isNotEmpty)
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
                    // In dark mode the page is colour-inverted: the cream
                    // paper turns near-black and the ink glows white so
                    // NOTHING is lost ("تەنیا نەماوە لە تاریکیدا").
                    final img = src.startsWith('http')
                        ? Image.network(src,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, w, prog) => prog == null
                                ? w
                                : const Center(
                                    child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => _pageError(p))
                        : Image.file(File(src), fit: BoxFit.contain);
                    final pageWidget = dark
                        ? ColorFiltered(
                            // invert: white text on near-black paper
                            colorFilter: const ColorFilter.matrix([
                              -1, 0, 0, 0, 1, //
                              0, -1, 0, 0, 1, //
                              0, 0, -1, 0, 1, //
                              0, 0, 0, 1, 0,
                            ]),
                            child: img)
                        : img;
                    return LayoutBuilder(builder: (context, box) {
                      final viewport = box.biggest;
                      final hl = (_selAyah != null && _selSurah != null &&
                              p == _page)
                          ? _highlightRects(_selSurah!, _selAyah!)
                          : const <Rect>[];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _onTap(d, p, viewport),
                        child: InteractiveViewer(
                          transformationController: _transform,
                          maxScale: 5,
                          child: Stack(fit: StackFit.expand, children: [
                            Center(child: pageWidget),
                            if (hl.isNotEmpty)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _HighlightPainter(
                                      rects: hl,
                                      viewport: viewport,
                                      img: Size(_imgW, _imgH),
                                      transform: _transform.value,
                                      playing:
                                          _state == PlayerState.playing),
                                ),
                              ),
                          ]),
                        ),
                      );
                    });
                  },
                );
              },
            ),
          ),
          // recitation bar (item 22): appears while a verse is recited —
          // also in fullscreen so play/pause stays reachable.
          if (_selAyah != null && _selSurah != null)
            _reciteBar(dark, txt),
          // Page turn bar — big, always-visible buttons (item 10).
          if (_showChrome && !_fullscreen)
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
          if (!_showChrome || _fullscreen)
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

  PreferredSizeWidget _appBar(bool dark, Color txt) => AppBar(
        backgroundColor:
            dark ? AppColors.nightCard : AppColors.primaryDark,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(widget.title ?? 'مەشەفی پیرۆز',
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(
              'لاپەڕە ${toArabicDigits(_page)} لە ${toArabicDigits(_totalPages)}'
              ' — دەست لە ئایەتێک بدە بۆ هەڵبژاردن',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          // item 2.3: the SAME reciter system as the Quran list — pick any
          // dangakan doxx=true reciter right inside the mushaf.
          IconButton(
              tooltip: 'گۆڕینی قاری — ${AppPrefs.I.qariName}',
              icon: const Icon(Icons.mic_rounded, color: Colors.white),
              onPressed: () async {
                final picked = await ReciterPickerSheet.show(context,
                    currentId: AppPrefs.I.qariId, dark: !AppPrefs.I.day);
                if (picked == null || !mounted) return;
                AppPrefs.I.qariId = '${picked['id'] ?? ''}';
                AppPrefs.I.qariName = '${picked['name_ar'] ?? 'قاری'}'.trim();
                AppPrefs.I.qariUrl = '${picked['url'] ?? ''}'
                    .replaceFirst(RegExp(r'^http://', caseSensitive: false),
                        'https://');
                await _player.stop();
                setState(() {
                  _state = PlayerState.stopped;
                  _selAyah = _selSurah == null ? null : _selAyah;
                  _reciterLabel = AppPrefs.I.qariName;
                });
                _timings = await Db.I.timings(AppPrefs.I.qariId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'قاری: ${picked['name_ar'] ?? ''} — دەنگ و ئایەت بەردەستە'),
                      duration: const Duration(seconds: 2)));
                }
              }),
          IconButton(
              tooltip: _fullscreen ? 'دەرچوون لە فول سکرین' : 'فول سکرین',
              onPressed: () {
                setState(() => _fullscreen = !_fullscreen);
                if (_fullscreen) {
                  SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.immersiveSticky);
                } else {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                }
              },
              icon: Icon(_fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
                  color: Colors.white)),
          IconButton(
              tooltip: 'چوونە لاپەڕە',
              onPressed: _askPage,
              icon: const Icon(Icons.pin_drop_rounded,
                  color: Colors.white)),
          // item 10: bulk download of the mushaf pages for offline use.
          IconButton(
              tooltip: 'داگرتنی لاپەڕەکان بۆ ئۆفلاین',
              onPressed: _downloadPagesDialog,
              icon: const Icon(Icons.download_for_offline_rounded,
                  color: Colors.white)),
          IconButton(
              tooltip: 'هاوبەشی',
              onPressed: () => sharePage(
                  'مەشەفی پیرۆز — لاپەڕە ${toArabicDigits(_page)}',
                  title: 'مەشەف'),
              icon: const Icon(Icons.share_rounded,
                  color: Colors.white)),
        ],
      );

  Widget _reciteBar(bool dark, Color txt) {
    final playing = _state == PlayerState.playing;
    final badge = _repeatBadge();
    return Container(
      color: dark ? AppColors.nightCard : Colors.white,
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset(context, extra: 2)),
      child: Row(children: [
        IconButton(
            tooltip: playing ? 'وەستان' : 'لێدان',
            onPressed: () async {
              if (playing) {
                await _player.pause();
              } else if (_state == PlayerState.paused) {
                await _player.resume();
              } else if (_selAyah != null && _selSurah != null) {
                await _reciteFromAyah(_selSurah!, _selAyah!);
              }
            },
            icon: Icon(playing
                ? Icons.pause_circle_rounded
                : Icons.play_circle_rounded,
                size: 34, color: dark ? AppColors.gold : AppColors.primaryDark)),
          // item 1+6: repeat control on the recite bar — the count is
          // picked from the same sheet as the reader, live badge included.
          Tooltip(
            message: 'دووبارەکردنەوەی هەر ئایەتێک',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickRepeatCount,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: badge.isEmpty
                        ? Colors.transparent
                        : AppColors.gold.withOpacity(.18),
                    borderRadius: BorderRadius.circular(10),
                    border: badge.isEmpty
                        ? null
                        : Border.all(color: AppColors.gold, width: 1.1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.repeat_one_rounded,
                      size: 18,
                      color: dark ? AppColors.gold : AppColors.primaryDark),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(badge,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dark
                                ? AppColors.gold
                                : AppColors.primaryDark)),
                  ],
                ]),
              ),
            ),
          ),
          Expanded(
            child: Text(
                '${_ayahByAyah ? 'ئایەت بە ئایەت' : 'لێدان لەم ئایەتەوە'} — '
                '${_surahLabel(_selSurah ?? 1)} • ئایەتی ${toArabicDigits(_selAyah ?? 0)}'
                ' • ${_reciterLabel ?? AppPrefs.I.qariName}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: txt)),
          ),
        IconButton(
            tooltip: 'وەستاندنی لێدان',
            onPressed: () async {
              await _player.stop();
              if (mounted) {
                setState(() {
                  _selAyah = null;
                  _repeatLeft = AppPrefs.I.ayahRepeat;
                });
              }
            },
            icon: Icon(Icons.stop_circle_rounded,
                size: 28, color: txt.withOpacity(.6))),
      ]),
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

/// The golden recitation highlight: the verse's line boxes (image-pixel
/// space) mapped through the fitted-image rect + the InteractiveViewer
/// transform onto the viewport.
class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.rects,
    required this.viewport,
    required this.img,
    required this.transform,
    required this.playing,
  });
  final List<Rect> rects;
  final Size viewport;
  final Size img;
  final Matrix4 transform;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (img == Size.zero || rects.isEmpty) return;
    final scale = math.min(viewport.width / img.width,
        viewport.height / img.height);
    final dx = (viewport.width - img.width * scale) / 2;
    final dy = (viewport.height - img.height * scale) / 2;
    final paint = Paint()
      ..color = AppColors.gold.withOpacity(playing ? .30 : .18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final r in rects) {
      // image px → fitted rect → child coords
      final child = Rect.fromLTRB(
          dx + r.left * scale,
          dy + r.top * scale,
          dx + r.right * scale,
          dy + r.bottom * scale);
      // child coords → viewport coords through the viewer transform
      final tl = MatrixUtils.transformPoint(transform, child.topLeft);
      final br = MatrixUtils.transformPoint(transform, child.bottomRight);
      final rect = Rect.fromPoints(tl, br);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(8)),
          paint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(8)),
          stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter old) =>
      old.playing != playing ||
      old.img != img ||
      old.transform != transform ||
      old.rects.length != rects.length;
}
