import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';
import '../../data/favorites.dart';
import '../misc/webview_screen.dart';

/// Original: LiveActivity — live streams from Firebase RTDB "Live"/"livemuslim".
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Map<String, dynamic>> _streams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var l = await Rtdb.I.live();
    if (l.isEmpty) l = await Rtdb.I.liveMuslim();
    if (!mounted) return;
    setState(() { _streams = l; _loading = false; _error = l.isEmpty ? 'پەخشێک بەردەست نییە — دواتر دووبارە هەوڵبدەرەوە' : null; });
  }

  void _open(Map<String, dynamic> s) {
    final link = '${s['link'] ?? s['url'] ?? s['video'] ?? s['videoUrl'] ?? s['stream'] ?? s['youtube'] ?? ''}'.trim();
    final title = '${s['name'] ?? s['title'] ?? 'پەخشی ڕاستەوخۆ'}';
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی پەخش لە Firebase نییە')));
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی پەخش دروست نییە')));
      return;
    }
    final yt = link.contains('youtube.com') || link.contains('youtu.be');
    if (yt) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => WebViewScreen(title: title, url: link)));
    } else {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
          title: const Text('پەخشی ڕاستەوخۆ',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: txt.withOpacity(.6))))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final s in _streams)
                        Card(
                          color: dark ? AppColors.nightCard : Colors.white,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            onTap: () => _open(s),
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFD32F2F),
                                child: Icon(Icons.wifi_tethering_rounded,
                                    color: Colors.white)),
                            title: Text(
                                '${s['name'] ?? s['title'] ?? 'پەخش'}',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: txt)),
                            subtitle: Text('${s['desc'] ?? s['text'] ?? ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12,
                                    color: txt.withOpacity(.55))),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              FavoriteButton(id: 'live::${s['id'] ?? s['url'] ?? s['link'] ?? title}',
                                title: title, content: '${s['desc'] ?? s['url'] ?? s['link'] ?? ''}'),
                              const Icon(Icons.play_circle_rounded,
                                color: Color(0xFFD32F2F), size: 30),
                            ]),
                          ),
                        ),
                    ]),
      ),
    );
  }
}
