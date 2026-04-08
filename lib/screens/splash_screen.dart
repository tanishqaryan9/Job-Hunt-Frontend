import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _revealController;
  late AnimationController _exitController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _pulse;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat(reverse: true);

    _revealController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _exitController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _pulse = Tween<double>(begin: 0.91, end: 1.09).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _revealController, curve: Curves.elasticOut));

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _revealController,
            curve: const Interval(0.45, 1.0, curve: Curves.easeIn)));

    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _revealController,
                curve: const Interval(0.35, 1.0, curve: Curves.easeOut)));

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitController, curve: Curves.easeIn));

    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _revealController.forward();
    await Future.delayed(const Duration(milliseconds: 2600));
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    widget.onComplete();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _revealController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_orbitController, _pulseController, _revealController, _exitController]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitFade,
            child: Stack(
              children: [
                // ── Ambient background glow orbs ───────────────
                Positioned(
                  top: -100, left: -80,
                  child: _AmbientBlob(
                      color: AppTheme.accent.withOpacity(0.18), size: 300),
                ),
                Positioned(
                  bottom: -120, right: -80,
                  child: _AmbientBlob(
                      color: AppTheme.teal.withOpacity(0.12), size: 340),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.38,
                  left: MediaQuery.of(context).size.width * 0.45,
                  child: _AmbientBlob(
                      color: AppTheme.amber.withOpacity(0.08), size: 180),
                ),

                // ── Centre content ─────────────────────────────
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Orbit system
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer orbit ring
                            _OrbitRing(radius: 105, opacity: 0.12),
                            _OrbitRing(radius: 78,  opacity: 0.08),

                            // Outer orbit — 3 dots, clockwise
                            _OrbitingDot(
                              angle: _orbitController.value * 2 * math.pi,
                              radius: 105,
                              color: AppTheme.accent,
                              size: 11,
                            ),
                            _OrbitingDot(
                              angle: _orbitController.value * 2 * math.pi +
                                  (2 * math.pi / 3),
                              radius: 105,
                              color: AppTheme.teal,
                              size: 9,
                            ),
                            _OrbitingDot(
                              angle: _orbitController.value * 2 * math.pi +
                                  (4 * math.pi / 3),
                              radius: 105,
                              color: AppTheme.amber,
                              size: 7,
                            ),

                            // Inner orbit — 2 dots, counter-clockwise
                            _OrbitingDot(
                              angle: -_orbitController.value * 2 * math.pi,
                              radius: 78,
                              color: AppTheme.accentLight.withOpacity(0.7),
                              size: 6,
                            ),
                            _OrbitingDot(
                              angle: -_orbitController.value * 2 * math.pi +
                                  math.pi,
                              radius: 78,
                              color: AppTheme.tealLight.withOpacity(0.6),
                              size: 5,
                            ),

                            // Centre logo — scales + pulses in
                            FadeTransition(
                              opacity: _logoFade,
                              child: Transform.scale(
                                scale: _logoScale.value * _pulse.value,
                                child: _CentreIcon(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 44),

                      // App name + tagline
                      FadeTransition(
                        opacity: _textFade,
                        child: SlideTransition(
                          position: _textSlide,
                          child: Column(children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.heroGradient.createShader(bounds),
                              child: const Text(
                                'POSTING',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 46,
                                  letterSpacing: -2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'YOUR CAREER. ELEVATED.',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                letterSpacing: 3.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                // Corner accent dots
                for (final pos in [
                  const Alignment(-1, -1), const Alignment(1, -1),
                  const Alignment(-1,  1), const Alignment(1,  1),
                ])
                  Positioned.fill(
                    child: Align(
                      alignment: pos,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accent.withOpacity(0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Ambient blob ───────────────────────────────────────────────
class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

// ── Orbit ring ─────────────────────────────────────────────────
class _OrbitRing extends StatelessWidget {
  final double radius;
  final double opacity;
  const _OrbitRing({required this.radius, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: radius * 2, height: radius * 2,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppTheme.textFaint.withOpacity(opacity), width: 1,
      ),
    ),
  );
}

// ── Orbiting dot ───────────────────────────────────────────────
class _OrbitingDot extends StatelessWidget {
  final double angle;
  final double radius;
  final Color color;
  final double size;
  const _OrbitingDot({
    required this.angle, required this.radius,
    required this.color, required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.65), blurRadius: 10, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

// ── Centre glass icon ──────────────────────────────────────────
class _CentreIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.45),
            blurRadius: 36,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: AppTheme.teal.withOpacity(0.2),
            blurRadius: 60,
            spreadRadius: -4,
          ),
        ],
      ),
      child: const Icon(
        Icons.work_rounded,
        size: 46,
        color: Colors.white,
      ),
    );
  }
}
