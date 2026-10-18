import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'pad_screen.dart';
import 'store.dart';

const _cyan = Color(0xFF00E5FF);
const _magenta = Color(0xFFE040FB);
const _gold = Color(0xFFD4A24C);

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  double _progress = 0.0;
  String _status = 'Memulai...';
  String? _warn;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Setiap langkah punya batas waktu & try-catch: loading TIDAK akan macet.
  Future<void> _step(
      String label, double p, Future<void> Function() job, int sec) async {
    if (mounted) {
      setState(() {
        _status = label;
        _progress = p;
      });
    }
    try {
      await job().timeout(Duration(seconds: sec));
    } catch (e) {
      debugPrint('$label -> $e');
      _warn = 'Dilewati: $label';
    }
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final st = Store.i;
    await _step('Membaca pengaturan', 0.15, st.init, 5);
    await _step('Memuat skin', 0.30, st.loadSkins, 5);
    await _step('Menyiapkan sample bawaan', 0.55, st.ensureDefaults, 15);
    await _step('Memetakan pad', 0.70, st.mapMissing, 5);
    await _step('Menyiapkan suara', 0.90,
        () => Engine.i.loadAll(st.pads), 15);
    if (mounted) {
      setState(() {
        _status = 'Siap!';
        _progress = 1.0;
      });
    }
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed < 2500) {
      await Future.delayed(Duration(milliseconds: 2500 - elapsed));
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (a, b, c) => const PadScreen(),
      transitionsBuilder: (a, anim, b, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final barW = min(w * 0.7, 420.0);
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _LoadPainter(_c)),
          Align(
            alignment: const Alignment(0, -0.22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DTX',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: _magenta, blurRadius: 24),
                      Shadow(color: _magenta, blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'K E N D A N G',
                  style: TextStyle(
                      fontSize: 18, letterSpacing: 6, color: Colors.white70),
                ),
              ],
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.62),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: barW,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222428),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: barW * _progress,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFFE040FB)]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_status,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                if (_warn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_warn!,
                        style: const TextStyle(
                            color: Colors.orangeAccent, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadPainter extends CustomPainter {
  final Animation<double> c;
  _LoadPainter(this.c) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    final t = c.value * 2 * pi;
    final center = Offset(size.width / 2, size.height * 0.40);
    final r = min(size.width, size.height) * 0.26;

    void arc(double rad, Color col, double start, double sweep, double w) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = col;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: rad), start, sweep, false, p);
    }

    arc(r, _cyan, t, 1.6, 4);
    arc(r * 1.14, _magenta, -t * 1.3, 2.0, 4);
    arc(r * 1.28, _gold, t * 0.7 + 1, 1.2, 3);

    const cols = [_cyan, _magenta, _gold];
    for (var k = 0; k < 8; k++) {
      final dir = k.isEven ? 1.0 : -1.0;
      final ang = t * dir * (0.5 + k * 0.1) + k;
      final rad = r * (1.35 + (k % 3) * 0.12);
      final pos = center + Offset(cos(ang) * rad, sin(ang) * rad);
      canvas.drawCircle(pos, 4, Paint()..color = cols[k % 3]);
    }

    const n = 40;
    final bw = size.width / (n * 1.6);
    final baseY = size.height * 0.93;
    for (var i = 0; i < n; i++) {
      final h = (sin(t * 3 + i * 0.5) + 1.3) * 22;
      final x = size.width * 0.5 + (i - n / 2) * bw * 1.6;
      final col = cols[i % 3].withAlpha(150);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseY - h, bw, h), const Radius.circular(2)),
        Paint()..color = col,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
