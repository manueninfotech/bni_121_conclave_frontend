import 'package:conclave_1_2_1/core/links/shared_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the share link', () {
    expect(
      SharedLinks.conclave('conc-123456').toString(),
      'https://www.manuen.com/conclave/c/conc-123456',
    );
  });

  test('routes our conclave links, ignores everything else', () {
    expect(
      SharedLinks.routeFor(
        Uri.parse('https://www.manuen.com/conclave/c/conc-123456'),
      ),
      '/conclaves/conc-123456',
    );
    expect(
      SharedLinks.routeFor(
        Uri.parse('https://manuen.com/conclave/c/conc-123456/'),
      ),
      '/conclaves/conc-123456',
    );
    expect(
      SharedLinks.routeFor(
        Uri.parse('https://www.manuen.com/conclave/privacy'),
      ),
      isNull,
    );
    expect(
      SharedLinks.routeFor(
        Uri.parse('https://evil.example/conclave/c/conc-123456'),
      ),
      isNull,
    );
    expect(
      SharedLinks.routeFor(
        Uri.parse('https://www.manuen.com/conclave/c/..%2F..'),
      ),
      isNull,
    );
    expect(
      SharedLinks.routeFor(
        Uri.parse('com.googleusercontent.apps.1://firebaseauth/link?x=1'),
      ),
      isNull,
    );
  });

  test('a link waits until the router takes it, once', () {
    var pinged = 0;
    SharedLinks.arrived.addListener(() => pinged++);
    SharedLinks.offer('/conclaves/conc-123456');
    expect(pinged, 1);
    expect(SharedLinks.take(), '/conclaves/conc-123456');
    expect(SharedLinks.take(), isNull);
  });
}
