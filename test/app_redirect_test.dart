import 'package:conclave_1_2_1/core/app_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

String? go(
  NavState nav,
  String path, {
  bool onboarded = true,
  String? locked,
  String? link,
}) {
  var queued = link;
  return appRedirect(
    nav: nav,
    path: path,
    seenOnboarding: onboarded,
    lockedConclaveId: locked,
    takeLink: () {
      final l = queued;
      queued = null;
      return l;
    },
  );
}

void main() {
  group('sign-up', () {
    test(
      'a new account with a saved profile leaves sign-up for Home (the 26 Nov loop)',
      () {
        expect(go(NavState.ready, '/register'), '/home');
      },
    );

    test(
      'while the profile is missing, sign-up stays put and everything else returns to it',
      () {
        expect(go(NavState.needsProfile, '/register'), isNull);
        expect(go(NavState.needsProfile, '/conclaves'), '/register');
        expect(go(NavState.needsProfile, '/home'), '/register');
      },
    );

    test('profile still loading: someone mid-sign-up is not moved', () {
      expect(go(NavState.profileLoading, '/register'), isNull);
      expect(go(NavState.profileLoading, '/login'), '/home');
    });

    test('forgot password is left alone while it briefly signs in', () {
      expect(go(NavState.needsProfile, '/forgot-password'), isNull);
    });
  });

  group('signed out', () {
    test('first launch goes to onboarding, later to sign in', () {
      expect(go(NavState.signedOut, '/home', onboarded: false), '/onboarding');
      expect(go(NavState.signedOut, '/home'), '/login');
      expect(go(NavState.signedOut, '/register'), isNull);
    });

    test('only the splash while auth is unknown', () {
      expect(go(NavState.authLoading, '/home'), '/');
      expect(go(NavState.authLoading, '/'), isNull);
    });
  });

  group('signed in', () {
    test('a queued link opens once ready', () {
      expect(
        go(NavState.ready, '/home', link: '/conclaves/c-123456'),
        '/conclaves/c-123456',
      );
      expect(go(NavState.ready, '/home'), isNull);
    });

    test(
      'a live round locks the app to the round screen and drops queued links',
      () {
        expect(
          go(NavState.ready, '/home', locked: 'c1', link: '/profile/referrals'),
          '/conclaves/c1/active',
        );
        expect(
          go(NavState.ready, '/conclaves/c1/active', locked: 'c1'),
          isNull,
        );
      },
    );
  });
}
