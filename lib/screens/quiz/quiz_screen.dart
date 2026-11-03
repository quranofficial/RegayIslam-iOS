import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Original: QuizActivity — quiz from Firebase RTDB "quiz" node; three answer
/// rounds with the original green/red colour feedback.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _index = 0;
  int _score = 0;
  int? _picked;
  bool _answered = false;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  Timer? _timer;
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await Rtdb.I.quiz();
    if (!mounted) return;
    if (q.isEmpty) {
      setState(() { _loading = false; _error = 'کێشەی هێنانەوەی پرسیارەکان — ئینتەرنێت بپشکنە'; });
      return;
    }
    q.shuffle();
    setState(() { _questions = q.take(20).toList(); _loading = false; });
    _startTimer();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _next(auto: true);
      }
    });
  }

  void _pick(int i) {
    if (_answered) return;
    _timer?.cancel();
    setState(() { _picked = i; _answered = true; });
    final q = _questions[_index];
    if (_letters[i] == _correctKey(q)) _score++;
  }

  void _next({bool auto = false}) {
    _timer?.cancel();
    if (_index >= _questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() { _index++; _picked = null; _answered = false; });
    _startTimer();
  }

  static const List<String> _letters = ['a', 'b', 'c', 'd'];

  String _opt(Map<String, dynamic> q, int i) {
    final l = _letters[i];
    for (final key in ['op$l', 'o$l', 'opt$l', l]) {
      final v = q[key];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
    }
    return '';
  }

  String _correctKey(Map<String, dynamic> q) =>
      '${q['ans'] ?? q['answer'] ?? ''}'.trim();

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    if (_loading) {
      return const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              backgroundColor: AppColors.nightBg,
              body: Center(child: CircularProgressIndicator())));
    }
    if (_error != null || _questions.isEmpty) {
      return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              backgroundColor: dark ? AppColors.nightBg : Colors.white,
              appBar: AppBar(backgroundColor: AppColors.primaryDark,
                  title: const Text('پرسیار و وەڵام',
                      style: TextStyle(color: Colors.white))),
              body: Center(child: Text(_error ?? 'پرسیارێک بەردەست نییە',
                  style: TextStyle(color: txt)))));
    }
    if (_finished) {
      return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              backgroundColor: dark ? AppColors.nightBg : Colors.white,
              appBar: AppBar(backgroundColor: AppColors.primaryDark,
                  title: const Text('ئەنجام',
                      style: TextStyle(color: Colors.white))),
              body: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_score >= _questions.length / 2
                        ? Icons.emoji_events_rounded
                        : Icons.emoji_people_rounded,
                    size: 80, color: AppColors.gold),
                const SizedBox(height: 14),
                Text('ئەنجامەکەت: $_score لە ${_questions.length}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: txt)),
                const SizedBox(height: 18),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() { _index = 0; _score = 0; _finished = false;
                        _answered = false; _picked = null; });
                      _startTimer();
                    },
                    child: const Text('دووبارەکردنەوە')),
              ]))));
    }
    final q = _questions[_index];
    final correct = _correctKey(q);
    Color cardColor(int i) {
      if (!_answered) {
        return dark ? AppColors.nightCard : Colors.white;
      }
      final isCorrect = _letters[i] == correct;
      final isPicked = _picked == i;
      if (isCorrect) return AppColors.green;
      if (isPicked) return AppColors.red;
      return dark ? AppColors.nightCard : Colors.white;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text('پرسیار ${_index + 1}/${_questions.length}',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          actions: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('✅ $_score',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(children: [
          LinearProgressIndicator(
              value: _seconds / 30, minHeight: 4,
              color: _seconds > 10 ? AppColors.green : AppColors.red,
              backgroundColor: Colors.grey.shade300),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: dark ? AppColors.nightCard : Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Text('${q['question'] ?? q['quiz'] ?? ''}',
                    style: TextStyle(fontSize: 16, height: 1.8,
                        fontWeight: FontWeight.bold, color: txt)),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < 4; i++)
                if (_opt(q, i).trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pick(i),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: cardColor(i),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: dark ? Colors.white10 : Colors.black12)),
                        child: Row(children: [
                          CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primaryDark,
                              child: Text(_letters[i].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_opt(q, i),
                                style: TextStyle(fontSize: 14.5,
                                    height: 1.6,
                                    color: _answered &&
                                            (_letters[i] == correct)
                                        ? Colors.white : txt)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                if (_answered)
                  Center(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 34, vertical: 12)),
                      onPressed: _next,
                      child: const Text('پرسیاری دواتر'))),
              const SizedBox(height: 20),
            ]),
          ),
        ]),
      ),
    );
  }
}
