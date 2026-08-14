import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../data/onboarding_service.dart';
import 'onboarding_art.dart';

/// The first-run tour.
///
/// Shown once, to a member who has never opened the app — before the login wall,
/// so their first impression is what the app does FOR them, not a password field.
/// The router gates it on [onboardingSeenProvider]; finishing or skipping flips
/// the flag and it is never shown again.
///
/// It renders on the plum hero backdrop the splash and login share, so it reads
/// as a continuation of the same brand moment rather than a separate screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  /// The live, fractional page position. Drives the parallax and the crimson
  /// bloom so the whole backdrop moves WITH the swipe instead of snapping.
  double _page = 0;

  static const _pages = <_Slide>[
    _Slide(
      art: ScheduleArt(),
      title: 'Your seat, every round',
      body: 'See exactly who you’re meeting and where to sit. Your schedule '
          'updates the moment a new round begins.',
    ),
    _Slide(
      art: ScanArt(),
      title: 'Attendance, signal or not',
      body: 'Captains scan members in seconds. It works with no network and '
          'syncs the instant you’re back online.',
    ),
    _Slide(
      art: ReferralArt(),
      title: 'Pass business in one tap',
      body: 'Give a referral to anyone at your table with a single tap. Add a '
          'note only if you want to.',
    ),
    _Slide(
      art: SummaryArt(),
      title: 'See what you built',
      body: 'After the conclave, review every connection you made and every '
          'referral you gave or received.',
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

  bool get _onLast => _page.round() >= _pages.length - 1;

  Future<void> _finish() async {
    // Persist first, then flip the in-memory flag so the router's redirect sees
    // "seen" the instant we navigate — otherwise it would bounce us straight
    // back to /onboarding.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
      ),
      // Hardware back walks the pages rather than exiting on page one.
      child: PopScope(
        canPop: _page.round() == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _controller.previousPage(
              duration: Motion.normal,
              curve: Motion.curve,
            );
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _Backdrop()),
              // The crimson bloom drifts across the top as you swipe.
              Positioned.fill(child: _Bloom(page: _page, count: _pages.length)),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      showSkip: !_onLast,
                      onSkip: _finish,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        itemBuilder: (context, i) {
                          // Parallax: the art lags the text slightly as the page
                          // slides, giving the layers depth.
                          final delta = i - _page;
                          return _SlideView(slide: _pages[i], parallax: delta);
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        Gap.lg,
                        context.pagePadding,
                        Gap.lg,
                      ),
                      child: ContentWidth(
                        max: 440,
                        child: Column(
                          children: [
                            _Dots(page: _page, count: _pages.length),
                            const SizedBox(height: Gap.xl),
                            PrimaryButton(
                              label: _onLast ? 'Get started' : 'Next',
                              icon: _onLast
                                  ? Icons.arrow_forward_rounded
                                  : Icons.chevron_right_rounded,
                              onPressed: _next,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  final Widget art;
  final String title;
  final String body;
  const _Slide({required this.art, required this.title, required this.body});
}

/// One page: the animated illustration above, the copy below.
class _SlideView extends StatelessWidget {
  final _Slide slide;

  /// Signed distance of this page from the viewport centre (−1..1 while swiping).
  final double parallax;

  const _SlideView({required this.slide, required this.parallax});

  @override
  Widget build(BuildContext context) {
    // Fade and lift the copy as the page settles into place.
    final settle = (1 - parallax.abs()).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: ContentWidth(
        max: 440,
        centerVertically: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Transform.translate(
                // The art slides at a different rate to the page: depth.
                offset: Offset(parallax * 48, 0),
                child: Center(
                  child: AspectRatio(aspectRatio: 1, child: slide.art),
                ),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Opacity(
              opacity: settle,
              child: Transform.translate(
                offset: Offset(0, (1 - settle) * 16),
                child: Column(
                  children: [
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.xxl),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;

  const _TopBar({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
        child: Row(
          children: [
            const Spacer(),
            AnimatedOpacity(
              opacity: showSkip ? 1 : 0,
              duration: Motion.fast,
              child: TextButton(
                onPressed: showSkip ? onSkip : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                ),
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The animated page indicator: the active dot stretches into a crimson pill.
class _Dots extends StatelessWidget {
  final double page;
  final int count;

  const _Dots({required this.page, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: Gap.sm),
          _dot((1 - (page - i).abs()).clamp(0.0, 1.0)),
        ],
      ],
    );
  }

  Widget _dot(double active) {
    return Container(
      width: 8 + 20 * active,
      height: 8,
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.white.withValues(alpha: 0.28),
          AppColors.crimson,
          active,
        ),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    );
  }
}

/// The base plum gradient — shared with the splash and the login hero.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.hero),
    );
  }
}

/// A crimson radial that tracks the swipe, so the light source moves with you.
class _Bloom extends StatelessWidget {
  final double page;
  final int count;

  const _Bloom({required this.page, required this.count});

  @override
  Widget build(BuildContext context) {
    // Slide the bloom's centre from left to right across the pages.
    final x = count <= 1 ? 0.0 : (page / (count - 1)) * 2 - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(x, -0.7),
          radius: 1.1,
          colors: [
            AppColors.crimson.withValues(alpha: 0.34),
            AppColors.crimson.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
