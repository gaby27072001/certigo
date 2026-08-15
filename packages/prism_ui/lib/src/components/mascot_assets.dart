import 'package:flutter/widgets.dart';

import 'aurora_mascot.dart';

/// Stable string ids for the crew and their moods.
///
/// These ids are the *contract* with custom mascot art: an image asset is
/// resolved at the convention path `{base}/{mascot.id}/{mood.id}.{ext}`. Keeping
/// them here (next to the registry) means the file/folder names a designer must
/// produce are defined in one obvious place.
extension AuroraMascotId on AuroraMascot {
  String get id => switch (this) {
        AuroraMascot.nimbus => 'nimbus',
        AuroraMascot.volt => 'volt',
        AuroraMascot.cosmo => 'cosmo',
        AuroraMascot.sentinel => 'sentinel',
        AuroraMascot.bicky => 'bicky',
        AuroraMascot.pixel => 'pixel',
        AuroraMascot.pip => 'pip',
      };
}

extension MascotMoodId on MascotMood {
  String get id => switch (this) {
        MascotMood.idle => 'idle',
        MascotMood.happy => 'happy',
        MascotMood.celebrate => 'celebrate',
        MascotMood.sad => 'sad',
      };
}

/// A resolved piece of mascot artwork: the image asset to paint, plus the owning
/// [package] when the art ships inside a package rather than the app.
@immutable
class MascotArt {
  const MascotArt(this.assetPath, {this.package});

  /// Path declared in `pubspec.yaml` (e.g. `assets/mascots/nimbus/happy.png`).
  final String assetPath;

  /// Owning package, or null when the asset lives in the host app.
  final String? package;

  @override
  bool operator ==(Object other) =>
      other is MascotArt && other.assetPath == assetPath && other.package == package;

  @override
  int get hashCode => Object.hash(assetPath, package);
}

/// Central place that decides **how** a mascot is drawn: with custom image art
/// (your future characters) or with the built-in procedural face.
///
/// ## Why this exists
/// Screens never hard-code mascot images. They render [MascotAvatar] /
/// [MascotHero], which ask this registry to resolve the right artwork. So the
/// day real character art is ready, you wire it **once** here (or via
/// [useImageAssets]) and every surface — Home greeting, Path guardians,
/// onboarding hero — switches over with zero screen edits.
///
/// ## Two ways to plug art in
/// 1. **Convention (recommended)** — drop files under a base folder and call
///    [useImageAssets]. For each mascot+mood the registry looks for
///    `{base}/{mascot.id}/{mood.id}.{ext}` and falls back to the mascot's
///    `idle` art, then to the procedural face if the file is missing at runtime.
/// 2. **Explicit** — register a specific asset for a mascot (all moods) with
///    [registerMascot] or a single mood with [registerMood].
///
/// Until art is registered the registry returns `null`, so the app keeps using
/// the friendly built-in faces and never crashes on a missing file.
class MascotRegistry {
  MascotRegistry._();

  /// The shared registry. Configure it once during app bootstrap.
  static final MascotRegistry instance = MascotRegistry._();

  /// Per-(mascot,mood) explicit overrides — the highest priority.
  final Map<AuroraMascot, Map<MascotMood, MascotArt>> _moodArt =
      <AuroraMascot, Map<MascotMood, MascotArt>>{};

  /// Convention resolver installed by [useImageAssets], if any.
  MascotArt? Function(AuroraMascot mascot, MascotMood mood)? _convention;

  /// Whether any custom art is configured (used by hosts to decide layout, e.g.
  /// a full-body hero only makes sense once real characters are provided).
  bool get hasCustomArt => _moodArt.isNotEmpty || _convention != null;

  /// Switch the whole crew to convention-based image assets.
  ///
  /// Looks up `{base}/{mascot.id}/{mood.id}.{ext}` for each request, with a
  /// graceful chain of fallbacks (mood → idle → procedural face). Call this from
  /// bootstrap once the `assets/mascots/...` folder is populated and declared in
  /// `pubspec.yaml`.
  ///
  /// ```dart
  /// MascotRegistry.instance.useImageAssets(); // assets/mascots/<id>/<mood>.png
  /// ```
  void useImageAssets({String base = 'assets/mascots', String extension = 'png', String? package}) {
    final String ext = extension.startsWith('.') ? extension.substring(1) : extension;
    _convention = (AuroraMascot mascot, MascotMood mood) =>
        MascotArt('$base/${mascot.id}/${mood.id}.$ext', package: package);
  }

  /// Register one image for a mascot, used for **every** mood.
  void registerMascot(AuroraMascot mascot, String assetPath, {String? package}) {
    for (final MascotMood mood in MascotMood.values) {
      registerMood(mascot, mood, assetPath, package: package);
    }
  }

  /// Register one image for a single (mascot, mood) pair — highest priority.
  void registerMood(AuroraMascot mascot, MascotMood mood, String assetPath, {String? package}) {
    (_moodArt[mascot] ??= <MascotMood, MascotArt>{})[mood] = MascotArt(assetPath, package: package);
  }

  /// Resolve the artwork for [mascot] in [mood], or `null` to use the built-in
  /// procedural face. Resolution order: explicit mood → explicit idle →
  /// convention(mood) → convention(idle).
  MascotArt? resolve(AuroraMascot mascot, MascotMood mood) {
    final Map<MascotMood, MascotArt>? explicit = _moodArt[mascot];
    if (explicit != null) {
      final MascotArt? exact = explicit[mood];
      if (exact != null) return exact;
      final MascotArt? idle = explicit[MascotMood.idle];
      if (idle != null) return idle;
    }
    final MascotArt? Function(AuroraMascot, MascotMood)? conv = _convention;
    if (conv != null) {
      return conv(mascot, mood) ?? conv(mascot, MascotMood.idle);
    }
    return null;
  }

  /// Clear all configuration. Primarily for tests.
  @visibleForTesting
  void reset() {
    _moodArt.clear();
    _convention = null;
  }
}
