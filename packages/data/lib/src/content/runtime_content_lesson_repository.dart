import 'dart:typed_data';

import 'package:core/core.dart';

import '../models/lesson.dart';
import '../repositories/repositories.dart';
import '../sync/sync_dispatcher.dart';
import 'runtime_content.dart';
import 'runtime_content_store.dart';

class RuntimeContentLessonRepository implements LessonRepository {
  const RuntimeContentLessonRepository({
    required LessonRepository inner,
    required RuntimeContentStore store,
    required String? Function() ownerIdProvider,
  })  : _inner = inner,
        _store = store,
        _ownerIdProvider = ownerIdProvider;

  final LessonRepository _inner;
  final RuntimeContentStore _store;
  final String? Function() _ownerIdProvider;

  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async {
    final Result<Lesson> remote = await _inner.getLesson(
      trackId: trackId,
      lessonId: lessonId,
    );
    if (remote.isSuccess) return remote;
    final Failure failure = (remote as Err<Lesson>).failure;
    if (classifyFailure(failure) != SyncDispatch.retryable) return remote;

    final String? ownerId = _ownerIdProvider();
    if (ownerId == null || ownerId.trim().isEmpty) return remote;
    try {
      final Lesson? cached = await _projectLesson(
        ownerScope: runtimeContentScopeKey(ownerId),
        trackId: trackId,
        lessonId: lessonId,
      );
      return cached == null ? remote : Success<Lesson>(cached);
    } on FormatException {
      return remote;
    } on TypeError {
      return remote;
    }
  }

  Future<Lesson?> _projectLesson({
    required String ownerScope,
    required String trackId,
    required String lessonId,
  }) async {
    final PublicContentManifest? manifest = await _store.readActiveManifest(ownerScope);
    if (manifest == null || manifest.schema != kPackageManifestV3) return null;
    final Map<String, Map<String, dynamic>> resources = <String, Map<String, dynamic>>{};
    for (final PublicContentFile file in manifest.files) {
      if (!const <String>{
        'certificationCatalog',
        'concept',
        'domain',
        'lesson',
        'question',
        'track',
        'unit',
      }.contains(file.resourceType)) {
        continue;
      }
      final Uint8List? bytes = await _store.readReleaseFile(manifest.manifestId, file);
      if (bytes == null) return null;
      resources[file.id] = validatePublicContentPayload(file, bytes);
    }

    final Map<String, dynamic>? track = resources.values
        .where((Map<String, dynamic> value) => value['resourceType'] == 'track')
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (Map<String, dynamic>? value) => _runtimeId(value!) == trackId,
          orElse: () => null,
        );
    if (track == null || !_isDistributable(track)) return null;
    return track['mode'] == 'questionBank'
        ? _projectQuestionBank(
            manifest.manifestId,
            resources,
            track,
            trackId,
            lessonId,
          )
        : _projectGuided(
            manifest.manifestId,
            resources,
            track,
            trackId,
            lessonId,
          );
  }

  Lesson? _projectGuided(
    String manifestId,
    Map<String, Map<String, dynamic>> resources,
    Map<String, dynamic> track,
    String trackId,
    String lessonId,
  ) {
    for (final String unitId in _stringList(track, 'unitIds')) {
      final Map<String, dynamic>? unit = resources[unitId];
      if (unit == null || !_isDistributable(unit)) continue;
      for (final String canonicalLessonId in _stringList(unit, 'lessonIds')) {
        final Map<String, dynamic>? lesson = resources[canonicalLessonId];
        if (lesson == null || _runtimeId(lesson) != lessonId || !_isDistributable(lesson)) {
          continue;
        }
        final Map<String, dynamic>? domain = resources[unit['domainId']];
        if (domain == null) return null;
        final List<LessonBlock> blocks = _projectBlocks(resources, lesson);
        return Lesson(
          id: lessonId,
          trackId: trackId,
          unitId: _runtimeId(unit),
          domainId: _runtimeId(domain),
          title: lesson['title'] as String,
          estMinutes: (lesson['estimatedMinutes'] as num).toInt(),
          blocks: blocks,
          publicManifestId: manifestId,
        );
      }
    }
    return null;
  }

  Lesson? _projectQuestionBank(
    String manifestId,
    Map<String, Map<String, dynamic>> resources,
    Map<String, dynamic> track,
    String trackId,
    String lessonId,
  ) {
    final String certificationId = track['certificationId'] as String;
    for (final String domainId in _stringList(track, 'domainIds')) {
      final Map<String, dynamic>? domain = resources[domainId];
      if (domain == null || !_isDistributable(domain)) continue;
      final String objectiveId = domain['objectiveId'] as String;
      final String expectedLessonId = '$trackId.lesson.$objectiveId.practice';
      if (expectedLessonId != lessonId) continue;
      final List<Map<String, dynamic>> questions = resources.values
          .where(
            (Map<String, dynamic> value) =>
                value['kind'] == 'public' &&
                value['metadata'] is Map<String, dynamic> &&
                (value['metadata'] as Map<String, dynamic>)['certification'] == certificationId &&
                (value['metadata'] as Map<String, dynamic>)['domainId'] == domainId,
          )
          .toList()
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return (a['id'] as String).compareTo(b['id'] as String);
        });
      final String title = _objectiveTitle(resources, certificationId, objectiveId);
      return Lesson(
        id: lessonId,
        trackId: trackId,
        unitId: '$trackId.unit.$objectiveId',
        domainId: _runtimeId(domain),
        title: '$title practice',
        estMinutes: (questions.length * 2).clamp(1, 20),
        blocks: questions
            .map((Map<String, dynamic> question) => _questionBlock(resources, question))
            .toList(growable: false),
        publicManifestId: manifestId,
      );
    }
    return null;
  }

  List<LessonBlock> _projectBlocks(
    Map<String, Map<String, dynamic>> resources,
    Map<String, dynamic> lesson,
  ) {
    return (lesson['blocks'] as List<dynamic>).map((dynamic value) {
      final Map<String, dynamic> block = Map<String, dynamic>.from(value as Map);
      final Map<String, dynamic>? concept = resources[block['conceptId']];
      if (concept == null) throw const FormatException('Lesson references an unknown concept');
      if (block['type'] == 'check') {
        final Map<String, dynamic>? question = resources[block['questionId']];
        if (question == null) {
          throw const FormatException('Lesson check references an unknown question');
        }
        return _questionBlock(resources, question);
      }
      return LessonBlock(
        type: _blockType(block['type'] as String?),
        conceptId: _runtimeId(concept),
        title: block['title'] as String?,
        body: block['body'] as String?,
        code: block['code'] as String?,
        language: block['language'] as String?,
      );
    }).toList(growable: false);
  }

  LessonBlock _questionBlock(
    Map<String, Map<String, dynamic>> resources,
    Map<String, dynamic> question,
  ) {
    final Map<String, dynamic> metadata = Map<String, dynamic>.from(question['metadata'] as Map);
    final Map<String, dynamic>? concept = resources[metadata['conceptId']];
    if (concept == null) throw const FormatException('Question references an unknown concept');
    return LessonBlock(
      type: BlockType.check,
      conceptId: _runtimeId(concept),
      check: QuizItem(
        id: _runtimeId(question),
        conceptId: _runtimeId(concept),
        type: itemTypeFrom(question['itemType'] as String?),
        stem: question['prompt'] as String,
        options: (question['options'] as List<dynamic>)
            .map(
              (dynamic value) => QuizOption.fromJson(Map<String, dynamic>.from(value as Map)),
            )
            .toList(growable: false),
      ),
    );
  }

  String _objectiveTitle(
    Map<String, Map<String, dynamic>> resources,
    String certificationId,
    String objectiveId,
  ) {
    final Map<String, dynamic>? catalog = resources['certification-catalog'];
    if (catalog == null) return objectiveId;
    for (final dynamic value in catalog['certifications'] as List<dynamic>) {
      final Map<String, dynamic> certification = Map<String, dynamic>.from(value as Map);
      if (certification['id'] != certificationId) continue;
      final Map<String, dynamic> blueprint =
          Map<String, dynamic>.from(certification['blueprint'] as Map);
      for (final dynamic objectiveValue in blueprint['objectives'] as List<dynamic>) {
        final Map<String, dynamic> objective = Map<String, dynamic>.from(objectiveValue as Map);
        if (objective['id'] == objectiveId) return objective['title'] as String;
      }
    }
    return objectiveId;
  }

  static bool _isDistributable(Map<String, dynamic> resource) {
    final Map<String, dynamic> lifecycle = Map<String, dynamic>.from(resource['lifecycle'] as Map);
    return lifecycle['status'] == 'active' || lifecycle['status'] == 'retiring';
  }

  static String _runtimeId(Map<String, dynamic> resource) =>
      resource['legacyId'] as String? ?? resource['id'] as String;

  static List<String> _stringList(Map<String, dynamic> json, String key) =>
      (json[key] as List<dynamic>).cast<String>();

  static BlockType _blockType(String? value) => switch (value) {
        'hook' => BlockType.hook,
        'concept' => BlockType.concept,
        'example' => BlockType.example,
        'code' => BlockType.code,
        'recap' => BlockType.recap,
        _ => BlockType.unknown,
      };
}
