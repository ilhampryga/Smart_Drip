import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Logo: scale + fade ──────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // ── Text: slide up + fade ───────────────────────────────────────────────
  late final AnimationController _textController;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  // ── Dot loader ──────────────────────────────────────────────────────────
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // ── Logo animation ────────────────────────────────────────────────────
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // ── Text animation ────────────────────────────────────────────────────
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // ── Dot loader (loops) ────────────────────────────────────────────────
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runSequence();
    });
  }

  Future<void> _runSequence() async {
    await _logoController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo dari asset ───────────────────────────────────────────
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, child) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: child,
                ),
              ),
              child: Image.asset(
                'assets/logo_smart_drip.png',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 48),

            // ── Dot loader ────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _textController,
              builder: (_, child) => FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(position: _textSlide, child: child),
              ),
              child: _DotLoader(controller: _dotController),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dot Loader ───────────────────────────────────────────────────────────────

class _DotLoader extends StatelessWidget {
  const _DotLoader({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i / 3;
        final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
          ),
        );
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Opacity(
              opacity: anim.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
