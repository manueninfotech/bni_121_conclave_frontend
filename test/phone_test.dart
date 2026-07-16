import 'package:flutter_test/flutter_test.dart';
import 'package:conclave_1_2_1/core/domain/phone.dart';

const india = Country(
    name: 'India', code: 'IN', dial: '91', flag: '🇮🇳', nationalLength: 10);
const uk = Country(name: 'United Kingdom', code: 'GB', dial: '44', flag: '🇬🇧');
const usa = Country(
    name: 'United States', code: 'US', dial: '1', flag: '🇺🇸', nationalLength: 10);

void main() {
  group('toE164', () {
    test('builds a full number from a country and a national number', () {
      expect(Phone.toE164(india, '9515409973'), '+919515409973');
    });

    // The bug that started this: the user typed 10 digits, the app looked up a
    // different account, and told them their password was wrong.
    test('a bare national number resolves to the registered identity', () {
      expect(
        Phone.toAuthEmail(Phone.toE164(india, '9515409973')),
        Phone.toAuthEmail('+919515409973'),
      );
    });

    test('strips the formatting people actually type', () {
      expect(Phone.toE164(india, '95154 09973'), '+919515409973');
      expect(Phone.toE164(india, '95154-09973'), '+919515409973');
      expect(Phone.toE164(india, '(95154) 09973'), '+919515409973');
    });

    test('drops a leading trunk 0 — it is not part of the international number', () {
      expect(Phone.toE164(uk, '07911123456'), '+447911123456');
    });

    test('tolerates the dial code already being in the field', () {
      // Someone pastes "919515409973" with +91 selected. Must not become +9191…
      expect(Phone.toE164(india, '919515409973'), '+919515409973');
    });

    // The reason this isn't a hardcoded "+91" prepend.
    test('the same ten digits mean different numbers in different countries', () {
      expect(Phone.toE164(india, '5551234567'), '+915551234567');
      expect(Phone.toE164(usa, '5551234567'), '+15551234567');
    });
  });

  group('validate', () {
    test('accepts a correct length', () {
      expect(Phone.validate(india, '9515409973'), isNull);
    });

    test('rejects too few or too many digits', () {
      expect(Phone.validate(india, '95154'), contains('10 digits'));
      expect(Phone.validate(india, '95154099731234'), contains('10 digits'));
    });

    test('rejects empty', () {
      expect(Phone.validate(india, ''), isNotNull);
    });

    test('is lenient where length genuinely varies', () {
      expect(Phone.validate(uk, '7911123456'), isNull);
      expect(Phone.validate(uk, '123'), isNotNull);
    });
  });

  group('toAuthEmail', () {
    test('is stable across equivalent spellings of the same number', () {
      // Every one of these is the same human being.
      const expected = '919515409973@bni121.conclave';
      expect(Phone.toAuthEmail('+919515409973'), expected);
      expect(Phone.toAuthEmail('919515409973'), expected);
      expect(Phone.toAuthEmail('+91 95154 09973'), expected);
      expect(Phone.toAuthEmail('+91-95154-09973'), expected);
    });
  });

  group('parseE164', () {
    test('splits a stored number back into country and national parts', () {
      final (c, national) = Phone.parseE164('+919515409973');
      expect(c.code, 'IN');
      expect(national, '9515409973');
    });

    // +1 is a prefix of nothing, but +91 starts with 9 and +1 starts with 1 —
    // matching short codes first would mis-assign numbers.
    test('prefers the longest matching dial code', () {
      final (c, _) = Phone.parseE164('+919515409973');
      expect(c.code, 'IN'); // not US (+1)
    });

    test('falls back to the default country for an unknown code', () {
      final (c, _) = Phone.parseE164('+9995551234');
      expect(c.code, defaultCountry.code);
    });
  });

  group('looksLikePhone', () {
    test('recognises numbers, not emails', () {
      expect(Phone.looksLikePhone('+919515409973'), isTrue);
      expect(Phone.looksLikePhone('9515409973'), isTrue);
      expect(Phone.looksLikePhone('eb@gmail.com'), isFalse);
    });
  });
}
