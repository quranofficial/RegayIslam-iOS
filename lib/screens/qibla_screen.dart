import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/prefs.dart';

/// Original: QiblaActivity — compass pointing to the Kaaba
/// (21.4225° N, 39.8262° E) using the device magnetometer.
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

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((e) {
      if (mounted && e.heading != null) setState(() => _heading = e.heading!);
    });
    _locate();
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final diff = _qiblaBearing == null ? 0.0 : (_qiblaBearing! - _heading);
    final aligned = diff.abs() < 8;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('قیبلەنما',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_error != null) ...[
              Icon(Icons.location_disabled_rounded, size: 60,
                  color: Colors.red.shade300),
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: txt)),
              const SizedBox(height: 14),
              OutlinedButton(
                  onPressed: () =>
                      launchUrl(Uri.parse('https://qiblafinder.withgoogle.com')),
                  child: const Text('کردنەوەی Qibla Finder لە وێب')),
            ] else ...[
              Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 280, height: 280,
                  child: Transform.rotate(
                    angle: (_qiblaBearing ?? 0) * math.pi / 180 - _heading * math.pi / 180,
                    child: CustomPaint(painter: _CompassPainter(
                        dark: dark, aligned: aligned)),
                  ),
                ),
                Icon(Icons.navigation_rounded, size: 40,
                    color: aligned ? AppColors.green : AppColors.primaryDark),
              ]),
              const SizedBox(height: 18),
              Text(
                  aligned
                      ? '✅ ئەمە ئاڕاستەی قیبلەیە'
                      : 'مۆبایلەکە بچرخێنە هەتا ئاماژەکە بۆ سەرەوە بێت',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: aligned ? AppColors.green : txt)),
              const SizedBox(height: 6),
              Text('گۆشەی قیبلە: ${_qiblaBearing?.toStringAsFixed(1) ?? '--'}°',
                  style: TextStyle(fontSize: 13, color: txt.withOpacity(.6))),
              const SizedBox(height: 2),
              Text('ناوخۆکەت: ${_lat?.toStringAsFixed(2) ?? '--'}, ${_lng?.toStringAsFixed(2) ?? '--'}',
                  style: TextStyle(fontSize: 11, color: txt.withOpacity(.4))),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.dark, required this.aligned});
  final bool dark;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = aligned ? AppColors.green : (dark ? Colors.white24 : Colors.black26);
    canvas.drawCircle(center, radius, ring);
    // N marker
    final tp = TextPainter(
        text: TextSpan(text: 'N', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold,
            color: dark ? Colors.white70 : Colors.black54)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, radius + 2));
    // needle towards qibla (top of rotated canvas)
    final needle = Paint()
      ..style = PaintingStyle.fill
      ..color = aligned ? AppColors.green : AppColors.primaryDark;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius + 14)
      ..lineTo(center.dx - 14, center.dy + 10)
      ..lineTo(center.dx + 14, center.dy + 10)
      ..close();
    canvas.drawPath(path, needle);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.dark != dark || old.aligned != aligned;
}
