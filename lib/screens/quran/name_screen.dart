import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show AudioSetup, bottomInset, kAppUrl;
import '../../data/db.dart';
import '../../data/downloader.dart';
import '../../data/favorites.dart';
import 'open_quran.dart' show OpenQuranScreen, toArabicDigits;

/// Original: NameActivity — the 99 names of Allah.
///
/// Item 13: every name now carries REAL sound and REAL location:
///  • the row keeps its TTS voice, and a second button plays the AYAH
///    where the name occurs (per-ayah audio, same cdn as the reader);
///  • the location row (سوورەت + ئایەت) is clickable — it opens the Quran
///    AT that ayah with the name's word highlighted inside the verse;
///  • tafsir in Sorani AND Badini (from the bundled name.db) stays visible;
///  • opening with openId (from favorites) expands + scrolls to that name.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key, this.openId});

  /// Item 12/13: when opened from favorites, expand + scroll to this name.
  final int? openId;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameRow {
  final int id;
  final String arabic;
  final String tashkeel;
  final String ref;
  final String sorani;
  final String badini;
  final String english;
  final String farsi;
  _NameRow({
    required this.id,
    required this.arabic,
    required this.tashkeel,
    required this.ref,
    required this.sorani,
    required this.badini,
    required this.english,
    required this.farsi,
  });
}

class _NameScreenState extends State<NameScreen> {
  List<_NameRow> _rows = [];
  List<_NameRow> _filtered = [];
  int? _openId;
  int? _speakingId;
  bool _playAll = false;
  bool _loading = true;
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  final AudioPlayer _ayahPlayer = AudioPlayer();
  int? _ayahPlayingId;
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _initTts();
    AudioSetup.prepare(_ayahPlayer);
    _load();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speakingId = null);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {}
  }

  Future<void> _load() async {
    List<_NameRow> rows = [];
    // 1) the ready data file shipped with the project (item 6)
    try {
      final raw = await rootBundle
          .loadString('assets/data/nawakani_xwda.json');
      final list = (jsonDecodeList(raw));
      rows = list
          .map((e) => _NameRow(
                id: (e['id'] as num?)?.toInt() ?? 0,
                arabic: '${e['arabic'] ?? ''}',
                tashkeel: '${e['tashkeel'] ?? ''}',
                ref: '${e['ref'] ?? ''}',
                sorani: '${e['sorani'] ?? ''}',
                badini: '${e['badini'] ?? ''}',
                english: '${e['english'] ?? ''}',
                farsi: '${e['farsi'] ?? ''}',
              ))
          .toList();
    } catch (_) {}
    // 2) fallback: the bundled SQLite database
    if (rows.isEmpty) {
      try {
        final dbRows = await Db.I.names();
        rows = dbRows.map((r) {
          final id = (r['_id'] as num?)?.toInt() ?? 0;
          return _NameRow(
            id: id == 0 ? 1 : id,
            arabic: '${r['arabic'] ?? ''}',
            tashkeel: '${r['highlight_section'] ?? ''}',
            ref: '${r['surah_ayah'] ?? ''}',
            sorani: '${r['sorani'] ?? ''}',
            badini: '${r['badini'] ?? ''}',
            english: '${r['english'] ?? ''}',
            farsi: '${r['farsi'] ?? ''}',
          );
        }).toList();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _rows = rows; _filtered = rows; _loading = false; });
    // Item 12/13: opened from a favorite — expand and scroll to the name.
    final target = widget.openId;
    if (target != null) {
      setState(() => _openId = target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _cardKeys[target]?.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              alignment: 0.1);
        }
      });
    }
  }

  static List<Map<String, dynamic>> jsonDecodeList(String raw) {
    try {
      final l = const JsonDecoder().convert(raw) as List;
      return l.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// The spoken text: the name itself — when the tashkeel column carries a
  /// whole verse excerpt (some rows do) fall back to the plain name.
  String _spoken(_NameRow r) {
    final t = r.tashkeel.trim();
    if (t.isNotEmpty && t.split(RegExp(r'\s+')).length <= 3) return t;
    return r.arabic;
  }

  Future<void> _speak(_NameRow r) async {
    if (!_ttsReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگی ئەم مۆبایلە بەردەست نییە'),
            duration: Duration(milliseconds: 900)));
      }
      return;
    }
    try {
      await _tts.stop();
      if (mounted) setState(() => _speakingId = r.id);
      await _tts.speak(_spoken(r));
      if (mounted && _speakingId == r.id) setState(() => _speakingId = null);
    } catch (_) {
      if (mounted) setState(() => _speakingId = null);
    }
  }

  /// Item 13: recite ALL names one by one with highlight.
  Future<void> _togglePlayAll() async {
    if (_playAll) {
      _playAll = false;
      await _tts.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }
    _playAll = true;
    if (mounted) setState(() {});
    for (final r in _rows) {
      if (!_playAll || !mounted) break;
      setState(() => _speakingId = r.id);
      await _speak(r);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _playAll = false;
    if (mounted) setState(() => _speakingId = null);
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _rows
          : _rows.where((r) {
              return r.arabic.contains(q) ||
                  r.sorani.toLowerCase().contains(q) ||
                  r.badini.toLowerCase().contains(q) ||
                  r.english.toLowerCase().contains(q);
            }).toList();
    });
  }

  /// "2:7" → (2, 7); ""/bad → null.
  (int, int)? _refOf(String ref) {
    final p = ref.split(':');
    if (p.length != 2) return null;
    final s = int.tryParse(p[0].trim());
    final a = int.tryParse(p[1].trim());
    if (s == null || a == null || s < 1 || s > 114 || a < 1) return null;
    return (s, a);
  }

  /// Item 13: open the Quran AT the ayah where this name occurs, with the
  /// name's word highlighted inside the verse (the word comes from the
  /// highlight_section column of name.db).
  Future<void> _openAyahOf(_NameRow r) async {
    final ref = _refOf(r.ref);
    if (ref == null) return;
    final (sid, ayah) = ref;
    final surahs = await Db.I.surahs();
    final s = surahs
        .where((e) => (e['soraid'] as num?)?.toInt() == sid)
        .toList();
    if (!mounted || s.isEmpty) return;
    final word = r.tashkeel.trim();
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => OpenQuranScreen(
            surahId: sid,
            surahName: '${s.first['name'] ?? ''}',
            ayaCount: (s.first['aya'] as num?)?.toInt() ?? 7,
            place: '${s.first['place'] ?? ''}',
            juz: '${s.first['juz'] ?? ''}',
            initialAyah: ayah,
            highlightAyah: ayah,
            highlightWord:
                (word.isNotEmpty && word.split(' ').length <= 3) ? word : null)));
  }

  /// Item 13: play the real recitation of the ayah where the name occurs
  /// (per-ayah audio — global index 1..6236, same CDN as the reader).
  Future<void> _playAyahOf(_NameRow r) async {
    final ref = _refOf(r.ref);
    if (ref == null) return;
    final (sid, ayah) = ref;
    try {
      await _ayahPlayer.stop();
      setState(() => _ayahPlayingId = r.id);
      final g = await Db.I.globalAyah(sid, ayah);
      final url = Downloader.httpsify(
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$g.mp3');
      await _ayahPlayer.play(UrlSource(url));
    } catch (_) {
      if (mounted) {
        setState(() => _ayahPlayingId = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگی ئایەتەکە بەردەست نییە — ئینتەرنێت بپشکنە'),
            duration: Duration(milliseconds: 900)));
      }
      return;
    }
    _ayahPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _ayahPlayingId = null);
    });
  }

  @override
  void dispose() {
    _playAll = false;
    try { _tts.stop(); } catch (_) {}
    _ayahPlayer.dispose();
    super.dispose();
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
          title: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            const Text('ناوەکانی خودای گەورە',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text('لێدانی ناوەکان بە دەنگ — ${toArabicDigits(_rows.length)} ناو',
                style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
          ]),
          actions: [
            IconButton(
              tooltip: _playAll ? 'وەستان' : 'لێدانی هەموو ناوەکان',
              icon: Icon(_playAll ? Icons.stop_circle_rounded : Icons.graphic_eq_rounded,
                  color: Colors.white),
              onPressed: _rows.isEmpty ? null : _togglePlayAll,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'گەڕان بە عەرەبی، کوردی یان ئینگلیزی...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: dark ? AppColors.nightCard : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('هیچ ناوێک نەدۆزرایەوە',
                    style: TextStyle(color: txt.withOpacity(.5))))
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(12, 4, 12,
                        bottomInset(context, extra: 14)),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = _filtered[i];
                      final open = _openId == r.id;
                      final speaking = _speakingId == r.id;
                      final key = _cardKeys.putIfAbsent(r.id, () => GlobalKey());
                      return _nameCard(r, open, speaking, dark, txt, key);
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _nameCard(_NameRow r, bool open, bool speaking, bool dark, Color txt,
      GlobalKey key) {
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    final ref = _refOf(r.ref);
    return Card(
      key: key,
      color: speaking
          ? accent.withOpacity(dark ? .18 : .10)
          : (dark ? AppColors.nightCard : Colors.white),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: speaking
              ? BorderSide(color: accent, width: 1.6)
              : BorderSide(
                  color: dark ? Colors.white10 : Colors.black12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _openId = open ? null : r.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              // number badge
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(.12),
                    border: Border.all(color: accent.withOpacity(.4))),
                child: Text(toArabicDigits(r.id),
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: accent)),
              ),
              const SizedBox(width: 10),
              // the name in Quran calligraphy
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(r.arabic,
                    style: TextStyle(
                        fontFamily: 'Quran', fontSize: 22, color: txt)),
              ),
              const Spacer(),
              // speak button
              InkWell(
                onTap: () => _speak(r),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: speaking
                          ? accent.withOpacity(.22)
                          : Colors.transparent),
                  child: Icon(
                      speaking
                          ? Icons.volume_up_rounded
                          : Icons.volume_up_outlined,
                      size: 24, color: accent),
                ),
              ),
              const SizedBox(width: 2),
              Icon(open
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
                  color: txt.withOpacity(.4)),
            ]),
            if (r.sorani.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.sorani,
                  maxLines: open ? null : 2,
                  overflow: open ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.6,
                      color: txt.withOpacity(.8))),
            ],
            if (open) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: txt.withOpacity(.15)),
              const SizedBox(height: 10),
              if (r.ref.isNotEmpty)
                // Item 13: the location is CLICKABLE — one tap opens the
                // Quran at that surah/ayah with the name highlighted.
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: ref != null ? () => _openAyahOf(r) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                        color: accent.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withOpacity(.25))),
                    child: Row(children: [
                      Icon(Icons.menu_book_rounded, size: 17, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'شوێنی ناوەکە — سوڕەتی ${toArabicDigits(ref?.$1 ?? 0)}'
                            ' • ئایەتی ${toArabicDigits(ref?.$2 ?? 0)}'
                            '${r.tashkeel.trim().isEmpty ? '' : '  (${r.tashkeel.trim()})'}',
                            style: TextStyle(fontSize: 12.5,
                                fontWeight: FontWeight.w600, color: accent)),
                      ),
                      // play the real ayah recitation
                      InkWell(
                        onTap: ref != null ? () => _playAyahOf(r) : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                              _ayahPlayingId == r.id
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_rounded,
                              size: 24, color: accent),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_left_rounded,
                          size: 20, color: accent),
                    ]),
                  ),
                ),
              if (r.badini.isNotEmpty) _m('بادینی', r.badini, txt, dark),
              if (r.english.isNotEmpty) _m('English', r.english, txt, dark),
              if (r.farsi.isNotEmpty) _m('فارسی', r.farsi, txt, dark),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                FavoriteButton(
                    id: 'allahname::${r.id}',
                    title: r.arabic,
                    content: r.sorani,
                    route: 'allahname::${r.id}'),
                TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: '${r.arabic}\n${r.sorani}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('کۆپی کرا')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('کۆپی', style: TextStyle(fontSize: 12))),
                TextButton.icon(
                    onPressed: () => Share.share(
                        '${r.arabic}\n${r.sorani}\n\nڕێگای ئیسلام — $kAppUrl',
                        subject: r.arabic),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('هاوبەشی',
                        style: TextStyle(fontSize: 12))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _m(String label, String value, Color txt, bool dark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold,
              color: dark ? AppColors.gold : AppColors.primaryDark)),
          Text(value, style: TextStyle(fontSize: 13.5, height: 1.6, color: txt)),
        ]),
      );
}
