import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';
import '../../data/favorites.dart';
import '../misc/webview_screen.dart';
import 'video_player_screen.dart';

/// Original: LiveActivity — HLS channels (مەککە، مەدینە…) from the "Live"
/// node (stored as a JSON string array) played in-app with video_player.
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
    var l = await Rtdb.I.liveChannels();
    l = l.where((s) => '${s['url'] ?? s['link'] ?? ''}'.trim().isNotEmpty || '${s['name'] ?? ''}'.isNotEmpty).toList();
    if (!mounted) return;
    setState(() { _streams = l; _loading = false; _error = l.isEmpty ? 'پەخشێک بەردەست نییە — دواتر دووبارە هەوڵبدەرەوە' : null; });
  }

  void _open(Map<String, dynamic> s) {
    final link = '${s['url'] ?? s['link'] ?? s['video'] ?? s['stream'] ?? ''}'.trim();
    final title = _channelName(s);
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی پەخش لە Firebase نییە')));
      return;
    }
    final uri = Uri.tryParse(Uri.encodeFull(link));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی پەخش دروست نییە')));
      return;
    }
    final yt = link.contains('youtube.com') || link.contains('youtu.be');
    if (yt) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => WebViewScreen(title: title, url: link)));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(title: title, url: link)));
    }
  }

  /// Item 2: every channel always carries a visible name — when the DB has
  /// no name the channel is labeled "کەناڵی ١", "کەناڵی ٢", ... in order.
  String _channelName(Map<String, dynamic> s) {
    final n = '${s['name'] ?? s['title'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final i = _streams.indexOf(s) + 1;
    return 'کەناڵی $i';
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
                            leading: CircleAvatar(
                                backgroundColor: const Color(0xFFD32F2F),
                                backgroundImage:
                                    '${s['image'] ?? ''}'.startsWith('http')
                                        ? NetworkImage('${s['image']}')
                                        : null,
                                child: '${s['image'] ?? ''}'.startsWith('http')
                                    ? null
                                    : const Icon(Icons.wifi_tethering_rounded,
                                        color: Colors.white)),
                            title: Text(
                                _channelName(s),
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: txt)),
                            subtitle: Text(
                                'پەخشی ڕاستەوخۆ — کلیک بکە بۆ بینین',
                                style: TextStyle(fontSize: 11,
                                    color: txt.withOpacity(.5))),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              FavoriteButton(
                                  id: 'live::${s['url'] ?? s['name'] ?? 'live_stream'}',
                                  title: _channelName(s),
                                  content: '${s['url'] ?? s['link'] ?? ''}',
                                  route: 'live::${s['url'] ?? s['name'] ?? 'live_stream'}'),
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
