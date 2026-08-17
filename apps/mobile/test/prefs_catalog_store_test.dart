import 'package:certigo/app/offline/prefs_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('catalog cache v2 discards pre-blueprint cache entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'microlingo.catalog.cache.v1': 'legacy',
      'certigo.catalog.cache.v1': 'without official metadata',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final store = prefsCatalogCacheStore(prefs);

    expect(prefs.containsKey('microlingo.catalog.cache.v1'), isFalse);
    expect(prefs.containsKey('certigo.catalog.cache.v1'), isFalse);
    expect(kCatalogCachePrefsKey, 'certigo.catalog.cache.v2');
    expect(await store.read(), isNull);
  });
}
