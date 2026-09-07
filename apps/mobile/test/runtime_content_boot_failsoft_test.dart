import 'package:certigo/bootstrap/bootstrap.dart';
import 'package:data/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le canal utilisé par `path_provider` sur les plateformes qui l'implémentent.
const MethodChannel _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathProvider, null);
  });

  group('resolveFileRuntimeContentStore', () {
    test('renvoie null au lieu de lever quand path_provider est absent', () async {
      // Reproduit exactement l'échec observé sur le web :
      // MissingPluginException(No implementation found for
      // getApplicationSupportDirectory on channel plugins.flutter.io/path_provider).
      messenger.setMockMethodCallHandler(_pathProvider, (MethodCall call) async {
        throw MissingPluginException(
          'No implementation found for method ${call.method} '
          'on channel plugins.flutter.io/path_provider',
        );
      });

      final FileRuntimeContentStore? store = await resolveFileRuntimeContentStore();

      expect(store, isNull);
    });

    test('renvoie null quand le dossier support est indisponible', () async {
      messenger.setMockMethodCallHandler(_pathProvider, (MethodCall call) async {
        throw PlatformException(code: 'unavailable', message: 'support directory refusé');
      });

      final FileRuntimeContentStore? store = await resolveFileRuntimeContentStore();

      expect(store, isNull);
    });

    test('renvoie un store quand la plateforme fournit un dossier support', () async {
      messenger.setMockMethodCallHandler(_pathProvider, (MethodCall call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return '/tmp/certigo-test-support';
        }
        return null;
      });

      final FileRuntimeContentStore? store = await resolveFileRuntimeContentStore();

      expect(store, isNotNull);
    });
  });
}
