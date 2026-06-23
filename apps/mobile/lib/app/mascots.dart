import 'package:prism_ui/prism_ui.dart';

/// Single place that wires the learner-facing mascot artwork.
///
/// Today the app ships with the built-in **procedural** faces, so this does
/// nothing. The moment real character art lands in `assets/mascots/<id>/<mood>.png`
/// (see `assets/mascots/README.md`):
///
/// 1. uncomment the `assets:` block in `apps/mobile/pubspec.yaml`;
/// 2. uncomment the single line below;
/// 3. `flutter pub get` and run.
///
/// Every surface — Home greeting, Path guardians, onboarding hero — then renders
/// your characters automatically, with a graceful fall back to the drawn face
/// for any image that is missing. No screen code changes.
void configureMascots() {
  // Touch the registry so this file is always wired and ready; flipping to
  // image assets is then the single commented line below.
  MascotRegistry.instance;

  // MascotRegistry.instance.useImageAssets(); // assets/mascots/<id>/<mood>.png

  // Need finer control? You can also register art explicitly, e.g.:
  // MascotRegistry.instance.registerMascot(AuroraMascot.nimbus, 'assets/mascots/nimbus/idle.png');
  // MascotRegistry.instance.registerMood(AuroraMascot.nimbus, MascotMood.celebrate, 'assets/mascots/nimbus/celebrate.png');
}
