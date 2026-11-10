import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

/// Public website used by every Share action so the shared content always
/// carries a working link (item 6: the app-store links can't be used —
/// the owner's own domain + the GitHub repo are shared instead).
const String kAppUrl = 'https://linkakam.com/Regayislam';
const String kRepoUrl = 'https://github.com/quranofficial/RegayIslam-iOS';
/// Item 6: the GitHub raw bases that replace the un-usable store links —
/// reciter audio, books (PDFs) and the databases are served from GitHub.
const String kQariRepoUrl = 'https://github.com/quranofficial/RegayIslam-iOS';
const String kBooksUrl = 'https://github.com/quranofficial/RegayIslam-iOS';
const String kDatabaseUrl = 'https://github.com/quranofficial/RegayIslam-iOS';

/// The original DB already writes some sura names as "سوڕەتی الفاتحة", so
/// composing "سوڕەتی $name" produced "سوڕەتی سوڕەتی الفاتحة". Strip the
/// existing prefix before composing.
String suraLabel(String name) {
  final n = name.trim();
  var stripped = n.replaceFirst(RegExp(r'^(سوڕەتی|سوورەتی|سورەتی|سورة|سورۃ|سُورَةُ)\s*'), '');
  stripped = stripped.replaceFirst(
      RegExp(r'^(سوڕەتی|سوورەتی|سورەتی|سورة|سورۃ)\s*'), '');
  return 'سوڕەتی $stripped';
}

/// Share helper used by every screen: title + body + app link.
Future<void> sharePage(String body, {String? title}) async {
  final head = (title == null || title.isEmpty) ? '' : '$title\n\n';
  final text = '$head$body\n\n'
      'ئەپڵیکەیشنی ڕێگای ئیسلام\n'
      'وێبسایت: $kAppUrl\n'
      '#ڕێگای_ئیسلام';
  await Share.share(text);
}

/// Copy helper matching the share layout.
Future<void> copyPage(String body) async {
  await Clipboard.setData(ClipboardData(
      text: '$body\n\nڕێگای ئیسلام — $kAppUrl\n#ڕێگای_ئیسلام'));
}

String _mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

/// Reusable media bar with a real seekbar and start/end times (item 19).
/// Works with any AudioPlayer; screens keep owning the player.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({
    super.key,
    required this.player,
    this.title,
    this.dark = false,
    this.card,
    this.onPlayPause,
    this.playing,
    this.accent = AppColors.primaryDark,
  });
  final AudioPlayer player;
  final String? title;
  final bool dark;
  final Color? card;
  final VoidCallback? onPlayPause;
  final bool? playing;
  final Color accent;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    widget.player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    widget.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    widget.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  bool get _playing {
    if (widget.playing != null) return widget.playing!;
    return _state == PlayerState.playing;
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final card = widget.card ?? (dark ? AppColors.nightCard : Colors.white);
    final txt = dark ? Colors.white : Colors.black;
    final maxMs = _dur.inMilliseconds.clamp(1, 1 << 40);
    final posMs = _pos.inMilliseconds.clamp(0, maxMs);
    return Container(
      decoration: BoxDecoration(
        color: card,
        border: Border(
            top: BorderSide(color: dark ? Colors.white10 : Colors.black12)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
              onPressed: widget.onPlayPause,
              icon: Icon(_playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                  size: 38, color: widget.accent),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null)
                      Text(widget.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11,
                              color: txt.withOpacity(.65),
                              fontWeight: FontWeight.w600)),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12),
                      ),
                      child: Slider(
                        value: posMs.toDouble(),
                        max: maxMs.toDouble(),
                        activeColor: widget.accent,
                        inactiveColor:
                            dark ? Colors.white12 : Colors.black12,
                        onChanged: (v) async {
                          final d = Duration(milliseconds: v.round());
                          setState(() => _pos = d);
                          try {
                            await widget.player.seek(d);
                            if (_state == PlayerState.paused ||
                                _state == PlayerState.stopped) {
                              await widget.player.resume();
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_mmss(_pos),
                              style: TextStyle(fontSize: 10.5,
                                  color: txt.withOpacity(.5))),
                          Text(_mmss(_dur),
                              style: TextStyle(fontSize: 10.5,
                                  color: txt.withOpacity(.5))),
                        ]),
                  ]),
            ),
          ]),
        ]),
      ),
    );
  }
}


/// Extra bottom padding that keeps lists/buttons above the system
/// navigation bar (item 9: دوگمەکانی خوارەوە لەبەر ناڤی مۆبایل دیار نەبوون).
double bottomInset(BuildContext context, {double extra = 12}) {
  final mq = MediaQuery.of(context);
  final bottom = mq.viewPadding.bottom > mq.padding.bottom
      ? mq.viewPadding.bottom
      : mq.padding.bottom;
  return bottom + extra;
}

/// One shared audio configuration so every sound in the app plays at a
/// steady, full volume on both Android and iPhone (item 2).
class AudioSetup {
  AudioSetup._();

  static bool _globalDone = false;

  /// Call once per player (initState) before first use.
  static Future<void> prepare(AudioPlayer player) async {
    try {
      if (!_globalDone) {
        // Audio focus + media routing via the global scope so the volume
        // matches other apps (lowLatency mode is quiet on some devices).
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.defaultToSpeaker},
          ),
        ));
        _globalDone = true;
      }
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
    } catch (_) {}
  }
}
