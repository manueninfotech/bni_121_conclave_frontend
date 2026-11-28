/// Where the app should be, derived from auth AND whether the profile exists.
enum NavState { authLoading, signedOut, profileLoading, needsProfile, ready }

/// The router's whole decision, as a pure function so it can be tested.
///
/// Returns the path to go to, or null to stay. [takeLink] hands over a queued
/// shared link or notification route (and clears it); it is only consulted
/// when the member is signed in with a profile.
String? appRedirect({
  required NavState nav,
  required String path,
  required bool seenOnboarding,
  String? lockedConclaveId,
  required String? Function() takeLink,
}) {
  const preAuth = {'/', '/login', '/onboarding'};

  switch (nav) {
    case NavState.authLoading:
      // The ONLY time we hold on the splash: the brief check of whether
      // anyone is signed in. Everything else routes into the app.
      return path == '/' ? null : '/';

    case NavState.signedOut:
      if (!seenOnboarding) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      const authScreens = {
        '/login',
        '/register',
        '/onboarding',
        '/forgot-password',
      };
      return authScreens.contains(path) ? null : '/login';

    case NavState.profileLoading:
      // Signed in; profile still loading. Head to home optimistically; if
      // there is no profile, needsProfile routes on to /register next.
      // Someone mid-registration stays on /register.
      if (path == '/register') return null;
      return preAuth.contains(path) ? '/home' : null;

    case NavState.needsProfile:
      // Signed in without a profile: an unfinished registration. Back to it
      // (the register screen resumes at the profile step). A forgot-password
      // check signs in briefly and straight out again: leave it alone.
      if (path == '/forgot-password') return null;
      return path == '/register' ? null : '/register';

    case NavState.ready:
      // Rapido-style lock: while a round the member is seated in is live,
      // the round screen is the only reachable place. A queued link or
      // notification would surface later, out of context, so it is dropped.
      if (lockedConclaveId != null) {
        takeLink();
        final active = '/conclaves/$lockedConclaveId/active';
        return path == active ? null : active;
      }
      // A shared link or notification that arrived (maybe before sign-in).
      final link = takeLink();
      if (link != null && link != path) return link;
      // A member with a profile never belongs on sign-up: the moment the
      // profile is known (right after Create account), move on to Home.
      return preAuth.contains(path) || path == '/register' ? '/home' : null;
  }
}
