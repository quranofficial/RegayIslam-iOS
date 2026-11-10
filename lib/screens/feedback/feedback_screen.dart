import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Original: FeedbackActivity — feedback form saved to Firebase "feedback"
/// (the original used a MailSender more block; RTDB keeps it working without
/// any credentials).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _name = TextEditingController();
  final _msg = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تکایە پەیامەکەت بنووسە')));
      return;
    }
    setState(() => _sending = true);
    await Rtdb.I.sendFeedback({
      'name': _name.text.trim(),
      'message': _msg.text.trim(),
      'date': DateTime.now().toIso8601String(),
      'app': 'regayislam-flutter',
    });
    if (!mounted) return;
    setState(() => _sending = false);
    _msg.clear();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پەیامەکەت نێردرا ✅ سوپاس')));
  }

  @override
  void dispose() { _name.dispose(); _msg.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('پەیام و ڕەخنە',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: _name,
              decoration: _dec('ناوت (ئارەزوومەندانە)', dark)),
          const SizedBox(height: 12),
          TextField(
              controller: _msg,
              maxLines: 6,
              decoration: _dec('پەیامەکەت...', dark)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('ناردن')),
        ]),
      ),
    );
  }

  InputDecoration _dec(String hint, bool dark) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: (dark ? Colors.white : Colors.black).withOpacity(.35)),
      filled: true,
      fillColor: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none));
}
