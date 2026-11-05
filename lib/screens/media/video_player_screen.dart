import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Original: PlayvideoActivity / ViewActivity — in-app video playback
/// (mp4 from the Videokan repo, HLS m3u8 for the live channels) instead of
/// handing the link to an external app.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.title, required this.url});
  final String title;
  final String url;
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;
  bool _controls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
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
            : !_ready
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
