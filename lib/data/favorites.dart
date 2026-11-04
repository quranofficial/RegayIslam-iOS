import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/prefs.dart';

class FavoriteEntry {
  const FavoriteEntry({required this.id, required this.title, required this.content});
  final String id;
  final String title;
  final String content;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'content': content};
  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    content: '${json['content'] ?? ''}',
  );
}

class FavoritesStore {
  static const _key = 'regayislam_favorites';

  static Future<List<FavoriteEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) {
      try { return FavoriteEntry.fromJson(jsonDecode(e) as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<FavoriteEntry>().toList();
  }

  static Future<bool> contains(String id) async =>
    (await all()).any((e) => e.id == id);

  static Future<bool> toggle(FavoriteEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all();
    final exists = items.any((e) => e.id == entry.id);
    items.removeWhere((e) => e.id == entry.id);
    if (!exists) items.insert(0, entry);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
    return !exists;
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await all()..removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.id, required this.title, required this.content, this.color});
  final String id;
  final String title;
  final String content;
  final Color? color;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    FavoritesStore.contains(widget.id).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _saved ? 'لابردن لە دڵخوازەکان' : 'زیادکردن بۆ دڵخوازەکان',
    icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: widget.color ?? (_saved ? AppColors.gold : null)),
    onPressed: () async {
      final saved = await FavoritesStore.toggle(FavoriteEntry(
        id: widget.id, title: widget.title, content: widget.content));
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved ? 'زیادکرا بۆ دڵخوازەکان' : 'لابرا لە دڵخوازەکان'),
        duration: const Duration(seconds: 1)));
    },
  );
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await FavoritesStore.all();
    if (mounted) setState(() { _items = rows; _loading = false; });
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
          title: const Text('دڵخوازەکان', style: TextStyle(color: Colors.white)),
        ),
        body: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
            ? Center(child: Text('هیچ بابەتێک لە دڵخوازەکانت نییە',
                style: TextStyle(color: txt.withOpacity(.6))))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return Card(
                    color: dark ? AppColors.nightCard : Colors.white,
                    child: ListTile(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(item.title),
                          content: SingleChildScrollView(
                            child: SelectableText(item.content)),
                          actions: [TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('داخستن'))],
                        )),
                      leading: const Icon(Icons.bookmark_rounded, color: AppColors.gold),
                      title: Text(item.title, style: TextStyle(
                        fontWeight: FontWeight.bold, color: txt)),
                      subtitle: Text(item.content, maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: txt.withOpacity(.65))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          await FavoritesStore.remove(item.id);
                          _load();
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
