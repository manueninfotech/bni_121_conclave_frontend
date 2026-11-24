import 'package:conclave_1_2_1/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserProfile p(String email) => UserProfile.fromMap('u1', {'name': 'Asha Rao', 'email': email});

  test('only a reachable email counts', () {
    expect(p('asha@gmail.com').hasRealEmail, isTrue);
    expect(p('').hasRealEmail, isFalse);
    expect(p('919515409973@bni121.conclave').hasRealEmail, isFalse);
  });
}
