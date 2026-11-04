import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Original: ListvideokanActivity — video list from Firebase "videoNew",
/// with comment count; opens PlayvideoActivity-equivalent.
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var v = await Rtdb.I.videos();
    if (v.isEmpty) v = await Rtdb.I.videoAll();
    if (!mounted) return;
    setState(() {
      _videos = v;
      _loading = false;
      _error = v.isEmpty ? 'هیچ ڤیدیۆیەک بەردەست نییە' : null;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_q.isEmpty) return _videos;
    return _videos
        .where((v) => '${v['title'] ?? v['name'] ?? ''}'
            .toLowerCase()
            .contains(_q.toLowerCase()))
        .toList();
  }

  void _open(Map<String, dynamic> v) {
    final link = '${v['url'] ?? v['link'] ?? v['video'] ?? v['videoUrl'] ?? v['youtube'] ?? ''}'.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی ڤیدیۆ لە Firebase نییە')));
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینکی ڤیدیۆ دروست نییە')));
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
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
          title: const Text('ڤیدیۆی ئاینی',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: txt.withOpacity(.6))))
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v),
                        decoration: InputDecoration(
                          hintText: 'گەڕان لە ڤیدیۆکان...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: dark ? AppColors.nightCard : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final v = _filtered[i];
                          final title = '${v['title'] ?? v['name'] ?? 'ڤیدیۆ'}';
                          return Card(
                            color: dark ? AppColors.nightCard : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              onTap: () => _open(v),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 64, height: 44,
                                  color: AppColors.primaryDark.withOpacity(.1),
                                  child: const Icon(Icons.ondemand_video_rounded,
                                      color: AppColors.primaryDark))),
                              title: Text(title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      fontSize: 13.5, color: txt)),
                              subtitle: Text('${v['desc'] ?? ''}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11,
                                      color: txt.withOpacity(.55))),
                              trailing: const Icon(Icons.play_circle_rounded,
                                  size: 30, color: AppColors.primaryDark),
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
