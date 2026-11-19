import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const EmoApp());

class EmoApp extends StatelessWidget {
  const EmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إيمو والشاحن',
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const EmoPage(),
    );
  }
}

class EmoPage extends StatefulWidget {
  const EmoPage({super.key});

  @override
  State<EmoPage> createState() => _EmoPageState();
}

class _EmoPageState extends State<EmoPage> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _sub;
  Timer? _timer;
  late final AnimationController _enter;
  late final AnimationController _loop;

  int _level = 70;
  bool _real = false;
  bool? _demo;
  bool _was = false;

  bool get _charging => _demo ?? _real;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
      reverseDuration: const Duration(milliseconds: 1000),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _init();
  }

  Future<void> _init() async {
    await _refreshLevel();
    try {
      final s = await _battery.batteryState;
      _apply(s);
    } catch (_) {}
    _sub = _battery.onBatteryStateChanged.listen((s) {
      _demo = null;
      _apply(s);
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshLevel());
  }

  Future<void> _refreshLevel() async {
    try {
      final l = await _battery.batteryLevel;
      if (mounted) setState(() => _level = l);
    } catch (_) {}
  }

  void _apply(BatteryState s) {
    _real = s == BatteryState.charging || s == BatteryState.full;
    _refreshLevel();
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    setState(() {});
    if (_charging) {
      _enter.forward();
      if (!_was) HapticFeedback.mediumImpact();
    } else {
      _enter.reverse();
    }
    _was = _charging;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charging = _charging;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1220),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_enter, _loop]),
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: EmoPainter(
                    t: _enter.value,
                    loop: _loop.value,
                    level: _level / 100,
                  ),
                ),
              ),
            ),
            Text(
              charging ? 'جارٍ الشحن $_level%' : 'إيمو نائم',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                charging
                    ? 'إيمو سعيد لأن هاتفك يشحن.'
                    : 'وصّل الشاحن بهاتفك ليستيقظ إيمو.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF98A1BB)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                _demo = !_charging;
                _sync();
              },
              child: Text(charging ? 'افصل الشاحن (تجربة)' : 'جرّب توصيل الشاحن'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

class EmoPainter extends CustomPainter {
  EmoPainter({required this.t, required this.loop, required this.level});

  final double t;
  final double loop;
  final double level;

  static const _cyan = Color(0xFF35E0FF);
  static const _bodyColor = Color(0xFF3A4052);
  static const _edge = Color(0xFF6B7390);

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  RRect _rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  void _heart(Canvas c, double x, double y, double alpha) {
    final p = Path()
      ..moveTo(x, y - 3)
      ..cubicTo(x - 6, y - 9, x - 12, y, x, y + 8)
      ..cubicTo(x + 12, y, x + 6, y - 9, x, y - 3)
      ..close();
    c.drawPath(p, _fill(const Color(0xFFFF5C8A).withAlpha((255 * alpha).round())));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 380, size.height / 470);
    canvas.save();
    canvas.translate((size.width - 380 * s) / 2, (size.height - 470 * s) / 2);
    canvas.scale(s);

    final plugT = Curves.easeOutCubic.transform(_seg(t, 0.0, 0.2));
    final botT = _seg(t, 0.25, 0.42);
    final botScale = botT == 0 ? 0.0 : Curves.elasticOut.transform(botT);
    final happy = _seg(t, 0.8, 0.88);
    var openA = _seg(t, 0.35, 0.4) * (1 - happy);
    if (t > 0.55 && t < 0.59) openA = 0;

    if (botScale > 0.001) {
      canvas.save();
      canvas.translate(190, 180);
      canvas.scale(botScale);
      canvas.translate(-190, -180);

      final wave = happy * math.max(0, math.sin(loop * math.pi * 2)) * 0.6;
      canvas.save();
      canvas.translate(124, 112);
      canvas.rotate(wave);
      canvas.translate(-124, -112);
      canvas.drawRRect(_rr(116, 108, 12, 36, 6), _fill(const Color(0xFF4A5166)));
      canvas.restore();
      canvas.save();
      canvas.translate(256, 112);
      canvas.rotate(-wave);
      canvas.translate(-256, -112);
      canvas.drawRRect(_rr(252, 108, 12, 36, 6), _fill(const Color(0xFF4A5166)));
      canvas.restore();

      canvas.drawRRect(_rr(150, 168, 22, 12, 5), _fill(const Color(0xFF4A5166)));
      canvas.drawRRect(_rr(208, 168, 22, 12, 5), _fill(const Color(0xFF4A5166)));
      canvas.drawRRect(_rr(128, 68, 124, 104, 30), _fill(_bodyColor));
      canvas.drawRRect(_rr(128, 68, 124, 104, 30), _stroke(_edge, 1));
      canvas.drawRRect(_rr(140, 80, 100, 66, 20), _fill(const Color(0xFF0B0D12)));

      if (openA > 0) {
        final p = _fill(_cyan.withAlpha((255 * openA).round()));
        canvas.drawRRect(_rr(163, 100, 15, 22, 6), p);
        canvas.drawRRect(_rr(202, 100, 15, 22, 6), p);
      }
      if (happy > 0) {
        final a = (255 * happy).round();
        final eye = _stroke(_cyan.withAlpha(a), 5);
        canvas.drawPath(
            Path()
              ..moveTo(162, 116)
              ..quadraticBezierTo(170.5, 100, 179, 116),
            eye);
        canvas.drawPath(
            Path()
              ..moveTo(201, 116)
              ..quadraticBezierTo(209.5, 100, 218, 116),
            eye);
        canvas.drawPath(
            Path()
              ..moveTo(178, 127)
              ..quadraticBezierTo(190, 139, 202, 127),
            _stroke(_cyan.withAlpha(a), 4));
        final cheek = _fill(const Color(0xFFFF7AA8).withAlpha(a));
        canvas.drawCircle(const Offset(153, 128), 5, cheek);
        canvas.drawCircle(const Offset(227, 128), 5, cheek);

        for (final h in [
          [270.0, 70.0, 0.0],
          [110.0, 60.0, 0.5]
        ]) {
          final p = (loop + h[2]) % 1.0;
          final alpha = (p < 0.25 ? p / 0.25 : (1 - p) / 0.75) * happy;
          _heart(canvas, h[0], h[1] - 50 * p, alpha.clamp(0.0, 1.0));
        }
      }
      canvas.restore();
    }

    canvas.drawRRect(_rr(164, 252, 52, 104, 12), _fill(const Color(0xFFCFD3DC)));
    canvas.drawRRect(_rr(169, 260, 42, 84, 7), _fill(const Color(0xFF1C2230)));
    final h = 38 * level.clamp(0.08, 1.0);
    canvas.drawRRect(_rr(180, 328 - h, 20, h, 3), _fill(const Color(0xFF3DDC84)));
    if (plugT > 0.6) {
      canvas.drawPath(
        Path()
          ..moveTo(193, 266)
          ..lineTo(184, 282)
          ..lineTo(191, 282)
          ..lineTo(187, 296)
          ..lineTo(199, 278)
          ..lineTo(192, 278)
          ..close(),
        _fill(const Color(0xFFFFD23F)),
      );
    }

    canvas.save();
    canvas.translate(0, 55 * (1 - plugT));
    canvas.drawRRect(_rr(182, 356, 16, 22, 3), _fill(const Color(0xFFE9EBF0)));
    canvas.drawRect(const Rect.fromLTWH(187, 378, 6, 200), _fill(const Color(0xFFE9EBF0)));
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EmoPainter old) => true;
}
