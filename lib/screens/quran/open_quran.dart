import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart';
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'quran_settings_sheet.dart';

/// Original: OpenquranActivity — ayah list with tafsir, audio playback with
/// ayah highlighting via the reciter timings dbs, and mushaf page mode.
class OpenQuranScreen extends StatefulWidget {
  const OpenQuranScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.ayaCount,
    required this.place,
    required this.juz,
  });

  final int surahId;
  final String surahName;
  final int ayaCount;
  final String place;
  final String juz;

  @override
  State<OpenQuranScreen> createState() => _OpenQuranScreenState();
}

class _OpenQuranScreenState extends State<OpenQuranScreen> {
  List<Map<String, Object?>> _ayat = [];
  bool _loading = true;
  String _tafsir = 'rebar';
  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  int? _playingAyah;
  PlayerState _state = PlayerState.stopped;
  Map<String, int> _timings = {};
  final ScrollController _scroll = ScrollController();
  bool _mushaf = false;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _tafsir = AppPrefs.I.tafsir;
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      _highlightByTime(p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _state = PlayerState.stopped; _playingAyah = null; });
    });
  }

  Future<void> _load() async {
    final rows = await Db.I.ayat(widget.surahId, _tafsir);
    if (!mounted) return;
    setState(() { _ayat = rows; _loading = false; });
  }

  String _mp3Url(String link) {
    if (link.startsWith('http')) return link;
    final n = link.replaceAll('.mp3', '').padLeft(3, '0');
    // Original: OpenquranActivity plays pref "url" + <surah>.mp3, reciter
    // chosen in QariakanActivity (default سعد الغامدي from SplashActivity).
    final base = AppPrefs.I.qariUrl;
    return base.endsWith('/') ? '$base$n.mp3' : '$base/$n.mp3';
  }

  /// Offline cache path for the current reciter + surah.
  Future<File?> _cachedAudio() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/quran_audio/'
          '${Downloader.safeName(AppPrefs.I.qariId)}_'
          '${widget.surahId.toString().padLeft(3, '0')}.mp3');
      return f.existsSync() && f.lengthSync() > 0 ? f : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playSurah() async {
    final link = _ayat.isEmpty ? '' : '${_ayat.first['link'] ?? ''}';
    if (link.isEmpty) return;
    final url = Downloader.httpsify(_mp3Url(link));
    try {
      if (_currentUrl == url && _state == PlayerState.playing) {
        await _player.pause();
      } else if (_currentUrl == url && _state == PlayerState.paused) {
        await _player.resume();
      } else {
        _timings = await Db.I.timings(AppPrefs.I.qariId);
        final cached = await _cachedAudio();
        if (cached != null) {
          await _player.play(DeviceFileSource(cached.path));
        } else {
          try {
            await _player.play(UrlSource(url));
          } catch (_) {
            // streaming refused — download then play, like the original
            final file = await Downloader.download(url,
                'quran_audio/${Downloader.safeName(AppPrefs.I.qariId)}_'
                '${widget.surahId.toString().padLeft(3, '0')}.mp3');
            await _player.play(DeviceFileSource(file.path));
          }
        }
        setState(() => _currentUrl = url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە داگرتنی دەنگ، تکایە ئینتەرنێت بپشکنە')));
      }
    }
  }

  void _highlightByTime(Duration p) {
    if (_timings.isEmpty || _ayat.isEmpty) return;
    final ms = p.inMilliseconds;
    int? cur;
    for (final a in _ayat) {
      final key = '${widget.surahId}:${a['ayah']}';
      final t = _timings[key];
      if (t != null && t <= ms) cur = (a['ayah'] as num).toInt();
    }
    if (cur != null && cur != _playingAyah) {
      setState(() => _playingAyah = cur);
      _scrollToAyah(cur);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Auto-scroll the ayah list to the currently recited ayah (item 20).
  void _scrollToAyah(int ayahNum) {
    if (!_scroll.hasClients) return;
    final itemIndex = _ayat.indexWhere(
        (a) => ((a['ayah'] as num?)?.toInt() ?? 0) == ayahNum);
    if (itemIndex < 0) return;
    const itemExtent = 170.0;
    final target = (itemIndex * itemExtent).clamp(
        0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (AppPrefs.I.showQuranSurahName)
              Text(suraLabel(widget.surahName),
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text('${widget.place} • ${widget.juz}',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          actions: [
            IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () => showQuranSettingsSheet(context, () {
                      setState(() {}); // refresh font prefs
                    })),
            IconButton(
                tooltip: 'مەشەف',
                icon: Icon(_mushaf
                    ? Icons.menu_book_rounded
                    : Icons.menu_book_outlined, color: Colors.white),
                onPressed: () => setState(() => _mushaf = !_mushaf)),
            IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => sharePage(
                    '${suraLabel(widget.surahName)} — ئەپی ڕێگای ئیسلام')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                if (_mushaf) Expanded(child: _mushafView(dark, txt))
                else Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _ayat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final a = _ayat[i];
                      final ayahNum = (a['ayah'] as num?)?.toInt() ?? 0;
                      final ayahText = '${a['text'] ?? ''}';
                      final tafsir = '${a[_tafsir] ?? ''}';
                      final highlighted = _playingAyah == ayahNum;
                      return GestureDetector(
                        onTap: () => _copyAyah(ayahText, tafsir),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? (dark ? AppColors.nightCard : const Color(0xFFE8F0FE))
                                : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: highlighted
                                    ? AppColors.primaryDark
                                    : dark ? Colors.white10 : Colors.black12),
                          ),
                          child: Column(crossAxisAlignment:
                              CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              if (AppPrefs.I.showQuranAyahNumbers) Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: dark
                                        ? AppColors.gold.withOpacity(.15)
                                        : AppColors.primaryDark.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(toArabicDigits(ayahNum),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: dark ? AppColors.gold : AppColors.primaryDark)),
                              ),
                              if (AppPrefs.I.showQuranAyahNumbers) const Spacer(),
                              FavoriteButton(
                                id: 'quran::${widget.surahId}::$ayahNum',
                                title: '${suraLabel(widget.surahName)} • ئایەتی ${toArabicDigits(ayahNum)}',
                                content: '$ayahText\n\n$tafsir',
                                color: dark ? AppColors.gold : AppColors.primaryDark),
                              if (AppPrefs.I.showQuranAyahNumbers) Text('${suraLabel(widget.surahName)} • ئایەتی ${toArabicDigits(ayahNum)}',
                                style: TextStyle(fontSize: 10,
                                  color: txt.withOpacity(.55),
                                  fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(ayahText,
                                  style: TextStyle(
                                      fontFamily: AppPrefs.I.fontQuran,
                                      fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                                      fontSize: AppPrefs.I.quranFontSize
                                          .toDouble(),
                                      height: 2, color: txt)),
                            ),
                            if (AppPrefs.I.showQuranTafsir && tafsir.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: dark
                                        ? Colors.white.withOpacity(.05)
                                        : const Color(0xFFF7F5EF),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(tafsir,
                                    style: TextStyle(
                                        fontSize: 13, height: 1.7,
                                        color: txt.withOpacity(.85))),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                AudioPlayerBar(
                  player: _player,
                  dark: dark,
                  card: card,
                  title: 'دەنگی سوورەت — ${AppPrefs.I.qariName}',
                  onPlayPause: _playSurah,
                  playing: _state == PlayerState.playing,
                ),
              ]),
      ),
    );
  }

  /// Item 3: mushaf page of the first/current ayah (bundled page images
  /// cover a subset; otherwise fall back to a friendly notice).
  Widget _mushafView(bool dark, Color txt) {
    final focus = _playingAyah ??
        ((_ayat.isNotEmpty
            ? ((_ayat.first['ayah'] as num?)?.toInt() ?? 1)
            : 1));
    return FutureBuilder<int?>(
      future: Db.I.ayahPage(widget.surahId, focus),
      builder: (context, snap) {
        final page = snap.data;
        final path = page == null ? null : 'assets/images/mushaf/$page.png';
        final exists = path != null;
        if (!exists) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_rounded, size: 44,
                    color: dark ? AppColors.gold : AppColors.primaryDark),
                const SizedBox(height: 12),
                Text('وێنەی لاپەڕەی مەشەف بۆ ئەم ئایەتە بەردەست نییە',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: txt.withOpacity(.7), fontSize: 13)),
                const SizedBox(height: 6),
                Text('دەتوانیت دەقەکە لە دۆخی ئاسایی بخوێنیتەوە',
                    style: TextStyle(color: txt.withOpacity(.45), fontSize: 12)),
              ]),
            ),
          );
        }
        return InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.asset(path,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                    'لاپەڕە $page بارنەبوو',
                    style: TextStyle(color: txt))),
          ),
        );
      },
    );
  }

  void _copyAyah(String ayah, String tafsir) async {
    await copyPage('$ayah\n\n$tafsir');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('کۆپی کرا')));
  }
}

String toArabicDigits(int n) {
  if (!AppPrefs.I.useKurdishDigits) return n.toString();
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}
