import 'package:flutter/material.dart';
import '../articles/json_article_screen.dart';

/// Original: TawanakanmActivity — "تاوەنە گەورەکان" (big sins) reader.
/// The original loaded its list via the generic JSON reader; we reuse it
/// with the tawanakan.json dataset. Item 8 (feedback): the section is
/// spelled exactly as the owner asked: تاوەنە گەورەکان.
class TawanakanmScreen extends StatelessWidget {
  const TawanakanmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const JsonArticleScreen(
        file: 'assets/data/tawanakan.json', title: 'تاوەنە گەورەکان');
  }
}
