import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show AudioSetup, bottomInset, copyPage, sharePage, suraLabel;
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'open_quran.dart' show toArabicDigits;

/// Original: AyatActivity — daily ayah.
///
/// Item 1: the screen is now a GALLERY — a PageView of the whole surah's
/// ayat that starts on today's deterministic pick. One swipe moves to the
/// previous/next verse; no button press is needed to change the ayah.
/// Copy / share / recitation / zoom stay available for every verse.
class AyatScreen extends StatefulWidget {
  const AyatScreen({super.key});
  @override
  State<AyatScreen> createState() => _AyatScreenState();
}

class _AyatScreenState extends State<AyatScreen> {
  List<Map<String, Object?>> _ayat = [];
  int _index = 0;
  bool _loading = true;
  final PageController _pager = PageController();
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _zoom = 24;
  bool _audioBusy = false;

  @override
  void initState() {
    super.initState();
    AudioSetup.prepare(_player); // item 2: steady full volume everywhere
    _zoom = AppPrefs.I.ayahFontSize.toDouble(); // item 6: keep last size
    _load();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// Same deterministic "ayah of the day" as the home banner: day-of-year
  /// drives the pick; the gallery starts there and the user can swipe
  /// freely through the rest of that surah.
  Future<void> _load() async {
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final sura = Random(day).nextInt(114) + 1;
    final ayat = await Db.I.ayat(sura, AppPrefs.I.tafsir);
    if (!mounted) return;
    final idx = ayat.isEmpty ? 0 : Random(day).nextInt(ayat.length);
    setState(() {
      _ayat = ayat;
      _index = idx;
      _loading = false;
    });
    if (idx > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pager.hasClients) _pager.jumpToPage(idx);
      });
    }
  }

  Map<String, Object?> get _row =>
      _ayat.isEmpty ? <String, Object?>{} : _ayat[_index];

  String _audioUrl(Map<String, Object?> row) {
    final link = row['link']?.toString().trim() ?? '';
    if (link.isEmpty) throw const FormatException('Ayah audio link is empty');
    if (link.startsWith('https://') || link.startsWith('http://')) {
      return link.replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
    }
    final file = link.toLowerCase().endsWith('.mp3') ? link : link + '.mp3';
    final number = file.replaceAll('.mp3', '').padLeft(3, '0');
    final base = AppPrefs.I.qariUrl;
    return base.endsWith('/') ? '$base$number.mp3' : '$base/$number.mp3';
  }

  Future<void> _play() async {
    if (_row.isEmpty) return;
    final link = '${_row['link'] ?? ''}';
    if (link.isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        setState(() => _audioBusy = true);
        await _player.stop();
        final url = Downloader.httpsify(_audioUrl(_row));
        try {
          await _player.play(UrlSource(url));
        } catch (_) {
          // streaming refused — download then play
          final file = await Downloader.download(
              url, 'ayat/${Downloader.safeName(link)}',
              timeout: const Duration(minutes: 3));
          await _player.play(DeviceFileSource(file.path));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کێشە لە پەخشکردنی دەنگ')));
      }
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final r = _row;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFF004D7B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            const Text('ئایەتی ڕۆژ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_ayat.isNotEmpty)
              Text(
                  '${suraLabel('${r['sura_name_ar'] ?? ''}')} • ئایەتی ${toArabicDigits(((r['ayah'] ?? 0) as num).toInt())} — ${toArabicDigits(_index + 1)}/${toArabicDigits(_ayat.length)}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _ayat.isEmpty
                ? Center(
                    child: Text('داتای ئایەتەکان بەردەست نییە',
                        style: TextStyle(color: Colors.white.withOpacity(.8))))
                : Column(children: [
                    Expanded(
                      // Item 1: the gallery — swipe left/right to move
                      // between verses, no button needed.
                      child: PageView.builder(
                        controller: _pager,
                        reverse: true,
                        itemCount: _ayat.length,
                        onPageChanged: (i) async {
                          await _player.stop();
                          if (mounted) setState(() { _index = i; _playing = false; });
                        },
                        itemBuilder: (context, i) =>
                            _page(_ayat[i], dark),
                      ),
                    ),
                    // page dots strip
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6, top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swipe_left_rounded,
                                color: Colors.white60, size: 16),
                            const SizedBox(width: 6),
                            ...List.generate(
                              _ayat.length.clamp(0, 24),
                              (i) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _index
                                        ? (dark ? AppColors.gold : Colors.white)
                                        : Colors.white.withOpacity(.25)),
                              ),
                            ),
                            if (_ayat.length > 24)
                              Text(' …${toArabicDigits(_ayat.length)}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    _zoomBar(),
                  ]),
      ),
    );
  }

  Widget _page(Map<String, Object?> r, bool dark) {
    final tafsir = '${r[AppPrefs.I.tafsir] ?? ''}';
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: dark ? AppColors.nightCard : Colors.white,
              borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Row(children: [
              Flexible(
                child: Text(AppPrefs.I.showQuranSurahName
                    ? '${suraLabel('${r['sura_name_ar'] ?? ''}')} • ئایەتی ${toArabicDigits(((r['ayah'] ?? 0) as num).toInt())}'
                    : 'ئایەتی ${toArabicDigits(((r['ayah'] ?? 0) as num).toInt())}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: dark ? AppColors.gold : AppColors.primaryDark)),
              ),
              const Spacer(),
              FavoriteButton(
                id: 'daily_ayah::${r['suraId']}::${r['ayah']}',
                title: '${suraLabel('${r['sura_name_ar'] ?? ''}')} • ئایەتی ${toArabicDigits(((r['ayah'] ?? 0) as num).toInt())}',
                content: '${r['text']}\n\n$tafsir',
                route: 'quran::${r['suraId']}::${r['ayah']}',
                color: dark ? AppColors.gold : AppColors.primaryDark),
              Text('ڕێگای ئیسلام',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(.4))),
            ]),
            const Divider(height: 22),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text('${r['text'] ?? ''}',
                  style: TextStyle(
                      fontFamily: AppPrefs.I.fontQuran,
                      fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                      fontSize: _zoom, height: 2.1,
                      color: dark ? Colors.white : Colors.black)),
            ),
            const SizedBox(height: 14),
            if (tafsir.trim().isNotEmpty) Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withOpacity(.05)
                      : const Color(0xFFF7F5EF),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(tafsir,
                  style: TextStyle(
                      fontSize: 14, height: 1.8,
                      color: dark ? Colors.white.withOpacity(.85) : Colors.black.withOpacity(.85))),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _btn(Icons.copy_rounded, 'کۆپی', () async {
            await copyPage('${r['text']}\n\n$tafsir');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('کۆپی کرا')));
          }),
          _btn(Icons.share_rounded, 'هاوبەشی', () => sharePage(
              '${r['text']}\n\n$tafsir',
              title: suraLabel('${r['sura_name_ar'] ?? ''}'))),
          _btn(
              _audioBusy
                  ? Icons.hourglass_top_rounded
                  : _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              'دەنگ', _play),
        ]),
      ]),
    );
  }

  Widget _zoomBar() => SafeArea(
        top: false,
        child: Container(
          color: Colors.black.withOpacity(.18),
          padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset(context, extra: 4)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: () => setState(() {
                  _zoom = (_zoom - 2).clamp(14, 60);
                  AppPrefs.I.ayahFontSize = _zoom.round();
                }),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.white70)),
            Text('قەبارەی نووسین: ${toArabicDigits(_zoom.round())}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            IconButton(
                onPressed: () => setState(() {
                  _zoom = (_zoom + 2).clamp(14, 60);
                  AppPrefs.I.ayahFontSize = _zoom.round();
                }),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.white70)),
          ]),
        ),
      );

  Widget _btn(IconData i, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkResponse(
              onTap: onTap,
              child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(i, color: AppColors.primaryDark))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}
