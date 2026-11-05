import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Original: PageActivity — the "چۆن تەوبە بکەم" book over garanawa.db.
/// babatakan lists the topics; rows carrying a tableName open one of the
/// four section tables (bochetawbabkain, chontawbabkam, marjakanitawba,
/// neshanayqbulitawba), plain rows expand into their text.
class TawbaScreen extends StatefulWidget {
  const TawbaScreen({super.key});
  @override
  State<TawbaScreen> createState() => _TawbaScreenState();
}

class _TawbaScreenState extends State<TawbaScreen> {
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  int? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.garanawaTable('babatakan');
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
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('چۆن تەوبە بکەم',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = _rows[i];
                  final table = '${r['tableName'] ?? ''}'.trim();
                  final title = '${r['title'] ?? ''}';
                  final text = '${r['desc'] ?? ''}';
                  if (table.isNotEmpty) {
                    return Card(
                      color: dark ? AppColors.nightCard : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TawbaSectionScreen(
                                table: table, title: title))),
                        leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryDark.withOpacity(.1),
                            child: Text(r['idku']?.toString() ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: dark
                                        ? AppColors.gold
                                        : AppColors.primaryDark))),
                        title: Text(title,
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 14, color: txt)),
                        trailing: const Icon(Icons.chevron_left),
                      ),
                    );
                  }
                  final open = _open == i;
                  return Container(
                    decoration: BoxDecoration(
                        color: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      ListTile(
                        onTap: () => setState(() => _open = open ? null : i),
                        leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryDark.withOpacity(.1),
                            child: Text(r['idku']?.toString() ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: dark
                                        ? AppColors.gold
                                        : AppColors.primaryDark))),
                        title: Text(title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 14, color: txt)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FavoriteButton(id: 'tawba::${r['_id']}',
                              title: title, content: text),
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
                                style: TextStyle(fontSize: 15, height: 1.9,
                                    color: txt)),
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

/// One of the four garanawa.db section tables (bịchûn tawba, çon tawba,
/// mercanî tawba, nîşaney qebûlî tawba).
class TawbaSectionScreen extends StatefulWidget {
  const TawbaSectionScreen({super.key, required this.table, required this.title});
  final String table;
  final String title;
  @override
  State<TawbaSectionScreen> createState() => _TawbaSectionScreenState();
}

class _TawbaSectionScreenState extends State<TawbaSectionScreen> {
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
    final rows = await Db.I.garanawaTable(widget.table);
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
                onPressed: () => setState(
                    () => _font = (_font - 2).clamp(12, 60)),
                icon: const Icon(Icons.text_decrease_rounded, color: Colors.white)),
            IconButton(
                onPressed: () => setState(
                    () => _font = (_font + 2).clamp(12, 60)),
                icon: const Icon(Icons.text_increase_rounded, color: Colors.white)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = _rows[i];
                  final open = _open == i;
                  final title = '${r['title'] ?? ''}';
                  final text = '${r['desc'] ?? ''}';
                  return Container(
                    decoration: BoxDecoration(
                        color: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      ListTile(
                        onTap: () => setState(() => _open = open ? null : i),
                        leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryDark.withOpacity(.1),
                            child: Text(
                                r['idku']?.toString().isNotEmpty == true
                                    ? '${r['idku']}'
                                    : toArabicDigits(i + 1),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: dark
                                        ? AppColors.gold
                                        : AppColors.primaryDark))),
                        title: Text(title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 14, color: txt)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FavoriteButton(
                              id: 'tawba::${widget.table}::${r['_id']}',
                              title: title, content: text),
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
                                style: TextStyle(fontSize: _font, height: 1.9,
                                    color: txt)),
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
