import 'package:flutter/material.dart';
import '../articles/json_article_screen.dart';

/// Original: TawanakanmActivity — "تاوانەگەورەکان" (big sins) reader.
/// The original loaded its list via the generic JSON reader; we reuse it
/// with the tawanakan.json dataset.
class TawanakanmScreen extends StatelessWidget {
  const TawanakanmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JsonArticleScreen(
        file: 'assets/data/tawanakan.json', title: 'تاوانەگەورەکان');
  }
}
