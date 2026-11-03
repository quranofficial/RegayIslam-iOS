import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../quiz/quiz_screen.dart';

/// Original: QuestionActivity — gateway to the quiz section.
class QuestionScreen extends StatelessWidget {
  const QuestionScreen({super.key});

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
          title: const Text('پرسیار و وەڵام',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? AppColors.nightCard : const Color(0xFFE8F0FE)),
                child: Icon(Icons.quiz_rounded, size: 60,
                    color: dark ? AppColors.gold : AppColors.primaryDark),
              ),
              const SizedBox(height: 18),
              Text('پرسیار و وەڵامی ئاینی',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold,
                      color: txt)),
              const SizedBox(height: 8),
              Text('پرسیارەکان لە سێرڤەرەوە دێن و هەموو جارێک نوێ دەبنەوە',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: txt.withOpacity(.6))),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 14)),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const QuizScreen())),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('دەستپێکردنی یاری')),
            ]),
          ),
        ),
      ),
    );
  }
}
