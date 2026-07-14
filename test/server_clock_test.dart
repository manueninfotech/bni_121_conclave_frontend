import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:conclave_1_2_1/core/time/server_clock.dart';

/// The NTP offset the client will compute for a given exchange.
///
///   offset = ((t1 - t0) + (t2 - t3)) / 2
Future<Duration> offsetFor({
  required DateTime sentAt,
  required DateTime serverReceivedAt,
  required DateTime serverSentAt,
  required DateTime receivedAt,
}) async {
  final clock = ServerClock();
  await clock.syncWith(
    sentAt: sentAt,
    serverReceivedAt: serverReceivedAt,
    serverSentAt: serverSentAt,
    receivedAt: receivedAt,
  );
  return clock.offset;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final t0 = DateTime(2026, 7, 14, 10, 0, 0);

  group('ServerClock NTP offset', () {
    test('a perfectly synced clock has zero offset', () async {
      // 100ms each way, no processing time, clocks agree.
      final offset = await offsetFor(
        sentAt: t0,
        serverReceivedAt: t0.add(const Duration(milliseconds: 100)),
        serverSentAt: t0.add(const Duration(milliseconds: 100)),
        receivedAt: t0.add(const Duration(milliseconds: 200)),
      );
      expect(offset, Duration.zero);
    });

    test('detects a device clock running behind the server', () async {
      // Device is 5s behind. Latency 100ms each way.
      const skew = Duration(seconds: 5);
      final offset = await offsetFor(
        sentAt: t0,
        serverReceivedAt: t0.add(skew + const Duration(milliseconds: 100)),
        serverSentAt: t0.add(skew + const Duration(milliseconds: 100)),
        receivedAt: t0.add(const Duration(milliseconds: 200)),
      );
      expect(offset, skew);
    });

    test('detects a device clock running ahead of the server', () async {
      const skew = Duration(seconds: -5); // device is 5s ahead
      final offset = await offsetFor(
        sentAt: t0,
        serverReceivedAt: t0.add(skew + const Duration(milliseconds: 100)),
        serverSentAt: t0.add(skew + const Duration(milliseconds: 100)),
        receivedAt: t0.add(const Duration(milliseconds: 200)),
      );
      expect(offset, skew);
    });

    // THE REGRESSION. The sync endpoint does real Firestore work, so the server
    // spends seconds between receiving the request and answering it. The old
    // implementation had only one server timestamp and assumed it was taken at
    // the midpoint of the round trip — which mistook processing time for network
    // latency and shoved the device's clock SECONDS into the future, making the
    // countdown run fast. The four-timestamp form must be immune to it.
    test('server processing time does NOT corrupt the offset', () async {
      // Clocks agree exactly. 100ms each way. But the server takes 6 SECONDS
      // to do its Firestore work.
      const processing = Duration(seconds: 6);
      final serverRecv = t0.add(const Duration(milliseconds: 100));

      final offset = await offsetFor(
        sentAt: t0,
        serverReceivedAt: serverRecv,
        serverSentAt: serverRecv.add(processing),
        receivedAt: t0.add(const Duration(milliseconds: 200)) .add(processing),
      );

      // The clocks agree, so the offset must be zero — not ~3s (half the
      // processing time), which is what the naive midpoint estimate produced.
      expect(offset, Duration.zero);
      expect(offset.abs(), lessThan(const Duration(milliseconds: 500)));
    });

    test('slow processing AND real skew still resolves to the real skew', () async {
      const skew = Duration(seconds: 3);
      const processing = Duration(seconds: 4);
      final serverRecv = t0.add(skew + const Duration(milliseconds: 50));

      final offset = await offsetFor(
        sentAt: t0,
        serverReceivedAt: serverRecv,
        serverSentAt: serverRecv.add(processing),
        receivedAt: t0.add(const Duration(milliseconds: 100)).add(processing),
      );

      expect(offset, skew);
    });

    test('now() applies the offset', () async {
      const skew = Duration(seconds: 30);
      final clock = ServerClock();
      await clock.syncWith(
        sentAt: t0,
        serverReceivedAt: t0.add(skew),
        serverSentAt: t0.add(skew),
        receivedAt: t0,
      );

      final drift = clock.now().difference(DateTime.now().add(skew)).abs();
      expect(drift, lessThan(const Duration(seconds: 1)));
    });

    test('the offset survives a restart (offline devices keep their correction)',
        () async {
      const skew = Duration(seconds: 12);
      final first = ServerClock();
      await first.syncWith(
        sentAt: t0,
        serverReceivedAt: t0.add(skew),
        serverSentAt: t0.add(skew),
        receivedAt: t0,
      );

      // A fresh instance, as after an app restart with no connectivity.
      final restarted = ServerClock();
      await restarted.load();
      expect(restarted.offset, skew);
    });
  });
}
