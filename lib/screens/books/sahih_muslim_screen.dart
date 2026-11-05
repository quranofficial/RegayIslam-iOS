import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Original: FarmudaActivity + PwxtaActivity — the "پوختەی سەحیحی موسلیم"
/// book over mu.db: chapter list (sarki) opening the hadith sections
/// (babat where bash = tag), with adjustable font size, favorites,
/// copy and share.
class SahihMuslimScreen extends StatefulWidget {
  const SahihMuslimScreen({super.key});
  @override
  State<SahihMuslimScreen> createState() => _SahihMuslimScreenState();
}

class _SahihMuslimScreenState extends State<SahihMuslimScreen> {
  late final Future<List<Map<String, Object?>>> _chapters;

  @override
  void initState() {
    super.initState();
    _chapters = Db.I.muChapters();
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
          title: const Text('پوختەی سەحیحی موسلیم',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _chapters,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final chapters = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = chapters[i];
                return Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MuslimChapterScreen(
                            title: '${c['title'] ?? ''}',
                            tag: '${c['tag'] ?? ''}'))),
                    leading: CircleAvatar(
                        backgroundColor: AppColors.primaryDark.withOpacity(.1),
                        child: Text(toArabicDigits(i + 1),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : AppColors.primaryDark))),
                    title: Text('${c['title'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Original: PwxtaActivity — hadith sections of one chapter (mu.db babat,
/// bash = tag) with font zoom and per-hadith favorites.
class MuslimChapterScreen extends StatefulWidget {
  const MuslimChapterScreen({super.key, required this.title, required this.tag});
  final String title;
  final String tag;
  @override
  State<MuslimChapterScreen> createState() => _MuslimChapterScreenState();
}

class _MuslimChapterScreenState extends State<MuslimChapterScreen> {
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  int? _open;
  late double _font;

  @override
  void initState() {
    super.initState();
    _font = AppPrefs.I.fontSize.toDouble();
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.muSection(widget.tag);
    if (!mounted) return;
    setState(() { _rows = rows; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          actions: [
            IconButton(
                onPressed: () {
                  if (_font > 14) { setState(() => _font -= 2); }
                  else { ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فۆنتەکە زۆر بچووکە'))); }
                },
                icon: const Icon(Icons.text_decrease_rounded, color: Colors.white)),
            IconButton(
                onPressed: () {
                  if (_font < 60) { setState(() => _font += 2); }
                  else { ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فۆنتەکە زۆر گەورەیە'))); }
                },
                icon: const Icon(Icons.text_increase_rounded, color: Colors.white)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? Center(child: Text('ئەم بەشە بەتاڵە',
                    style: TextStyle(color: txt.withOpacity(.5))))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = _rows[i];
                      final open = _open == i;
                      final title = '${r['sarder'] ?? ''}';
                      final text = '${r['drezha'] ?? ''}';
                      return Container(
                        decoration: BoxDecoration(
                            color: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          ListTile(
                            onTap: () => setState(() => _open = open ? null : i),
                            title: Text(title.isEmpty
                                ? text.split('\n').first
                                : title,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 14, color: txt)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              FavoriteButton(
                                  id: 'muslim::${r['bash']}::${r['_id']}',
                                  title: title.isEmpty ? widget.title : title,
                                  content: text),
                              Icon(open
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                                  color: txt.withOpacity(.4)),
                            ]),
                          ),
                          if (open) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: SelectableText(text,
                                    style: TextStyle(
                                        fontSize: _font, height: 1.9, color: txt)),
                              ),
                            ),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                        text: '$title\n$text\n\n#ڕێگای ئیسلام'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('کۆپی کرا')));
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('کۆپی',
                                      style: TextStyle(fontSize: 12))),
                              TextButton.icon(
                                  onPressed: () =>
                                      Share.share('$title\n\n$text\n\n#ڕێگای ئیسلام'),
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: const Text('هاوبەشی',
                                      style: TextStyle(fontSize: 12))),
                            ]),
                          ],
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
