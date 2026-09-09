import 'package:certigo/features/auth/application/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('doPasswordsMatch', () {
    test('confirmation vide -> faux, meme si le mot de passe est vide', () {
      expect(doPasswordsMatch('', ''), isFalse);
      expect(doPasswordsMatch('secret42', ''), isFalse);
      expect(doPasswordsMatch(null, null), isFalse);
    });

    test('confirmation identique octet-a-octet -> vrai', () {
      expect(doPasswordsMatch('secret42', 'secret42'), isTrue);
    });

    test('confirmation differente d une casse -> faux (pas de normalisation)', () {
      expect(doPasswordsMatch('Secret42', 'secret42'), isFalse);
    });

    test('confirmation avec espace en trop -> faux (pas de trim implicite)', () {
      expect(doPasswordsMatch('secret42', 'secret42 '), isFalse);
      expect(doPasswordsMatch(' secret42', 'secret42'), isFalse);
    });
  });
}
