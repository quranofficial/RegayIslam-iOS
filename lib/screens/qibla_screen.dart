import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import '../core/ui.dart' show sharePage;

/// Original: QiblaActivity — compass pointing to the Kaaba
/// (21.4225° N, 39.8262° E) using the device magnetometer.
///
/// Item 14: rebuilt as a beautiful dial — degree ring, cardinal letters,
/// Kaaba marker riding the needle, green glow when aligned, haptic pulse,
/// live bearing + distance to the Kaaba.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double _heading = 0;
  double? _qiblaBearing;
  double? _lat, _lng;
  StreamSubscription<CompassEvent>? _sub;
  String? _error;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((e) {
      if (!mounted || e.heading == null) return;
      setState(() => _heading = e.heading!);
      final aligned = _alignedNow;
      if (aligned && !_wasAligned) _pulse();
      _wasAligned = aligned;
    });
    _locate();
  }

  bool get _alignedNow {
    if (_qiblaBearing == null) return false;
    final diff = ((_qiblaBearing! - _heading) % 360 + 360) % 360;
    return diff < 8 || diff > 352;
  }

  Future<void> _pulse() async {
    try {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: 120);
      }
    } catch (_) {}
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'ڕێگەی ناوخۆکە (location) نەدرا');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _qiblaBearing = _bearing(pos.latitude, pos.longitude);
      });
    } catch (e) {
      setState(() => _error = 'کێشە لە دیاریکردونی ناوخۆ');
    }
  }

  double _bearing(double lat, double lng) {
    const kaabaLat = 21.4225, kaabaLng = 39.8262;
    final phi1 = lat * math.pi / 180, phi2 = kaabaLat * math.pi / 180;
    final dl = (kaabaLng - lng) * math.pi / 180;
    final y = math.sin(dl) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dl);
    final b = math.atan2(y, x) * 180 / math.pi;
    return (b + 360) % 360;
  }

  double _distanceKm(double lat, double lng) {
    const kaabaLat = 21.4225, kaabaLng = 39.8262;
    const r = 6371.0;
    final dLat = (kaabaLat - lat) * math.pi / 180;
    final dLng = (kaabaLng - lng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat * math.pi / 180) *
            math.cos(kaabaLat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final aligned = _alignedNow;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xFF141414)
            : const Color(0xFFEAF2F8),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('قیبلە',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          actions: [
            IconButton(
                tooltip: 'هاوبەشی',
                onPressed: () => sharePage(
                    'قیبلەنمای ڕێگای ئیسلام — ئاڕاستەی قیبلە بە دروستی بدۆزەوە',
                    title: 'قیبلە'),
                icon: const Icon(Icons.share_rounded, color: Colors.white)),
          ],
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_error != null) ...[
              Icon(Icons.location_disabled_rounded, size: 60,
                  color: Colors.red.shade300),
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: txt)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                  onPressed: () async {
                    final enabled = await Geolocator.isLocationServiceEnabled();
                    if (!enabled) {
                      await Geolocator.openLocationSettings();
                      return;
                    }
                    final p = await Geolocator.checkPermission();
                    if (p == LocationPermission.deniedForever) {
                      await Geolocator.openAppSettings();
                    } else {
                      await _locate();
                    }
                  },
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text('دووبارە داوای مۆڵەتی شوێن بکە')),
            ] else ...[
              // status banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                    color: aligned
                        ? AppColors.green.withOpacity(.15)
                        : (dark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05)),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: aligned
                            ? AppColors.green.withOpacity(.6)
                            : Colors.transparent)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(aligned ? Icons.check_circle_rounded : Icons.explore_rounded,
                      size: 18,
                      color: aligned ? AppColors.green : (dark ? AppColors.gold : AppColors.primaryDark)),
                  const SizedBox(width: 8),
                  Text(
                      aligned
                          ? 'ئەمە ئاڕاستەی قیبلەیە ✅'
                          : 'مۆبایلەکە بچرخێنە هەتا ئاماژەکە بۆ سەرەوە بێت',
                      style: TextStyle(fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: aligned ? AppColors.green : txt)),
                ]),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 320, height: 320,
                child: Stack(alignment: Alignment.center, children: [
                  // soft glow behind the dial
                  Container(
                    width: 320, height: 320,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          (aligned ? AppColors.green : AppColors.primaryDark)
                              .withOpacity(.10),
                          Colors.transparent,
                        ])),
                  ),
                  // static dial with cardinal marks
                  CustomPaint(
                      size: const Size(320, 320),
                      painter: _DialPainter(dark: dark, heading: _heading)),
                  // rotating needle + Kaaba marker toward qibla
                  Transform.rotate(
                    angle: (_qiblaBearing ?? 0) * math.pi / 180 -
                        _heading * math.pi / 180,
                    child: SizedBox(
                      width: 320, height: 320,
                      child: CustomPaint(painter: _QiblaPainter(
                          dark: dark, aligned: aligned)),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark ? AppColors.nightCard : Colors.white,
                        border: Border.all(
                            color: aligned
                                ? AppColors.green
                                : (dark ? AppColors.gold.withOpacity(.4) : AppColors.primaryDark.withOpacity(.3)),
                            width: aligned ? 2.4 : 1.4),
                        boxShadow: [
                          BoxShadow(
                              color: (aligned ? AppColors.green : AppColors.primaryDark)
                                  .withOpacity(aligned ? .45 : .3),
                              blurRadius: aligned ? 26 : 12),
                        ]),
                    child: Icon(Icons.mosque_rounded, size: 38,
                        color: aligned ? AppColors.green : AppColors.primaryDark),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              // bearing + distance info card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: dark ? Colors.white.withOpacity(.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: dark ? Colors.white10 : Colors.black12)),
                child: Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.rotate_right_rounded, size: 15,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    const SizedBox(width: 5),
                    Text(
                        'گۆشەی قیبلە: ${_qiblaBearing?.toStringAsFixed(1) ?? '--'}°',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: dark ? AppColors.gold : AppColors.primaryDark)),
                  ]),
                  if (_lat != null && _lng != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        'دووری قیبلە: ${_distanceKm(_lat!, _lng!).toStringAsFixed(0)} کم — ناوخۆکەت: ${_lat!.toStringAsFixed(2)}, ${_lng!.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5,
                            color: txt.withOpacity(.6))),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Text('مۆبایلەکە تەخت ڕابگرە و لە دوور لە مێتال بەکاری بهێنە',
                  style: TextStyle(fontSize: 11, color: txt.withOpacity(.4))),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Fixed dial: degree ticks + cardinal letters that rotate with the phone.
class _DialPainter extends CustomPainter {
  _DialPainter({required this.dark, required this.heading});
  final bool dark;
  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    // dial ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = dark ? Colors.white24 : Colors.black26;
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius - 26,
        ring..strokeWidth = 1..color = (dark ? Colors.white12 : Colors.black12));

    // rotate ticks with the phone heading
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    for (var d = 0; d < 360; d += 15) {
      final major = d % 90 == 0;
      final tick = Paint()
        ..strokeWidth = major ? 2.4 : 1.2
        ..color = major
            ? (dark ? Colors.white54 : Colors.black45)
            : (dark ? Colors.white24 : Colors.black26);
      final a = d * math.pi / 180;
      final p1 = Offset(math.sin(a) * (radius - 2), -math.cos(a) * (radius - 2));
      final p2 = Offset(math.sin(a) * (radius - (major ? 14 : 9)),
          -math.cos(a) * (radius - (major ? 14 : 9)));
      canvas.drawLine(p1, p2, tick);
    }
    // cardinal letters
    const letters = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = (i * 90) * math.pi / 180;
      final pos = Offset(math.sin(a) * (radius - 34), -math.cos(a) * (radius - 34));
      final tp = TextPainter(
          text: TextSpan(text: letters[i], style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold,
              color: i == 0
                  ? Colors.redAccent
                  : (dark ? Colors.white70 : Colors.black54))),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.dark != dark || old.heading != heading;
}

/// Rotating layer: the Kaaba marker + green needle toward the qibla.
class _QiblaPainter extends CustomPainter {
  _QiblaPainter({required this.dark, required this.aligned});
  final bool dark;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // needle shaft
    final needle = Paint()
      ..style = PaintingStyle.fill
      ..color = aligned ? AppColors.green : AppColors.primaryDark;
    final path = Path()
      ..moveTo(center.dx - 12, center.dy)
      ..lineTo(center.dx, center.dy - radius + 44)
      ..lineTo(center.dx + 12, center.dy)
      ..close();
    canvas.drawPath(path, needle);

    // Kaaba marker at the tip
    final tip = Offset(center.dx, center.dy - radius + 34);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: tip, width: 26, height: 26),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawRect(
        Rect.fromCenter(center: tip - const Offset(0, 0), width: 26, height: 6),
        Paint()..color = const Color(0xFFC8A24B));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: tip, width: 26, height: 26),
            const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFD54F));
  }

  @override
  bool shouldRepaint(covariant _QiblaPainter old) =>
      old.dark != dark || old.aligned != aligned;
}
