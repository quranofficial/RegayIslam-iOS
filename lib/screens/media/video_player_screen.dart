import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';
import 'videos_screen.dart' show CommentsSheet;

/// Original: PlayvideoActivity / ViewActivity — in-app video playback
/// (mp4 from the Videokan repo, HLS m3u8 for the live channels) instead of
/// handing the link to an external app.
///
/// Optional folder/videoKey/initialLike/initialComment: when opened from
/// VideosScreen (direct mp4 with a known push key) a compact like + comment
/// actions bar is shown under the player. The live player passes nothing
/// and stays unchanged.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.url,
    this.folder,
    this.videoKey,
    this.initialLike,
    this.initialComment,
  });
  final String title;
  final String url;
  final String? folder;
  final String? videoKey;
  final int? initialLike;
  final int? initialComment;
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;
  bool _controls = true;
  Timer? _hideTimer;
  int _likes = 0;
  int _commentsCount = 0;

  bool get _hasVideo => (widget.videoKey ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLike ?? 0;
    _commentsCount = widget.initialComment ?? 0;
    _init();
  }

  Future<void> _init() async {
    final url = widget.url.startsWith('http://')
        ? widget.url.replaceFirst('http://', 'https://')
        : widget.url;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) return;
      await c.play();
      setState(() => _ready = true);
      c.addListener(() {
        if (!mounted) return;
        setState(() {});
        if (c.value.isCompleted) {
          c.pause();
        }
      });
      _armHide();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'پەخشکردن سەرکەوتوو نەبوو — تکایە پەیوەندی ئینتەرنێت بپشکنە و دواتر دووبارە هەوڵبدەرەوە');
    }
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controls = false);
      }
    });
  }

  void _toggle() {
    setState(() => _controls = !_controls);
    if (_controls) _armHide();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Same optimistic like as the videos list: bump the local count, write
  /// videoNew/<folder>/<key>/like in the DB, rollback + error snack on
  /// failure, per-device "already liked" guard in prefs.
  Future<void> _like() async {
    final folder = widget.folder ?? '';
    final key = widget.videoKey ?? '';
    if (folder.isEmpty || key.isEmpty) return;
    if (AppPrefs.I.isVideoLiked(key)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('پێشتر لایکت کردووە'),
          duration: Duration(milliseconds: 800)));
      return;
    }
    final before = _likes;
    setState(() => _likes = before + 1); // optimistic
    final next = await Rtdb.I.likeVideo(folder, key, 'like');
    if (!mounted) return;
    if (next != null) {
      AppPrefs.I.setVideoLiked(key, true);
      setState(() => _likes = next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لایک کرا ❤️'),
          duration: Duration(milliseconds: 900)));
    } else {
      // rollback the optimistic value on failure
      setState(() => _likes = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'لایک سەرکەوتوو نەبوو — ${Rtdb.I.lastError ?? 'ئینتەرنێت بپشکنە'}')));
    }
  }

  Future<void> _openComments() async {
    final folder = widget.folder ?? '';
    final key = widget.videoKey ?? '';
    if (key.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPrefs.I.day ? Colors.white : AppColors.nightCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => CommentsSheet(
          videoId: key, folder: folder, videoKey: key,
          onCounted: (n) {
            if (mounted) setState(() => _commentsCount = n);
          }),
    );
    if (!mounted) return;
    // Re-read the row so the counters reflect the database.
    final fresh = await Rtdb.I.get('videoNew/$folder/$key');
    if (fresh is Map && mounted) {
      setState(() {
        _likes = int.tryParse('${fresh['like']}') ?? _likes;
        _commentsCount = int.tryParse('${fresh['comment']}') ?? _commentsCount;
      });
    }
  }

  /// Compact like/comment bar shown under the video (list videos only).
  Widget _actionsBar(bool dark) {
    final accent = dark ? AppColors.gold : AppColors.primaryDark;
    final txt = dark ? Colors.white : Colors.black;
    final liked = AppPrefs.I.isVideoLiked(widget.videoKey ?? '');
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: dark ? AppColors.nightCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'لایک',
            visualDensity: VisualDensity.compact,
            onPressed: _like,
            icon: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 20,
                color: liked ? const Color(0xFFE91E63) : accent)),
          Text('$_likes',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: liked ? const Color(0xFFE91E63) : txt)),
          const SizedBox(width: 24),
          IconButton(
            tooltip: 'سەرنجەکان',
            visualDensity: VisualDensity.compact,
            onPressed: _openComments,
            icon: Icon(Icons.comment_rounded, size: 20, color: accent)),
          Text('$_commentsCount',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: txt)),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final value = _controller?.value;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14))))
            : Column(children: [
                Expanded(
                  child: !_ready
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          onTap: _toggle,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: value!.aspectRatio == 0
                                  ? 16 / 9
                                  : value.aspectRatio,
                              child: Stack(alignment: Alignment.bottomCenter, children: [
                                VideoPlayer(_controller!),
                                if (_controls) ..._controlsWidget(value),
                              ]),
                            ),
                          ),
                        ),
                ),
                if (_hasVideo) _actionsBar(dark),
              ]),
      ),
    );
  }

  List<Widget> _controlsWidget(VideoPlayerValue value) {
    final pos = value.position;
    final dur = value.duration;
    return [
      Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54])),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
                onPressed: () {
                  final c = _controller!;
                  c.value.isPlaying ? c.pause() : c.play();
                  _armHide();
                },
                icon: Icon(value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                    color: Colors.white, size: 32)),
            Text('${_fmt(pos)} / ${_fmt(dur)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
            child: Slider(
                value: dur.inMilliseconds > 0
                    ? pos.inMilliseconds / dur.inMilliseconds
                    : 0,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  final c = _controller!;
                  c.seekTo(dur * v);
                  _armHide();
                }),
          ),
        ]),
      ),
      if (value.isBuffering)
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ];
  }
}
