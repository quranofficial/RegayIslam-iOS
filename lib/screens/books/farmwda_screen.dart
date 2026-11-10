import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;
import '../articles/json_article_screen.dart';
import 'sahih_muslim_screen.dart';

/// Original: FarmwdaActivity — the hadith hub: the Sahih Muslim summary
/// book (mu.db) and the 400-hadith article list (farmwda.json).
class FarmwdaScreen extends StatelessWidget {
  const FarmwdaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final items = <(String, String, IconData, Widget)>[
      ('پوختەی سەحیحی موسلیم', 'کتێبی فەرموودەکان بە بەشەکان', Icons.menu_book_rounded,
          const SahihMuslimScreen()),
      ('٤٠٠ فەرموودە', 'فەرموودە هەڵبژێرکراوەکان', Icons.format_quote_rounded,
          const JsonArticleScreen(file: 'assets/data/farmwda.json', title: '٤٠٠ فەرموودە')),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('فەرموودەکان',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: ListView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset(context, extra: 14)),
            children: [
          for (final it in items)
            Card(
              color: dark ? AppColors.nightCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => it.$4)),
                leading: CircleAvatar(
                    backgroundColor: AppColors.primaryDark.withOpacity(.1),
                    child: Icon(it.$3,
                        color: dark ? AppColors.gold : AppColors.primaryDark)),
                title: Text(it.$1,
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 14, color: txt)),
                subtitle: Text(it.$2,
                    style: TextStyle(fontSize: 12, color: txt.withOpacity(.55))),
                trailing: const Icon(Icons.chevron_left),
              ),
            ),
        ]),
      ),
    );
  }
}
