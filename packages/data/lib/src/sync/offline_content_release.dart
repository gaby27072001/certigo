import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../models/content_release.dart';
import '../models/lesson.dart';
import '../models/track_summary.dart';
import '../repositories/catalog_payload_decoder.dart';
import '../repositories/repositories.dart';
import 'content_release_cache_store.dart';

typedef ContentReleaseEventSink = void Function(ContentReleaseEvent event);
typedef LegacyLessonCacheRead = Future<String?> Function();
typedef ContentReleaseNow = DateTime Function();

class ContentReleaseEvent {
  const ContentReleaseEvent(
    this.name, {
    this.manifestId,
    this.failureCode,
    this.fileCount,
    this.restoredPrevious = false,
  });

  final String name;
  final String? manifestId;
  final String? failureCode;
  final int? fileCount;
  final bool restoredPrevious;

  Map<String, Object> toJson() => <String, Object>{
        'name': name,
        if (manifestId != null) 'manifestId': manifestId!,
        if (failureCode != null) 'failureCode': failureCode!,
        if (fileCount != null) 'fileCount': fileCount!,
        if (restoredPrevious) 'restoredPrevious': true,
      };
}

class ContentReleaseResolution {
  const ContentReleaseResolution._({
    required this.capabilityUnavailable,
    this.release,
    this.refreshFailure,
  });

  const ContentReleaseResolution.unavailable() : this._(capabilityUnavailable: true);

  const ContentReleaseResolution.ready(CachedContentRelease release, {Failure? refreshFailure})
      : this._(capabilityUnavailable: false, release: release, refreshFailure: refreshFailure);

  final bool capabilityUnavailable;
  final CachedContentRelease? release;
  final Failure? refreshFailure;
}

class ContentReleaseCoordinator {
  ContentReleaseCoordinator({
    required ContentReleaseRepository remote,
    required ContentReleaseCacheStore store,
    ContentReleaseEventSink? events,
    LegacyLessonCacheRead? readLegacyLessons,
    ContentReleaseNow? now,
    this.refreshInterval = const Duration(minutes: 5),
  })  : _remote = remote,
        _store = store,
        _events = events,
        _readLegacyLessons = readLegacyLessons,
        _now = now ?? DateTime.now;

  final ContentReleaseRepository _remote;
  final ContentReleaseCacheStore _store;
  final ContentReleaseEventSink? _events;
  final LegacyLessonCacheRead? _readLegacyLessons;
  final ContentReleaseNow _now;
  final Duration refreshInterval;
  static const int _downloadConcurrency = 6;

  Future<Result<ContentReleaseResolution>>? _inFlight;
  ContentReleaseResolution? _lastResolution;
  DateTime? _lastCheckedAt;

  Future<Result<ContentReleaseResolution>> resolve({bool forceRefresh = false}) {
    final DateTime now = _now();
    final DateTime? checkedAt = _lastCheckedAt;
    if (!forceRefresh &&
        checkedAt != null &&
        now.difference(checkedAt) < refreshInterval &&
        _lastResolution != null) {
      return Future<Result<ContentReleaseResolution>>.value(
        Success<ContentReleaseResolution>(_lastResolution!),
      );
    }
    final Future<Result<ContentReleaseResolution>>? running = _inFlight;
    if (running != null) return running;

    late final Future<Result<ContentReleaseResolution>> operation;
    operation = _synchronize().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<Result<ContentReleaseResolution>> _synchronize() async {
    final Result<OfflineContentManifest> manifestResult = await _remote.getActiveManifest();
    if (manifestResult case Err<OfflineContentManifest>(:final Failure failure)) {
      if (failure is NotFoundFailure) {
        _emit(const ContentReleaseEvent('content.release.offline.capability_unavailable'));
        return _remember(const ContentReleaseResolution.unavailable());
      }
      return _fallback(failure);
    }

    final OfflineContentManifest manifest =
        (manifestResult as Success<OfflineContentManifest>).value;
    try {
      final ContentReleaseCacheSelection before = await _store.readBest();
      if (before.failure != null) {
        _emit(
          ContentReleaseEvent(
            'content.release.offline.cache_corrupt',
            manifestId: before.release?.manifest.manifestId,
            failureCode: before.failure!.code,
            restoredPrevious: before.release?.restoredPrevious ?? false,
          ),
        );
      }
      await _store.stageManifest(manifest);
      await _migrateLegacyLessons(manifest);
      final List<OfflineContentFileDescriptor> missing = await _store.missingFiles(manifest);
      for (int offset = 0; offset < missing.length; offset += _downloadConcurrency) {
        final List<OfflineContentFileDescriptor> batch =
            missing.skip(offset).take(_downloadConcurrency).toList(growable: false);
        final List<
            ({
              OfflineContentFileDescriptor descriptor,
              Result<ContentFileResponse> result,
            })> responses = await Future.wait(
          batch.map((OfflineContentFileDescriptor descriptor) async {
            return (
              descriptor: descriptor,
              result: await _remote.getFile(
                manifestId: manifest.manifestId,
                descriptor: descriptor,
              ),
            );
          }),
        );
        final List<ContentReleaseFileWrite> verified = <ContentReleaseFileWrite>[];
        Failure? batchFailure;
        ContentReleaseIntegrityException? batchIntegrityFailure;
        for (final ({
          OfflineContentFileDescriptor descriptor,
          Result<ContentFileResponse> result,
        }) response in responses) {
          if (response.result case Err<ContentFileResponse>(:final Failure failure)) {
            batchFailure ??= failure;
            continue;
          }
          final ContentFileResponse payload =
              (response.result as Success<ContentFileResponse>).value;
          try {
            _validateResponseMetadata(manifest, response.descriptor, payload);
          } on ContentReleaseIntegrityException catch (error) {
            batchIntegrityFailure ??= error;
            continue;
          }
          verified.add((descriptor: response.descriptor, bytes: payload.bytes));
        }
        await _store.stageFiles(manifest: manifest, files: verified);
        if (batchIntegrityFailure != null) {
          throw batchIntegrityFailure;
        }
        if (batchFailure != null) {
          return _fallback(batchFailure, attemptedManifestId: manifest.manifestId);
        }
      }
      await _store.activate(manifest);
      final ContentReleaseCacheSelection selected = await _store.readBest();
      final CachedContentRelease? release = selected.release;
      if (release == null || release.manifest.version != manifest.version) {
        throw const ContentReleaseCacheException(
          'The synchronized manifest was not activated atomically.',
        );
      }
      _emit(
        ContentReleaseEvent(
          'content.release.offline.activated',
          manifestId: manifest.manifestId,
          fileCount: manifest.files.length,
        ),
      );
      return _remember(ContentReleaseResolution.ready(release));
    } on ContentReleaseCacheException catch (error) {
      return _fallback(CacheFailure(error.message), attemptedManifestId: manifest.manifestId);
    } on FormatException catch (_) {
      return _fallback(
        const ParseFailure('Le contrat de contenu offline est invalide.'),
        attemptedManifestId: manifest.manifestId,
      );
    }
  }

  Future<Result<ContentReleaseResolution>> _fallback(
    Failure refreshFailure, {
    String? attemptedManifestId,
  }) async {
    try {
      final ContentReleaseCacheSelection selected = await _store.readBest();
      final CachedContentRelease? release = selected.release;
      if (release != null) {
        if (selected.failure != null) {
          _emit(
            ContentReleaseEvent(
              'content.release.offline.cache_corrupt',
              manifestId: release.manifest.manifestId,
              failureCode: selected.failure!.code,
              restoredPrevious: release.restoredPrevious,
            ),
          );
        }
        _emit(
          ContentReleaseEvent(
            'content.release.offline.fallback',
            manifestId: release.manifest.manifestId,
            failureCode: refreshFailure.code,
            restoredPrevious: release.restoredPrevious,
          ),
        );
        return _remember(ContentReleaseResolution.ready(release, refreshFailure: refreshFailure));
      }
      if (selected.failure != null) return Err<ContentReleaseResolution>(selected.failure!);
    } on ContentReleaseCacheException catch (error) {
      _emit(
        ContentReleaseEvent(
          'content.release.offline.cache_corrupt',
          manifestId: attemptedManifestId,
          failureCode: 'cache',
        ),
      );
      return Err<ContentReleaseResolution>(CacheFailure(error.message));
    }
    return Err<ContentReleaseResolution>(refreshFailure);
  }

  Future<void> _migrateLegacyLessons(OfflineContentManifest manifest) async {
    final LegacyLessonCacheRead? readLegacy = _readLegacyLessons;
    if (readLegacy == null) return;
    final String? raw = await readLegacy();
    if (raw == null || raw.isEmpty) return;

    try {
      final Map<String, dynamic> document = Map<String, dynamic>.from(
        jsonDecode(raw) as Map<dynamic, dynamic>,
      );
      final Object? rawLessons = document['lessons'];
      if (rawLessons is! Map) {
        throw const FormatException('Legacy lesson map is absent.');
      }
      int migrated = 0;
      for (final Object? value in rawLessons.values) {
        if (value is! Map) continue;
        final Map<String, dynamic> lesson = Map<String, dynamic>.from(value);
        if (lesson['publicManifestId'] != manifest.manifestId) continue;
        final String? id = lesson['id'] as String?;
        final String? trackId = lesson['trackId'] as String?;
        if (id == null || trackId == null) continue;
        final OfflineContentFileDescriptor? descriptor = _findLesson(manifest, trackId, id);
        if (descriptor == null) continue;

        final Uint8List bytes = _encodeBackendLesson(Lesson.fromJson(lesson));
        try {
          await _store.stageFile(manifest: manifest, descriptor: descriptor, bytes: bytes);
          migrated++;
        } on ContentReleaseIntegrityException {
          // The legacy JSON serializer may differ; the verified network copy wins.
        }
      }
      if (migrated > 0) {
        _emit(
          ContentReleaseEvent(
            'content.release.offline.legacy_migrated',
            manifestId: manifest.manifestId,
            fileCount: migrated,
          ),
        );
      }
    } on FormatException {
      _emit(
        ContentReleaseEvent(
          'content.release.offline.legacy_rejected',
          manifestId: manifest.manifestId,
          failureCode: 'cache',
        ),
      );
    } on TypeError {
      _emit(
        ContentReleaseEvent(
          'content.release.offline.legacy_rejected',
          manifestId: manifest.manifestId,
          failureCode: 'cache',
        ),
      );
    }
  }

  OfflineContentFileDescriptor? _findLesson(
    OfflineContentManifest manifest,
    String trackId,
    String lessonId,
  ) {
    for (final OfflineContentFileDescriptor descriptor in manifest.files) {
      if (descriptor.isLesson && descriptor.trackId == trackId && descriptor.id == lessonId) {
        return descriptor;
      }
    }
    return null;
  }

  Uint8List _encodeBackendLesson(Lesson lesson) {
    final Map<String, Object?> wire = <String, Object?>{
      'id': lesson.id,
      'trackId': lesson.trackId,
      'unitId': lesson.unitId,
      'domainId': lesson.domainId,
      'title': lesson.title,
      'estMinutes': lesson.estMinutes,
      'blocks': lesson.blocks.map((LessonBlock block) {
        final QuizItem? check = block.check;
        return <String, Object?>{
          'type': blockTypeToWire(block.type),
          'conceptId': block.conceptId,
          'title': block.title,
          'body': block.body,
          'code': block.code,
          'language': block.language,
          'check': check == null
              ? null
              : <String, Object?>{
                  'id': check.id,
                  'conceptId': check.conceptId,
                  'type': itemTypeToWire(check.type),
                  'stem': check.stem,
                  'options': check.options
                      .map(
                        (QuizOption option) => <String, Object?>{
                          'id': option.id,
                          'label': option.label,
                        },
                      )
                      .toList(growable: false),
                },
        };
      }).toList(growable: false),
    };
    return Uint8List.fromList(utf8.encode(_encodeSystemTextJson(wire)));
  }

  String _encodeSystemTextJson(Object? value) {
    if (value == null) return 'null';
    if (value is bool || value is num) return jsonEncode(value);
    if (value is String) return _encodeSystemTextJsonString(value);
    if (value is List) {
      return '[${value.map(_encodeSystemTextJson).join(',')}]';
    }
    if (value is Map<String, Object?>) {
      return '{${value.entries.map((MapEntry<String, Object?> entry) {
        return '${_encodeSystemTextJsonString(entry.key)}:${_encodeSystemTextJson(entry.value)}';
      }).join(',')}}';
    }
    throw FormatException('Unsupported legacy lesson JSON value: ${value.runtimeType}.');
  }

  String _encodeSystemTextJsonString(String value) {
    final StringBuffer encoded = StringBuffer('"');
    for (final int codeUnit in value.codeUnits) {
      switch (codeUnit) {
        case 0x08:
          encoded.write(r'\b');
        case 0x09:
          encoded.write(r'\t');
        case 0x0A:
          encoded.write(r'\n');
        case 0x0C:
          encoded.write(r'\f');
        case 0x0D:
          encoded.write(r'\r');
        case 0x5C:
          encoded.write(r'\\');
        default:
          if (codeUnit < 0x20 ||
              codeUnit > 0x7E ||
              codeUnit == 0x22 ||
              codeUnit == 0x26 ||
              codeUnit == 0x27 ||
              codeUnit == 0x2B ||
              codeUnit == 0x3C ||
              codeUnit == 0x3E ||
              codeUnit == 0x60) {
            encoded
              ..write(r'\u')
              ..write(codeUnit.toRadixString(16).toUpperCase().padLeft(4, '0'));
          } else {
            encoded.writeCharCode(codeUnit);
          }
      }
    }
    return encoded.toString() + '"';
  }

  void _validateResponseMetadata(
    OfflineContentManifest manifest,
    OfflineContentFileDescriptor descriptor,
    ContentFileResponse response,
  ) {
    if (response.manifestId != manifest.manifestId ||
        response.hash != descriptor.hash ||
        response.size != descriptor.size) {
      throw ContentReleaseIntegrityException(
        'Server metadata for ${descriptor.path} does not match the manifest.',
      );
    }
  }

  Result<ContentReleaseResolution> _remember(ContentReleaseResolution resolution) {
    _lastResolution = resolution;
    _lastCheckedAt = _now();
    return Success<ContentReleaseResolution>(resolution);
  }

  void _emit(ContentReleaseEvent event) => _events?.call(event);
}

class ReleaseAwareCatalogRepository implements CatalogRepository {
  const ReleaseAwareCatalogRepository({
    required ContentReleaseCoordinator coordinator,
    required CatalogRepository legacy,
  })  : _coordinator = coordinator,
        _legacy = legacy;

  final ContentReleaseCoordinator _coordinator;
  final CatalogRepository _legacy;

  @override
  Future<Result<List<TrackSummary>>> getCatalog() async {
    final Result<ContentReleaseResolution> resolution = await _coordinator.resolve();
    if (resolution case Err<ContentReleaseResolution>(:final Failure failure)) {
      return Err<List<TrackSummary>>(failure);
    }
    final ContentReleaseResolution value = (resolution as Success<ContentReleaseResolution>).value;
    if (value.capabilityUnavailable) return _legacy.getCatalog();

    try {
      final CachedContentRelease release = value.release!;
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(release.fileBytes(release.manifest.catalog)))
            as Map<dynamic, dynamic>,
      );
      final List<TrackSummary> tracks = decodeTrackSummaries(json);
      return tracks.isEmpty
          ? const Err<List<TrackSummary>>(CatalogEmptyFailure())
          : Success<List<TrackSummary>>(tracks);
    } on ContentReleaseCacheException catch (error) {
      return Err<List<TrackSummary>>(CacheFailure(error.message));
    } on FormatException {
      return const Err<List<TrackSummary>>(
        ParseFailure('Le catalogue offline vérifié est incompatible.'),
      );
    } on TypeError {
      return const Err<List<TrackSummary>>(
        ParseFailure('Le catalogue offline vérifié est incompatible.'),
      );
    }
  }
}

class ReleaseAwareLessonRepository implements LessonRepository {
  const ReleaseAwareLessonRepository({
    required ContentReleaseCoordinator coordinator,
    required LessonRepository legacy,
  })  : _coordinator = coordinator,
        _legacy = legacy;

  final ContentReleaseCoordinator _coordinator;
  final LessonRepository _legacy;

  @override
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId}) async {
    final Result<ContentReleaseResolution> resolution = await _coordinator.resolve();
    if (resolution case Err<ContentReleaseResolution>(:final Failure failure)) {
      return Err<Lesson>(failure);
    }
    final ContentReleaseResolution value = (resolution as Success<ContentReleaseResolution>).value;
    if (value.capabilityUnavailable) {
      return _legacy.getLesson(trackId: trackId, lessonId: lessonId);
    }

    final CachedContentRelease release = value.release!;
    final OfflineContentFileDescriptor? descriptor = _findLesson(
      release.manifest,
      trackId,
      lessonId,
    );
    if (descriptor == null) {
      return const Err<Lesson>(NotFoundFailure('Leçon absente de la release offline active.'));
    }
    try {
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(release.fileBytes(descriptor))) as Map<dynamic, dynamic>,
      );
      final Lesson lesson = Lesson.fromJson(json).withPublicManifestId(release.manifest.manifestId);
      if (lesson.id != lessonId || lesson.trackId != trackId) {
        return const Err<Lesson>(
          ParseFailure('La leçon offline ne correspond pas à son descripteur.'),
        );
      }
      return Success<Lesson>(lesson);
    } on ContentReleaseCacheException catch (error) {
      return Err<Lesson>(CacheFailure(error.message));
    } on FormatException {
      return const Err<Lesson>(ParseFailure('La leçon offline vérifiée est incompatible.'));
    } on TypeError {
      return const Err<Lesson>(ParseFailure('La leçon offline vérifiée est incompatible.'));
    }
  }

  OfflineContentFileDescriptor? _findLesson(
    OfflineContentManifest manifest,
    String trackId,
    String lessonId,
  ) {
    for (final OfflineContentFileDescriptor descriptor in manifest.files) {
      if (descriptor.isLesson && descriptor.trackId == trackId && descriptor.id == lessonId) {
        return descriptor;
      }
    }
    return null;
  }
}
