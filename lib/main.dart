import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const BilliardsApp());

class BilliardsApp extends StatelessWidget {
  const BilliardsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro Billiards 2D',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07131C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF31D6A0),
          secondary: Color(0xFF4DB8FF),
        ),
      ),
      home: const PoolHome(),
    );
  }
}

class Ball {
  Ball(this.x, this.y, this.color, {this.number = 0, this.stripe = false});
  double x, y;
  double vx = 0, vy = 0;
  final Color color;
  final int number;
  final bool stripe;
  bool pocketed = false;
}

class PoolHome extends StatefulWidget {
  const PoolHome({super.key});
  @override
  State<PoolHome> createState() => _PoolHomeState();
}

class _PoolHomeState extends State<PoolHome> with SingleTickerProviderStateMixin {
  static const double w = 1000, h = 520, r = 13;
  late final AnimationController ticker;
  final List<Ball> balls = [];
  Offset? dragPoint;
  bool moving = false;
  bool versusComputer = true;
  bool computerTurn = false;
  bool gameOver = false;
  int playerScore = 0, cpuScore = 0;
  String message = 'اسحب للخلف ثم اترك لتضرب الكرة';
  double lastTick = 0;
  final Stopwatch clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    _rackBalls();
    ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)
      ..repeat();
    clock.start();
  }

  void _rackBalls() {
    balls.clear();
    balls.add(Ball(270, 260, Colors.white, number: 0));
    const colors = [
      Color(0xFFF4C542), Color(0xFF2878E8), Color(0xFFDA3434),
      Color(0xFF6C3DB8), Color(0xFFF18B2B), Color(0xFF159A68),
      Color(0xFF7A1D2B), Color(0xFF17191F), Color(0xFFF4C542),
      Color(0xFF2878E8), Color(0xFFDA3434), Color(0xFF6C3DB8),
      Color(0xFFF18B2B), Color(0xFF159A68), Color(0xFF7A1D2B),
    ];
    int n = 0;
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col <= row; col++) {
        final x = 680 + row * 24.0;
        final y = 260 + (col - row / 2) * 27.0;
        balls.add(Ball(x, y, colors[n % colors.length], number: n + 1, stripe: n % 2 == 1));
        n++;
      }
    }
    playerScore = 0; cpuScore = 0; gameOver = false; moving = false;
    computerTurn = false;
    message = 'اسحب للخلف ثم اترك لتضرب الكرة';
  }

  void _tick() {
    final now = clock.elapsedMicroseconds / 1000000.0;
    double dt = (now - lastTick).clamp(0.0, 0.025).toDouble();
    lastTick = now;
    if (dt == 0) return;
    bool anyMoving = false;
    for (final b in balls) {
      if (b.pocketed) continue;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      final speed = math.sqrt(b.vx * b.vx + b.vy * b.vy);
      if (speed > 0.1) {
        final next = math.max(0.0, speed - 105 * dt).toDouble();
        final scale = next / speed;
        b.vx *= scale; b.vy *= scale;
      } else {
        b.vx = 0; b.vy = 0;
      }
      // Cushions
      if (b.x < 62 + r) { b.x = 62 + r; b.vx = b.vx.abs() * .88; }
      if (b.x > 938 - r) { b.x = 938 - r; b.vx = -b.vx.abs() * .88; }
      if (b.y < 62 + r) { b.y = 62 + r; b.vy = b.vy.abs() * .88; }
      if (b.y > 458 - r) { b.y = 458 - r; b.vy = -b.vy.abs() * .88; }
      // Six pockets
      for (final p in _pockets) {
        if (math.pow(b.x - p.dx, 2) + math.pow(b.y - p.dy, 2) < 24 * 24) {
          if (b.number == 0) {
            b.x = 270; b.y = 260; b.vx = 0; b.vy = 0;
            message = 'دخلت الكرة البيضاء! أعد التصويب';
          } else {
            b.pocketed = true;
            if (computerTurn) { cpuScore++; } else { playerScore++; }
            message = computerTurn ? 'الكمبيوتر أدخل كرة' : 'رائع! أدخلت كرة';
          }
          break;
        }
      }
      if (math.sqrt(b.vx * b.vx + b.vy * b.vy) > 3) anyMoving = true;
    }
    // Ball-to-ball collisions
    for (int i = 0; i < balls.length; i++) {
      final a = balls[i];
      if (a.pocketed) continue;
      for (int j = i + 1; j < balls.length; j++) {
        final b = balls[j];
        if (b.pocketed) continue;
        double dx = b.x - a.x, dy = b.y - a.y;
        double d = math.sqrt(dx * dx + dy * dy);
        if (d < r * 2 && d > 0.001) {
          final nx = dx / d, ny = dy / d;
          final overlap = r * 2 - d;
          a.x -= nx * overlap * .5; a.y -= ny * overlap * .5;
          b.x += nx * overlap * .5; b.y += ny * overlap * .5;
          final rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
          if (rel > 0) {
            final impulse = rel * .94;
            a.vx -= impulse * nx; a.vy -= impulse * ny;
            b.vx += impulse * nx; b.vy += impulse * ny;
          }
        }
      }
    }
    if (anyMoving != moving) moving = anyMoving;
    if (mounted) setState(() {});
    if (!moving && computerTurn && !gameOver) {
      computerTurn = false;
      Future.delayed(const Duration(milliseconds: 650), _computerShot);
    }
  }

  List<Offset> get _pockets => const [
    Offset(55, 55), Offset(500, 52), Offset(945, 55),
    Offset(55, 465), Offset(500, 468), Offset(945, 465),
  ];

  void _startAim(Offset local, Size size) {
    if (moving || computerTurn || gameOver) return;
    final scale = size.width / w;
    final p = Offset(local.dx / scale, local.dy / scale);
    final cue = balls.firstWhere((b) => b.number == 0);
    if (!cue.pocketed) {
      dragPoint = p;
      setState(() {});
    }
  }

  void _endAim(Offset local, Size size) {
    if (dragPoint == null || moving || computerTurn || gameOver) return;
    final scale = size.width / w;
    final end = Offset(local.dx / scale, local.dy / scale);
    final cue = balls.firstWhere((b) => b.number == 0);
    final dx = cue.x - end.dx, dy = cue.y - end.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > 8) {
      final power = math.min(850.0, len * 5.2).toDouble();
      cue.vx = dx / len * power;
      cue.vy = dy / len * power;
      moving = true;
      message = 'الضربة بدأت...';
    }
    dragPoint = null;
    setState(() {});
  }

  void _computerShot() {
    if (!mounted || gameOver) return;
    final cue = balls.firstWhere((b) => b.number == 0);
    final target = balls.where((b) => b.number != 0 && !b.pocketed).toList();
    if (target.isEmpty) {
      gameOver = true; message = 'انتهت اللعبة!'; setState(() {}); return;
    }
    target.sort((a, b) => a.x.compareTo(b.x));
    final t = target[math.Random().nextInt(target.length)];
    double dx = t.x - cue.x, dy = t.y - cue.y;
    double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) len = 1;
    cue.vx = dx / len * 540;
    cue.vy = dy / len * 540;
    moving = true;
    message = 'دور الكمبيوتر...';
    setState(() {});
  }

  void _playAgain() { setState(_rackBalls); }
  void _toggleMode() {
    setState(() {
      versusComputer = !versusComputer;
      message = versusComputer ? 'اللعب ضد الكمبيوتر' : 'وضع التدريب';
    });
  }

  @override
  void dispose() { ticker.dispose(); clock.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF102936), Color(0xFF07131C), Color(0xFF03090E)]),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF153C42), borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF31D6A0).withOpacity(.5))),
                    child: const Icon(Icons.sports_baseball_rounded, color: Color(0xFF31D6A0), size: 26)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PRO BILLIARDS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    SizedBox(height: 3),
                    Text('OFFLINE • 8 BALL POOL', style: TextStyle(color: Color(0xFF8BA6B1), fontSize: 10, letterSpacing: 1.3)),
                  ])),
                  IconButton(onPressed: _toggleMode, tooltip: 'تغيير الوضع',
                    icon: Icon(versusComputer ? Icons.smart_toy_outlined : Icons.sports_esports,
                      color: const Color(0xFF31D6A0))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(children: [
                  _scoreCard('أنت', playerScore, const Color(0xFF31D6A0)),
                  const SizedBox(width: 10),
                  _scoreCard(versusComputer ? 'الكمبيوتر' : 'التدريب', cpuScore, const Color(0xFF4DB8FF)),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1000 / 520,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onPanStart: (d) => _startAim(d.localPosition, size),
                        onPanUpdate: (d) { if (dragPoint != null) setState(() {}); },
                        onPanEnd: (d) {
                          final cue = balls.firstWhere((b) => b.number == 0);
                          final start = dragPoint;
                          if (start != null) {
                            // Use the last global drag delta to create an intuitive pull-back shot.
                            final delta = d.velocity.pixelsPerSecond;
                            final dx = -delta.dx * 0.5;
                            final dy = -delta.dy * 0.5;
                            final len = math.sqrt(dx * dx + dy * dy);
                            if (len > 30 && !moving && !computerTurn) {
                              cue.vx = dx / len * math.min(850.0, len * 1.8).toDouble();
                              cue.vy = dy / len * math.min(850.0, len * 1.8).toDouble();
                              moving = true; message = 'الضربة بدأت...';
                            } else {
                              _endAim(d.localPosition, size);
                            }
                          }
                          dragPoint = null; setState(() {});
                        },
                        child: CustomPaint(
                          painter: PoolPainter(balls: balls, dragPoint: dragPoint, pockets: _pockets,
                            message: message),
                          child: const SizedBox.expand(),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(children: [
                  Text(message, textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB5CCD5), fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _actionButton(Icons.refresh_rounded, 'لعبة جديدة', _playAgain, filled: false)),
                    const SizedBox(width: 10),
                    Expanded(child: _actionButton(Icons.sports_esports_rounded,
                      versusComputer ? 'ضد الكمبيوتر' : 'وضع التدريب', _toggleMode, filled: true)),
                  ]),
                  const SizedBox(height: 7),
                  const Text('اسحب بإصبعك عكس اتجاه الضربة ثم اترك', style: TextStyle(color: Color(0xFF65818C), fontSize: 11)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCard(String label, int score, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF10232D), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.25))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFB8CDD4)))),
        Text('$score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      ]),
    ),
  );

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {required bool filled}) =>
    Material(
      color: filled ? const Color(0xFF31D6A0) : const Color(0xFF142A35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: filled ? const Color(0xFF06221A) : const Color(0xFFB9CDD4)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
              color: filled ? const Color(0xFF06221A) : const Color(0xFFB9CDD4))),
          ])),
      ),
    );
}

class PoolPainter extends CustomPainter {
  PoolPainter({required this.balls, required this.dragPoint, required this.pockets, required this.message});
  final List<Ball> balls;
  final Offset? dragPoint;
  final List<Offset> pockets;
  final String message;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 520);
    final outer = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 984, 504), const Radius.circular(30));
    canvas.drawRRect(outer, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFB77A3E), Color(0xFF4B2615), Color(0xFF9C5D2D), Color(0xFF32190F)],
    ).createShader(const Rect.fromLTWH(8, 8, 984, 504)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 28, 944, 464), const Radius.circular(22)),
      Paint()..color = const Color(0xFF1C100C));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 44, 912, 432), const Radius.circular(18)),
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF08764D), Color(0xFF075A3E), Color(0xFF06432F)]).createShader(const Rect.fromLTWH(44, 44, 912, 432)));
    // Felt texture lines and rails
    final linePaint = Paint()..color = Colors.white.withOpacity(.035)..strokeWidth = 1;
    for (int i = 0; i < 16; i++) {
      canvas.drawLine(Offset(70, 80 + i * 24.0), Offset(930, 80 + i * 24.0), linePaint);
    }
    final rail = Paint()..color = const Color(0xFFB3D4B6).withOpacity(.45)..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(61, 61, 878, 398), const Radius.circular(10)),
      Paint()..color = const Color(0xFF063B2B));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(65, 65, 870, 390), const Radius.circular(8)),
      Paint()..color = const Color(0xFF0B704A));
    // Pockets
    for (final p in pockets) {
      canvas.drawCircle(p, 25, Paint()..color = const Color(0xFF020607));
      canvas.drawCircle(p, 20, Paint()..shader = const RadialGradient(
        colors: [Color(0xFF000000), Color(0xFF10171A), Color(0xFF050708)],
      ).createShader(Rect.fromCircle(center: p, radius: 20)));
      canvas.drawCircle(p, 25, Paint()..color = const Color(0xFFCF9A5D).withOpacity(.28)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    // Diamonds on the rails
    for (int i = 0; i < 7; i++) {
      final x = 170 + i * 110.0;
      _diamond(canvas, Offset(x, 53));
      _diamond(canvas, Offset(x, 467));
    }
    for (int i = 0; i < 3; i++) {
      _diamond(canvas, Offset(53, 145 + i * 115.0));
      _diamond(canvas, Offset(947, 145 + i * 115.0));
    }
    // Aim guide
    final cue = balls.firstWhere((b) => b.number == 0);
    if (dragPoint != null && !cue.pocketed) {
      final dx = cue.x - dragPoint!.dx, dy = cue.y - dragPoint!.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 1) {
        final end = Offset(cue.x + dx / len * 250, cue.y + dy / len * 250);
        canvas.drawLine(Offset(cue.x, cue.y), end, Paint()
          ..color = const Color(0xFFDAFFF0).withOpacity(.8)..strokeWidth = 2..strokeCap = StrokeCap.round);
        for (int i = 1; i <= 7; i++) {
          final p = Offset(cue.x + dx / len * i * 30, cue.y + dy / len * i * 30);
          canvas.drawCircle(p, 2.2, Paint()..color = Colors.white.withOpacity(.75));
        }
      }
    }
    for (final b in balls) {
      if (b.pocketed) continue;
      _drawBall(canvas, b);
    }
    // Branding detail
    _text(canvas, 'PRO • BILLIARDS', const Offset(500, 486), 11, const Color(0xFFD9B47D), bold: true);
    canvas.restore();
  }

  void _diamond(Canvas canvas, Offset p) {
    final path = Path()..moveTo(p.dx, p.dy - 5)..lineTo(p.dx + 5, p.dy)
      ..lineTo(p.dx, p.dy + 5)..lineTo(p.dx - 5, p.dy)..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE4C28C));
  }

  void _drawBall(Canvas canvas, Ball b) {
    final center = Offset(b.x, b.y);
    canvas.drawCircle(center.translate(2.5, 4), 14, Paint()..color = Colors.black.withOpacity(.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final rect = Rect.fromCircle(center: center, radius: 13);
    canvas.drawCircle(center, 13, Paint()..shader = RadialGradient(
      center: const Alignment(-.35, -.42),
      radius: .95,
      colors: b.number == 0
        ? [Colors.white, const Color(0xFFE1E7E8), const Color(0xFF7E8A91)]
        : [Color.lerp(b.color, Colors.white, .7)!, b.color, Color.lerp(b.color, Colors.black, .55)!],
      stops: const [0, .42, 1],
    ).createShader(rect));
    if (b.stripe && b.number != 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawRect(Rect.fromLTWH(b.x - 14, b.y - 5, 28, 10), Paint()..color = Colors.white.withOpacity(.92));
      canvas.restore();
    }
    if (b.number > 0) {
      canvas.drawCircle(center, 5.2, Paint()..color = Colors.white.withOpacity(.94));
      final tp = TextPainter(text: TextSpan(text: '${b.number}', style: const TextStyle(
        color: Color(0xFF111820), fontSize: 6.5, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
    } else {
      canvas.drawCircle(center.translate(-4, -5), 3.5, Paint()..color = Colors.white.withOpacity(.75));
    }
  }

  void _text(Canvas canvas, String value, Offset center, double size, Color color, {bool bold = false}) {
    final tp = TextPainter(text: TextSpan(text: value, style: TextStyle(color: color, fontSize: size,
      fontWeight: bold ? FontWeight.w900 : FontWeight.normal, letterSpacing: 1.5)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant PoolPainter oldDelegate) => true;
}