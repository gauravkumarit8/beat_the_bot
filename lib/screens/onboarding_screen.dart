import 'package:flutter/material.dart';

import '../core/ads_service.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';
import 'home_screen.dart';

/// Three short pages shown the first time the app opens.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_PageData> _pages = [
    _PageData(
      icon: Icons.smart_toy_rounded,
      title: 'Meet Zed-9',
      body: 'A bot that keeps score and talks back. Beat him at reflexes, '
          'memory, precision and patterns.',
    ),
    _PageData(
      icon: Icons.local_fire_department_rounded,
      title: 'Train a little every day',
      body: 'Play the Daily Gauntlet, build your streak and climb the ranks. '
          'Skip days and your rank slips, but a streak freeze protects it.',
    ),
    _PageData(
      icon: Icons.tune_rounded,
      title: 'Your level, your pace',
      body: 'Pick Easy, Medium or Hard, or let Auto match your skill. '
          'Everything works offline.',
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.rank.setOnboarded();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(rank: widget.rank, ads: widget.ads),
      ),
    );
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip',
                      style: TextStyle(color: AppColors.muted, fontSize: 15)),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [for (final p in _pages) _page(p)],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.lime : AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _next,
                child: Text(last ? 'GET STARTED' : 'NEXT'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(_PageData p) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
              ),
              child: Icon(p.icon, size: 72, color: AppColors.lime),
            ),
            const SizedBox(height: 28),
            Text(
              p.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              p.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 16, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
