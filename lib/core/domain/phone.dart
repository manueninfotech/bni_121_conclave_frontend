/// Phone numbers.
///
/// The phone number IS the account identity here — a phone registration is
/// stored against a synthetic address `<e164-digits>@bni121.conclave` — so how a
/// number is normalised decides whether someone can get back into their account.
/// That makes guessing unacceptable.
///
/// Which is why there is a country picker rather than a silent "+91" prepend:
/// `9515409973` is a valid Indian mobile, but ten digits is equally a valid US
/// number, or a UK mobile with the leading 0 dropped. Assuming India works right
/// up until the first member outside India, and then locks them out of an
/// account they cannot see is wrong.
library;

class Country {
  final String name;
  final String code; // ISO 3166-1 alpha-2
  final String dial; // without the +
  final String flag;

  /// National number length, used for validation. Null where it varies too much
  /// to check usefully.
  final int? nationalLength;

  const Country({
    required this.name,
    required this.code,
    required this.dial,
    required this.flag,
    this.nationalLength,
  });
}

/// The countries BNI actually operates in, India first.
///
/// Deliberately not "every country on earth": a 240-item list is a scroll
/// nobody wants, and the ones here cover BNI's real footprint. Adding one is a
/// single line.
const List<Country> countries = [
  Country(name: 'India', code: 'IN', dial: '91', flag: '🇮🇳', nationalLength: 10),
  Country(name: 'United States', code: 'US', dial: '1', flag: '🇺🇸', nationalLength: 10),
  Country(name: 'United Kingdom', code: 'GB', dial: '44', flag: '🇬🇧'),
  Country(name: 'United Arab Emirates', code: 'AE', dial: '971', flag: '🇦🇪'),
  Country(name: 'Singapore', code: 'SG', dial: '65', flag: '🇸🇬', nationalLength: 8),
  Country(name: 'Australia', code: 'AU', dial: '61', flag: '🇦🇺'),
  Country(name: 'Canada', code: 'CA', dial: '1', flag: '🇨🇦', nationalLength: 10),
  Country(name: 'Malaysia', code: 'MY', dial: '60', flag: '🇲🇾'),
  Country(name: 'Sri Lanka', code: 'LK', dial: '94', flag: '🇱🇰'),
  Country(name: 'Germany', code: 'DE', dial: '49', flag: '🇩🇪'),
  Country(name: 'France', code: 'FR', dial: '33', flag: '🇫🇷'),
  Country(name: 'South Africa', code: 'ZA', dial: '27', flag: '🇿🇦'),
  Country(name: 'New Zealand', code: 'NZ', dial: '64', flag: '🇳🇿'),
  Country(name: 'Indonesia', code: 'ID', dial: '62', flag: '🇮🇩'),
  Country(name: 'Philippines', code: 'PH', dial: '63', flag: '🇵🇭'),
];

const Country defaultCountry = Country(
  name: 'India',
  code: 'IN',
  dial: '91',
  flag: '🇮🇳',
  nationalLength: 10,
);

class Phone {
  Phone._();

  /// Strips everything that isn't a digit. Users paste numbers with spaces,
  /// dashes and brackets, and none of that is part of the number.
  static String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Builds an E.164 number (`+919515409973`) from a country and a national
  /// number.
  ///
  /// Tolerates the two things people actually type: a leading 0 (the national
  /// trunk prefix, not part of the international number), and the dial code
  /// already included.
  static String toE164(Country country, String national) {
    var d = digitsOnly(national);

    if (d.startsWith('0')) d = d.replaceFirst(RegExp(r'^0+'), '');

    // "919515409973" typed into the national field with +91 selected — take it
    // as already-qualified rather than producing "+9191...".
    if (d.startsWith(country.dial) &&
        country.nationalLength != null &&
        d.length == country.dial.length + country.nationalLength!) {
      return '+$d';
    }

    return '+${country.dial}$d';
  }

  /// Validates a national number for a country. Returns null when it's fine.
  static String? validate(Country country, String national) {
    final d = digitsOnly(national);
    if (d.isEmpty) return 'Enter your phone number';

    final expected = country.nationalLength;
    if (expected != null && d.length != expected) {
      return 'A ${country.name} number is $expected digits';
    }
    if (expected == null && (d.length < 6 || d.length > 14)) {
      return 'That does not look like a valid number';
    }
    return null;
  }

  /// True when a string looks like a phone number rather than an email.
  static bool looksLikePhone(String s) =>
      RegExp(r'^\+?[0-9\s\-()]{6,20}$').hasMatch(s.trim());

  /// The identity Firebase Auth is keyed by.
  ///
  /// Firebase has no "sign in with phone AND password", so a phone registration
  /// is stored against a synthetic address. Every caller must build it through
  /// here — the original bug was login and registration each deriving it
  /// slightly differently, so `9515409973` and `+919515409973` became two
  /// different accounts and the user simply could not sign in.
  static String toAuthEmail(String e164) =>
      '${digitsOnly(e164)}@bni121.conclave';

  /// Splits a stored E.164 number back into a country and a national part, for
  /// pre-filling a form.
  static (Country, String) parseE164(String e164) {
    final d = digitsOnly(e164);

    // Longest dial code first, so +1 doesn't shadow +91.
    final sorted = [...countries]
      ..sort((a, b) => b.dial.length.compareTo(a.dial.length));

    for (final c in sorted) {
      if (d.startsWith(c.dial)) {
        return (c, d.substring(c.dial.length));
      }
    }
    return (defaultCountry, d);
  }
}
