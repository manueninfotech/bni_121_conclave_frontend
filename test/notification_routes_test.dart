import 'package:conclave_1_2_1/core/links/shared_links.dart';
import 'package:conclave_1_2_1/core/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each notification type opens its screen', () {
    expect(
      routeForNotification({'type': 'referral_received'}),
      '/profile/referrals',
    );
    expect(
      routeForNotification({'type': 'one_to_one_request'}),
      '/profile/one-to-ones',
    );
    expect(
      routeForNotification({'type': 'round_started', 'conclaveId': 'c-123456'}),
      '/conclaves/c-123456/active',
    );
    expect(
      routeForNotification({'type': 'table_changed', 'conclaveId': 'c-123456'}),
      '/conclaves/c-123456/active',
    );
    expect(
      routeForNotification({
        'type': 'conclave_completed',
        'conclaveId': 'c-123456',
      }),
      '/conclaves/c-123456/summary',
    );
    expect(
      routeForNotification({
        'type': 'schedule_ready',
        'conclaveId': 'c-123456',
      }),
      '/conclaves/c-123456',
    );
    expect(routeForNotification({'type': 'round_started'}), isNull);
  });

  test('a link in the payload wins', () {
    expect(
      routeForNotification({
        'type': 'x',
        'link': 'https://www.manuen.com/conclave/c/c-123456',
      }),
      '/conclaves/c-123456',
    );
    expect(
      routeForNotification({'link': '/profile/referrals'}),
      '/profile/referrals',
    );
    expect(routeForNotification({'link': '/conclaves/../admin'}), isNull);
    expect(
      routeForNotification({
        'link': 'https://evil.example/x',
        'type': 'referral_received',
      }),
      '/profile/referrals',
    );
  });

  test('a push tap waits in the queue for the router', () {
    openFromNotification({'type': 'referral_received'});
    expect(SharedLinks.take(), '/profile/referrals');
  });
}
