// Fixture for .github/sast/rules/dart-security.yaml — storage rules.
import 'dart:io';

Future<void> storage(
  SharedPreferences prefs,
  SharedPreferencesAsync asyncPrefs,
  AuthSession session,
  String accessToken,
  File file,
) async {
  // ruleid: dart-sensitive-data-in-shared-preferences
  await prefs.setString('auth.access_token', accessToken);

  // ruleid: dart-sensitive-data-in-shared-preferences
  await asyncPrefs.setString(_sessionTokenKey, session.encode());

  // ruleid: dart-sensitive-data-in-shared-preferences
  await prefs.setString('profile.cache', session.refreshToken);

  // ruleid: dart-sensitive-data-in-shared-preferences
  await prefs.setStringList('cookies', <String>[session.cookie]);

  // ok: dart-sensitive-data-in-shared-preferences
  await prefs.setString('onboarding.completed', 'true');

  // ok: dart-sensitive-data-in-shared-preferences
  await prefs.setBool('auth.has_token', true);

  // ruleid: dart-sensitive-data-written-to-file
  await file.writeAsString(session.refreshToken);

  // ruleid: dart-sensitive-data-written-to-file
  file.writeAsStringSync('token=$accessToken');

  // ok: dart-sensitive-data-written-to-file
  await file.writeAsString(jsonEncode(progress));

  // ok: dart-sensitive-data-written-to-file
  await file.writeAsString('token length ${accessToken.length}');

  // ruleid: dart-keychain-accessibility-migratable
  const IOSOptions migrates = IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  // ruleid: dart-keychain-accessibility-migratable
  const IOSOptions unlocked = IOSOptions(accessibility: KeychainAccessibility.unlocked);

  // ok: dart-keychain-accessibility-migratable
  const IOSOptions deviceOnly =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device);

  // ok: dart-keychain-accessibility-migratable
  const IOSOptions unlockedDeviceOnly =
      IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device);

  // ruleid: dart-external-storage-directory
  final Directory? shared = await getExternalStorageDirectory();

  // ruleid: dart-external-storage-directory
  final Directory? downloads = await getDownloadsDirectory();

  // ok: dart-external-storage-directory
  final Directory support = await getApplicationSupportDirectory();
}
