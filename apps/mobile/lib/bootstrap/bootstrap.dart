import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    // TODO(observability): forward to Application Insights via a Crash service.
    FlutterError.presentError(details);
  };

  runApp(const ProviderScope(child: MicrolingoApp()));
}
