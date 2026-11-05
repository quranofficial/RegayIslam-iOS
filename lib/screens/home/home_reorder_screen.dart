import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;

/// Item 8: "بتوانم دەستکاری بەشەکانە لە پەڕەی یەکەم بکەم" — reorder the
/// home feature grid up/down and persist the arrangement.
class HomeReorderScreen extends StatefulWidget {
  const HomeReorderScreen({super.key});
  @override
  State<HomeReorderScreen> createState() => _HomeReorderScreenState();
}

class _HomeReorderScreenState extends State<HomeReorderScreen> {
  List<_Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Default order mirrors HomeScreen._grid; persisted order wins.
    final defaults = const <_Item>[
      _Item('دڵخوازەکان', Icons.bookmarks_rounded),
      _Item('ئیدیتی قورئان', Icons.edit_note_rounded),
      _Item('نوێژکردن', Icons.mosque_rounded),
      _Item('ناوەکانی خودای گەورە', Icons.badge_rounded),
      _Item('ئایەتی کورسی', Icons.menu_book_rounded),
      _Item('پرسیار و وەڵام', Icons.quiz_rounded),
      _Item('ڤیدیۆی ئاینی', Icons.ondemand_video_rounded),
      _Item('تاوانەکانم', Icons.warning_amber_rounded),
      _Item('کتێبخانە', Icons.local_library_rounded),
      _Item('ڕوقیەی شەرعی', Icons.healing_rounded),
      _Item('زیکرەکان', Icons.self_improvement_rounded),
      _Item('فەرموودەکان', Icons.format_quote_rounded),
      _Item('مانگی ڕەمەزان', Icons.dark_mode_rounded),
      _Item('ئافرەتان', Icons.face_3_rounded),
      _Item('دوعا و پاڕانەوە', Icons.volunteer_activism_rounded),
      _Item('چۆن تۆبە بکەم', Icons.change_circle_rounded),
      _Item('حەج و عومرە', Icons.flight_land_rounded),
      _Item('ئەهلی ئاگر', Icons.local_fire_department_rounded),
      _Item('بەهەشت', Icons.park_rounded),
      _Item('دۆزەخ', Icons.whatshot_rounded),
      _Item('خەونامە', Icons.bedtime_rounded),
      _Item('ژیانی پێغەمبەرمان ﷺ', Icons.person_rounded),
      _Item('ژیانی پێغەمبەران', Icons.groups_rounded),
      _Item('هاوەڵانی پێغەمبەر ﷺ', Icons.people_rounded),
      _Item('سونەت', Icons.star_rounded),
      _Item('زانیاری قورئان', Icons.info_rounded),
      _Item('تاوانەگەورەکان', Icons.gavel_rounded),
      _Item('ڕاو بۆچونەکان', Icons.forum_rounded),
      _Item('وتە و ئامۆژگاری', Icons.record_voice_over_rounded),
      _Item('حەڕام کراوەکان', Icons.block_rounded),
      _Item('زیانەکانی گۆرانی', Icons.music_off_rounded),
      _Item('تاوانی غەیبەت', Icons.volume_off_rounded),
      _Item('چیرۆکی دەجال', Icons.crisis_alert_rounded),
      _Item('قیبلەنما', Icons.explore_rounded),
      _Item('دەنگی قورئان', Icons.graphic_eq_rounded),
      _Item('گەڕان لە قورئان', Icons.search_rounded),
      _Item('دوعاکانی نوێژ', Icons.waving_hand_rounded),
      _Item('کاتەکانی مانگ', Icons.calendar_month_rounded),
      _Item('خوێندنی ئایەتەکان', Icons.surround_sound_rounded),
      _Item('دروستکردنی ڤیدیۆ و وێنە', Icons.movie_creation_rounded),
      _Item('ڕێکخستنی بەشەکان', Icons.swap_vert_rounded),
    ];
    final order = AppPrefs.I.homeOrder;
    final byLabel = {for (final i in defaults) i.label: i};
    final out = <_Item>[];
    for (final l in order) {
      final it = byLabel.remove(l);
      if (it != null) out.add(it);
    }
    out.addAll(byLabel.values);
    setState(() { _items = out; _loading = false; });
  }

  Future<void> _save() async {
    AppPrefs.I.homeOrder = _items.map((e) => e.label).toList();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ڕێکخستن پاشەکەوت کرا ✅'),
        duration: Duration(seconds: 1)));
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _items.length) return;
    setState(() {
      final it = _items.removeAt(from);
      _items.insert(to, it);
    });
    _save();
  }

  /// Item 8: گۆڕینی ناوی بەشەکان — empty text restores the original name.
  Future<void> _rename(_Item it) async {
    final c = TextEditingController(
        text: AppPrefs.I.homeNames[it.label] ?? it.label);
    final ok = await showDialog<Object>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ناوی «${it.label}» بگۆڕە'),
          content: TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'ناوی نوێ', border: OutlineInputBorder())),
          actions: [
            if (AppPrefs.I.homeNames.containsKey(it.label))
              TextButton(
                  onPressed: () => Navigator.pop(d, 'reset'),
                  child: const Text('گەڕانەوە بۆ ناوی ئەسلی')),
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('لابردن')),
            ElevatedButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('پاشەکەوت')),
          ],
        ),
      ),
    );
    if (ok == null) return;
    if (ok == 'reset') {
      AppPrefs.I.setHomeName(it.label, null);
    } else if (ok == true) {
      AppPrefs.I.setHomeName(it.label, c.text.trim());
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ناوی بەش پاشەکەوت کرا ✅'),
        duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ڕێکخستنی بەشەکان',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      'بە گرتنی هەر بەشێک و ڕاکێشان بۆ سەرەوە/خوارەوە یان دوگمەکان بەکاری بهێنە؛ ڕێکخستنەکە پاشەکەوت دەکرێت.',
                      style: TextStyle(fontSize: 12, color: txt.withOpacity(.6))),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset(context, extra: 12)),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final it = _items.removeAt(oldIndex);
                        _items.insert(newIndex, it);
                      });
                      _save();
                    },
                    proxyDecorator: (child, index, animation) => ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 1.05)
                          .animate(animation),
                      child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: child),
                    ),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      final shown = AppPrefs.I.homeNames[it.label] ?? it.label;
                      return Container(
                        key: ValueKey(it.label),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: dark ? Colors.white10 : Colors.black12)),
                        child: ListTile(
                          dense: true,
                          leading: Icon(it.icon,
                              color: dark ? AppColors.gold : AppColors.primaryDark),
                          title: Text(shown,
                              style: TextStyle(fontSize: 13.5, color: txt)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            // Item 8: rename any section from the first page.
                            IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'گۆڕینی ناوی بەش',
                                onPressed: () => _rename(it),
                                icon: Icon(Icons.edit_rounded,
                                    size: 20,
                                    color: dark
                                        ? AppColors.gold
                                        : AppColors.primaryDark)),
                            IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: i == 0 ? null : () => _move(i, i - 1),
                                icon: Icon(Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: i == 0
                                        ? txt.withOpacity(.25)
                                        : (dark ? AppColors.gold : AppColors.primaryDark))),
                            IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: i == _items.length - 1
                                    ? null
                                    : () => _move(i, i + 1),
                                icon: Icon(Icons.arrow_downward_rounded,
                                    size: 20,
                                    color: i == _items.length - 1
                                        ? txt.withOpacity(.25)
                                        : (dark ? AppColors.gold : AppColors.primaryDark))),
                            Icon(Icons.drag_handle_rounded,
                                size: 18, color: txt.withOpacity(.35)),
                          ]),
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

class _Item {
  final String label;
  final IconData icon;
  const _Item(this.label, this.icon);
}
