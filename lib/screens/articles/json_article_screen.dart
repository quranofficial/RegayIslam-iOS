import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;
import '../../data/downloader.dart';
import '../../data/favorites.dart';

/// Original: Hack1Activity — generic article reader over the bundled JSON
/// files (zikrakan, duha, agr, bahasht, xawn, wta, ...), with live search,
/// copy and share of each item. The four time-of-day zikrs carry their own
/// recitation audio, streamed exactly like the Android MediaPlayer.
const kZikrAudios = <String, String>{
  'زیکری لەخەو هەستان': 'https://github.com/quranofficial/swrat/raw/main/hastan.mp3',
  'زیکری بەیانیان': 'https://github.com/sahanddler/dang/raw/main/bayani.mp3',
  'زیکری ئێواران': 'https://github.com/quranofficial/swrat/raw/main/ewara.mp3',
  'زیکری خەوتن': 'https://github.com/quranofficial/swrat/raw/main/sleep.mp3',
};

class JsonArticleScreen extends StatefulWidget {
  const JsonArticleScreen({super.key, required this.file, required this.title});
  final String file;
  final String title;
  @override
  State<JsonArticleScreen> createState() => _JsonArticleScreenState();
}

class _JsonArticleScreenState extends State<JsonArticleScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  int? _open;
  final AudioPlayer _zikrPlayer = AudioPlayer();
  String? _zikrUrl;
  PlayerState _zikrState = PlayerState.stopped;
  bool _zikrBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _zikrPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _zikrState = s);
    });
    _zikrPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _zikrUrl = null);
    });
  }

  Future<void> _playZikr(String url) async {
    if (_zikrUrl == url && _zikrState == PlayerState.playing) {
      await _zikrPlayer.pause();
      return;
    }
    if (_zikrUrl == url && _zikrState == PlayerState.paused) {
      await _zikrPlayer.resume();
      return;
    }
    setState(() => _zikrBusy = true);
    try {
      // Download-first like the original, so the zikr replays offline.
      final name = Downloader.safeName(url.split('/').last);
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/zikr/$name');
      if (!f.existsSync()) {
        await Downloader.download(url, 'zikr/$name',
            timeout: const Duration(minutes: 3));
      }
      await _zikrPlayer.stop();
      await _zikrPlayer.play(DeviceFileSource(f.path));
      setState(() => _zikrUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('کێشە لە داگرتنی دەنگ، تکایە ئینتەرنێت بپشکنە')));
      }
    } finally {
      if (mounted) setState(() => _zikrBusy = false);
    }
  }

  @override
  void dispose() {
    _zikrPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.file);
      final list = jsonDecode(raw) as List;
      setState(() {
        _all = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _filtered = _all;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((m) {
              return '${m['title'] ?? ''}'.toLowerCase().contains(q) ||
                  '${m['text'] ?? ''}'.toLowerCase().contains(q);
            }).toList();
    });
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
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  child: _filtered.isEmpty
                      ? Center(child: Text('هیچ نەدۆزرایەوە',
                          style: TextStyle(color: txt.withOpacity(.5))))
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset(context, extra: 14)),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final m = _filtered[i];
                            final open = _open == i;
                            final title = '${m['title'] ?? ''}';
                            final text = '${m['text'] ?? ''}';
                            return Card(
                              color: dark ? AppColors.nightCard : Colors.white,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(() => _open = open ? null : i),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(crossAxisAlignment:
                                      CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Container(width: 4, height: 34,
                                          decoration: BoxDecoration(
                                              color: AppColors.primaryDark,
                                              borderRadius: BorderRadius.circular(4))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                            title.isEmpty ? text.split('\n').first : title,
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                fontSize: 14, color: txt)),
                                      ),
                                      if (kZikrAudios[title] != null)
                                        IconButton(
                                            tooltip: 'بیستنی دەنگی زیکر',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _zikrBusy
                                                ? null
                                                : () =>
                                                    _playZikr(kZikrAudios[title]!),
                                            icon: _zikrBusy
                                                ? const SizedBox(
                                                    width: 18, height: 18,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2))
                                                : Icon(
                                                    _zikrUrl == kZikrAudios[title] &&
                                                            _zikrState == PlayerState.playing
                                                        ? Icons.pause_circle_rounded
                                                        : Icons.play_circle_rounded,
                                                    size: 26,
                                                    color: AppColors.primaryDark)),
                                      const SizedBox(width: 6),
                                      Icon(open
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                          color: txt.withOpacity(.4)),
                                    ]),
                                    if (open) ...[
                                      const SizedBox(height: 10),
                                      Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: SelectableText(
                                            m['text2'] != null && '${m['text2']}'.isNotEmpty
                                                ? '$text\n\n${m['text2']}'
                                                : text,
                                            style: TextStyle(fontSize: 15,
                                                height: 1.9, color: txt)),
                                      ),
                                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                        FavoriteButton(id: '${widget.file}::$i', title: title.isEmpty ? widget.title : title, content: text),
                                        TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: '$title\n$text\n\n#ڕێگای ئیسلام'));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text('کۆپی کرا')));
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            label: const Text('کۆپی',
                                                style: TextStyle(fontSize: 12))),
                                        TextButton.icon(
                                            onPressed: () => Share.share(
                                                '$title\n\n$text\n\n#ڕێگای ئیسلام'),
                                            icon: const Icon(Icons.share_rounded, size: 16),
                                            label: const Text('هاوبەشی',
                                                style: TextStyle(fontSize: 12))),
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
}
