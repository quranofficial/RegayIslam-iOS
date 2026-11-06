import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';

/// Original: NameActivity — the 99 names of Allah (name.db) with
/// Sorani/Badini/English/Farsi meanings.
///
/// Item 6: every name now speaks — the Arabic name is recited with the
/// device TTS (works offline), the playing name is highlighted, and
/// "لێدانی هەموو" walks through all 99 names one after another.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});
  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  List<Map<String, Object?>> _rows = [];
  List<Map<String, Object?>> _filtered = [];
  int? _open;
  int? _speakingId;
  bool _playAll = false;
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initTts();
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
    final rows = await Db.I.names();
    if (!mounted) return;
    setState(() { _rows = rows; _filtered = rows; });
  }

  Future<void> _speak(Map<String, Object?> r) async {
    if (!_ttsReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('دەنگی ئەم مۆبایلە بەردەست نییە'),
            duration: Duration(milliseconds: 900)));
      }
      return;
    }
    final id = (r['_id'] as num?)?.toInt() ?? 0;
    final text = '${r['highlight_section'] ?? r['arabic'] ?? ''}';
    try {
      await _tts.stop();
      if (mounted) setState(() => _speakingId = id);
      await _tts.speak(text);
      // awaitSpeakCompletion(true) resolves when done
      if (mounted && _speakingId == id) setState(() => _speakingId = null);
    } catch (_) {
      if (mounted) setState(() => _speakingId = null);
    }
  }

  /// Item 6: recite ALL 99 names one by one with highlight.
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
      final id = (r['_id'] as num?)?.toInt() ?? 0;
      setState(() => _speakingId = id);
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
              return '${r['arabic']}'.contains(q) ||
                  '${r['sorani']}'.toLowerCase().contains(q) ||
                  '${r['english']}'.toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  void dispose() {
    _playAll = false;
    try { _tts.stop(); } catch (_) {}
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
          title: const Text('ناوەکانی خودای گەورە',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: _playAll ? 'وەستان' : 'لێدانی هەموو ناوەکان',
              icon: Icon(_playAll ? Icons.stop_circle_rounded : Icons.graphic_eq_rounded,
                  color: Colors.white),
              onPressed: _togglePlayAll,
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'گەڕان...',
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final r = _filtered[i];
                final id = (r['_id'] as num?)?.toInt() ?? i + 1;
                final open = _open == i;
                final speaking = _speakingId == id;
                return Card(
                  color: speaking
                      ? (dark ? AppColors.gold.withOpacity(.18) : const Color(0xFFE8F5E9))
                      : (dark ? AppColors.nightCard : Colors.white),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: speaking
                          ? const BorderSide(color: AppColors.gold, width: 1.4)
                          : BorderSide.none),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _open = open ? null : i),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(
                                  radius: 20,
                                  backgroundColor: speaking
                                      ? AppColors.gold.withOpacity(.3)
                                      : (dark
                                          ? AppColors.gold.withOpacity(.15)
                                          : AppColors.primaryDark.withOpacity(.08)),
                                  child: Text('${id}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: dark ? AppColors.gold : AppColors.primaryDark))),
                              const SizedBox(width: 10),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text('${r['arabic']}',
                                    style: TextStyle(
                                        fontFamily: 'Quran', fontSize: 22, color: txt)),
                              ),
                              const Spacer(),
                              // Item 6: speak this name.
                              InkWell(
                                onTap: () => _speak(r),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                      speaking
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_up_outlined,
                                      size: 26,
                                      color: speaking
                                          ? AppColors.gold
                                          : (dark ? AppColors.gold : AppColors.primaryDark)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(open
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                                  color: txt.withOpacity(.4)),
                            ]),
                            if (open) ...[
                              const SizedBox(height: 10),
                              _m('کوردی', '${r['sorani']}', txt, dark),
                              if ('${r['badini'] ?? ''}'.trim().isNotEmpty)
                                _m('بادینی', '${r['badini']}', txt, dark),
                              _m('English', '${r['english'] ?? ''}', txt, dark),
                              if ('${r['farsi'] ?? ''}'.trim().isNotEmpty)
                                _m('فارسی', '${r['farsi']}', txt, dark),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                FavoriteButton(id: 'allahname::${r['_id'] ?? i}',
                                  title: '${r['arabic']}', content: '${r['sorani']}',
                                  route: 'allahname::${r['_id'] ?? i}'),
                                TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: '${r['arabic']}\n${r['sorani']}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('کۆپی کرا')));
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('کۆپی', style: TextStyle(fontSize: 12))),
                                TextButton.icon(
                                    onPressed: () => Share.share(
                                        '${r['arabic']}\n${r['sorani']}\n\n#ڕێگای ئیسلام'),
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: const Text('هاوبەشی', style: TextStyle(fontSize: 12))),
                              ]),
                            ],
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

  Widget _m(String label, String value, Color txt, bool dark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          Text(value, style: TextStyle(fontSize: 13.5, height: 1.6, color: txt)),
        ]),
      );
}
