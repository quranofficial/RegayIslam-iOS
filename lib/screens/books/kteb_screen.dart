import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';
import '../pdf/pdf_screen.dart';

/// Original: KtebActivity — library/books list (garanawa.db) opening the
/// chapter reader; PDF items open PdfScreen.
class KtebScreen extends StatelessWidget {
  const KtebScreen({super.key});

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
          title: const Text('کتێبخانە',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.books(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final books = snap.data!;
            if (books.isEmpty) {
              return Center(child: Text('کتێبێک بەردەست نییە',
                  style: TextStyle(color: txt.withOpacity(.6))));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              itemBuilder: (context, i) {
                final b = books[i];
                return Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () {
                      final title = '${b['title'] ?? 'کتێب'}';
                      final url = '${b['url'] ?? b['link'] ?? b['pdf'] ?? ''}'.trim();
                      if (url.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PdfScreen(title: title, url: url)));
                      } else {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => BookReaderScreen(
                            title: title, table: '${b['tableName'] ?? ''}')));
                      }
                    },
                    leading: CircleAvatar(
                        backgroundColor: AppColors.primaryDark.withOpacity(.1),
                        child: Icon(Icons.menu_book_rounded,
                            color: dark ? AppColors.gold : AppColors.primaryDark)),
                    title: Text('${b['title'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                    subtitle: Text('${b['desc'] ?? 'چیرۆک و بابەت'}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: txt.withOpacity(.55))),
                    trailing: FavoriteButton(id: 'book::${b['tableName']}',
                      title: '${b['title'] ?? 'کتێب'}',
                      content: '${b['desc'] ?? 'کتێبخانە'}'),
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

/// Original: BookActivity/PageActivity/Page1Activity — chapter list and
/// reader over mu.db (babat/sarki) with adjustable font size.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({super.key, required this.title, required this.table});
  final String title;
  final String table;
  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
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
    final rows = await Db.I.muSection(widget.table);
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
                onPressed: () =>
                    setState(() => _font = (_font - 2).clamp(12, 40)),
                icon: const Icon(Icons.text_decrease_rounded, color: Colors.white)),
            IconButton(
                onPressed: () =>
                    setState(() => _font = (_font + 2).clamp(12, 40)),
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
                  return Container(
                    decoration: BoxDecoration(
                        color: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      ListTile(
                        onTap: () => setState(() => _open = open ? null : i),
                        title: Text('${r['sarder'] ?? r['drezha'] ?? ''}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 14, color: txt)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FavoriteButton(id: 'bookchapter::${widget.table}::$i',
                            title: '${widget.title} — ${r['sarder'] ?? 'بابەت'}',
                            content: '${r['drezha'] ?? ''}'),
                          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: txt.withOpacity(.4)),
                        ]),
                      ),
                      if (open)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: SelectableText('${r['drezha'] ?? ''}',
                              style: TextStyle(fontSize: _font, height: 1.9,
                                  color: txt)),
                        ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
