import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/aero_shards.dart';
import '../../active_conclave/presentation/round/round_timer.dart' show kDeckBottom;
import '../data/onboarding_service.dart';
import 'onboarding_visuals.dart';

/// The first-run tour.
///
/// Shown once, before the login wall, so the first impression is what the app
/// does for the member. Light and calm like the rest of the app: the brand mark
/// up top, a silk "stage" showing a real slice of the app per page, then one
/// bold line and one sentence. The router gates it on [onboardingSeenProvider];
/// finishing or skipping flips the flag for good.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final Widget visual;
  final String title;
  final String body;
  const _Page(this.visual, this.title, this.body);
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  static const _pages = <_Page>[
    _Page(
      WelcomeVisual(),
      'Welcome to\n1-2-1 Connect',
      'Structured one-to-one networking for BNI conclaves, from your first table to your last referral.',
    ),
    _Page(
      SeatVisual(),
      'Your seat, every round',
      'See your table and who you are meeting. When the round ends, the app tells you where to go next.',
    ),
    _Page(
      ScanVisual(),
      'Attendance, signal or not',
      'Captains scan you in with your QR code. It works without network and syncs when you are back online.',
    ),
    _Page(
      ReferralVisual(),
      'Pass business in one tap',
      'Give a referral to anyone at your table during the referral slot, with a note if you like.',
    ),
    _Page(
      SummaryVisual(),
      'See what you built',
      'After the conclave, your summary shows every referral and everyone you met, ready to save.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _pages.length - 1);
  bool get _onLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    // Persist first, then flip the in-memory flag so the router's redirect sees
    // "seen" the instant we navigate.
    await ref.read(onboardingServiceProvider).markSeen();
    ref.read(onboardingSeenProvider.notifier).set(true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_onLast) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    _controller.nextPage(duration: Motion.normal, curve: Motion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: PopScope(
        // Hardware back walks the pages rather than exiting on page one.
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _controller.previousPage(duration: Motion.normal, curve: Motion.curve);
          }
        },
        child: Scaffold(
          body: Stack(children: [
            // A living background: glass shards drifting on flowing ribbons.
            const Positioned.fill(child: AeroShards()),
            SafeArea(
            child: ContentWidth(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Gap.sm),
                    _Brand(showSkip: !_onLast, onSkip: _finish),
                    const SizedBox(height: Gap.lg),
                    // The visuals float over the living shard field.
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        itemBuilder: (context, i) {
                          final d = (_page - i).clamp(-1.0, 1.0);
                          return Opacity(
                            opacity: (1 - d.abs()).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(-d * 60, 0),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(Gap.lg),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _pages[i].visual,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    // Copy cross-fades with the page.
                    SizedBox(
                      height: 150,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Column(
                          key: ValueKey(_index),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              page.title,
                              style: context.text.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: Gap.sm),
                            Text(
                              page.body,
                              style: context.text.bodyLarge?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _Dots(count: _pages.length, page: _page),
                        const Spacer(),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              backgroundColor: kDeckBottom,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _onLast ? 'Get started' : 'Next',
                                key: ValueKey(_onLast),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.lg),
                  ],
                ),
              ),
            ),
          ),
          ]),
        ),
      ),
    );
  }
}

/// The app mark, the name, and Skip.
class _Brand extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;
  const _Brand({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Image.asset('assets/images/app_mark.png', width: 34, height: 34),
          const SizedBox(width: Gap.sm),
          Text(
            '1-2-1 Connect',
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showSkip ? 1 : 0,
            child: TextButton(
              onPressed: showSkip ? onSkip : null,
              style: TextButton.styleFrom(foregroundColor: context.scheme.onSurfaceVariant),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ink progress dots; the active one stretches as you swipe.
class _Dots extends StatelessWidget {
  final int count;
  final double page;
  const _Dots({required this.count, required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Builder(builder: (context) {
            final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 8 + 16 * t,
              height: 8,
              decoration: BoxDecoration(
                color: Color.lerp(context.scheme.outlineVariant, context.scheme.onSurface, t),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
      ],
    );
  }
}
