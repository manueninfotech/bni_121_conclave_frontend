import 'package:conclave_1_2_1/core/domain/profile_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Same cases as the backend's src/domain/__tests__/placeholderProfile.test.ts.
void main() {
  test('rejects test-style and gibberish names', () {
    for (final n in [
      'Test User',
      'Test Member 09',
      'test',
      'John Doe',
      'ss',
      'S',
      'Demo',
      'Dummy Account',
      'Member 5',
      'user',
      'asdf',
      'Fake Name',
      'Test Verification User',
      '123',
      'hhh4jjas',
      'a12d1cw3',
      'hhhjjas',
      'asdkjh',
      'Ravi123',
      'qwerty uiop',
    ]) {
      expect(placeholderName(n), isTrue, reason: n);
    }
  });
  test('accepts real names', () {
    for (final n in [
      'Ravi Teja Kolli',
      'Dr.K.Pawan',
      'Ashok M',
      'T.Manideep',
      'Testa Reddy',
      'Demon Kumar',
      'Om',
      'SHAIK ABDUL RAHAMAN',
      'Kvsn Praveen',
      'Abhilash',
      'SRIKNTH LINGAMALLU',
      'Sekhara Babu P.S.',
      'YEDUKONDALU CH',
      'Ch Kiran',
      'K NAGARJUNA KAPIL',
      'Lakka Nagaraju',
      "D'Souza",
      'Venkata-Ramana',
      'Ananthchandra',
    ]) {
      expect(placeholderName(n), isFalse, reason: n);
    }
  });
  test('rejects random places, keeps real ones', () {
    for (final p in [
      'hhh4jjas',
      'a12d1cw3',
      'xkcdqwz',
      'Test',
      'zz',
      '123',
      'guntur@',
    ]) {
      expect(placeholderPlace(p), isTrue, reason: p);
    }
    for (final p in [
      'Guntur',
      'guntur',
      'Vijayawada',
      'Hyderabad, Telangana',
      'Guntur Region',
      'Narasaraopet',
      'Bhimavaram',
      'Navi Mumbai',
      'Mangalagiri (AP)',
    ]) {
      expect(placeholderPlace(p), isFalse, reason: p);
    }
  });
}
