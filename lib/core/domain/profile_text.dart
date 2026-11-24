/// Keeps test entries and keyboard mash out of member profiles. Mirrors the
/// server's `src/domain/placeholderProfile.ts` (which has the final say), so
/// members see the problem on the form instead of after submitting it.
library;

final _nameWords = RegExp(
  r'\b(test|tests|tester|testing|demo|dummy|sample|fake|mock|placeholder|asdf|asdfgh|qwerty|lorem|ipsum|xyz|abc|abcd|na|null|undefined)\b',
  caseSensitive: false,
);
final _namePatterns = [
  RegExp(r'^(john|jane)\s+doe$', caseSensitive: false),
  RegExp(
    r'^(user|member|guest|person|name|admin|customer)\s*\d*$',
    caseSensitive: false,
  ),
];
final _letter = RegExp(r'\p{L}', unicode: true);
final _nonLetter = RegExp(r'[^\p{L}]', unicode: true);
final _sameLetter = RegExp(
  r'^(\p{L})\1*$',
  unicode: true,
  caseSensitive: false,
);

/// "hhh4jjas", "a12d1cw3", "asdkjh": letters mixed with digits, a letter three
/// times in a row, five consonants in a row (not counting h), or keyboard runs.
bool gibberishWord(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r"[.'\-]"), '');
  if (w.isEmpty) return false;
  if (_letter.hasMatch(w) && RegExp(r'\d').hasMatch(w)) return true;
  if (RegExp(r'(\p{L})\1\1', unicode: true).hasMatch(w)) return true;
  if (RegExp(r'[bcdfgjklmnpqrstvwxz]{5,}').hasMatch(w)) return true;
  return RegExp(
    r'asdf|sdfg|dfgh|qwer|wert|zxcv|xcvb|hjkl|jkl|lkj|kjh|jhg|hgf|gfd|sdk|dkj',
  ).hasMatch(w);
}

List<String> _words(String s) =>
    s.split(RegExp(r'[\s,()/]+')).where((w) => w.isNotEmpty).toList();

bool placeholderName(String raw) {
  final name = raw.trim();
  if (RegExp(r"[^\p{L}\s.'\-]", unicode: true).hasMatch(name)) return true;
  if (_words(name).any(gibberishWord)) return true;
  final letters = name.replaceAll(_nonLetter, '');
  if (letters.length < 2) return true;
  if (_sameLetter.hasMatch(letters) && letters.length <= 4) return true;
  if (_nameWords.hasMatch(name)) return true;
  return _namePatterns.any((p) => p.hasMatch(name));
}

bool placeholderPlace(String raw) {
  final place = raw.trim();
  if (place.isEmpty) return false;
  final letters = place.replaceAll(_nonLetter, '');
  if (letters.length < 2 || _sameLetter.hasMatch(letters)) return true;
  if (RegExp(r"[^\p{L}\s.,'\-()]", unicode: true).hasMatch(place)) return true;
  if (_nameWords.hasMatch(place)) return true;
  return _words(place).any(gibberishWord);
}

/// Form validators.
String? validateFullName(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Enter your name';
  if (placeholderName(s)) {
    return 'Enter your real full name, using letters only';
  }
  return null;
}

String? validatePlace(String? v, {String empty = 'Enter your city'}) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return empty;
  if (placeholderPlace(s)) return 'Enter a real place, like Guntur';
  return null;
}
