import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the one-time onboarding has already been shown on this device.
///
/// Synchronously readable on purpose: the router's `redirect` runs synchronously
/// and cannot await SharedPreferences. [main] loads the real value into it before
/// the first frame, so by the time anything routes, the flag is accurate.
///
/// It defaults to `true` — "already seen" — so that in the sliver of time before
/// main sets it, a returning user is never flashed the onboarding they finished
/// months ago. A genuine first-time user simply has the flag flipped to `false`
/// during bootstrap, before the splash hands off.
class OnboardingSeen extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final onboardingSeenProvider =
    NotifierProvider<OnboardingSeen, bool>(OnboardingSeen.new);

final onboardingServiceProvider =
    Provider<OnboardingService>((ref) => OnboardingService());

class OnboardingService {
  /// Versioned so that if the onboarding is ever meaningfully rebuilt, bumping
  /// the key re-shows it to existing users without touching anything else.
  static const _key = 'onboarding_seen_v1';

  Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
