import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _OfflineLessons implements LessonRepository {
  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async =>
      const Err<Lesson>(NetworkFailure());
}

class _PinObservingStore extends InMemoryRuntimeContentStore {
  _PinObservingStore(this.pins);

  final RuntimeContentPinRegistry pins;
  bool observedPinnedRead = false;

  @override
  Future<PublicContentManifest?> readActiveManifest(String ownerScope) async {
    final RuntimeContentActivation? activation = await readActivation(ownerScope);
    observedPinnedRead =
        activation != null && pins.manifestIds.contains(activation.activeManifestId);
    return super.readActiveManifest(ownerScope);
  }
}

class _BrokenCacheStore extends InMemoryRuntimeContentStore {
  @override
  Future<RuntimeContentActivation?> readActivation(String ownerScope) async {
    throw const FileSystemException('cache unavailable');
  }
}

void main() {
  test('projects a guided lesson and its public check from the active v3 cache', () async {
    const String certificationId = 'microsoft:az-900';
    const String domainId = 'microsoft.az-900.domain.cloud-concepts';
    const String conceptId = 'microsoft.az-900.concept.cloud-service-models';
    const String unitId = 'microsoft.az-900.unit.cloud';
    const String lessonId = 'microsoft.az-900.lesson.cloud';
    const String questionId = 'microsoft.az-900.section-1.cloud.001';
    final List<ContentFixture> fixtures = <ContentFixture>[
      _catalog(certificationId, 'section-1', 'Cloud concepts'),
      _runtime(
        id: 'microsoft.az-900.track.main',
        type: 'track',
        path: 'runtime/tracks/microsoft/az-900/track.json',
        json: <String, dynamic>{
          'legacyId': 'az-900',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'mode': 'guided',
          'summary': 'Guided',
          'domainIds': <String>[domainId],
          'unitIds': <String>[unitId],
        },
      ),
      _runtime(
        id: domainId,
        type: 'domain',
        path: 'runtime/domains/microsoft/az-900/domain.json',
        json: <String, dynamic>{
          'legacyId': 'domain-legacy',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'objectiveId': 'section-1',
        },
      ),
      _runtime(
        id: unitId,
        type: 'unit',
        path: 'runtime/units/microsoft/az-900/unit.json',
        json: <String, dynamic>{
          'legacyId': 'unit-legacy',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'domainId': domainId,
          'title': 'Unit',
          'lessonIds': <String>[lessonId],
        },
      ),
      _runtime(
        id: conceptId,
        type: 'concept',
        path: 'runtime/concepts/microsoft/az-900/concept.json',
        json: <String, dynamic>{
          'legacyId': 'concept-legacy',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'domainId': domainId,
          'title': 'Concept',
        },
      ),
      questionFixture(
        questionId,
        domainId: domainId,
        conceptId: conceptId,
        legacyId: 'question-legacy',
      ),
      _runtime(
        id: lessonId,
        type: 'lesson',
        path: 'runtime/lessons/microsoft/az-900/lesson.json',
        json: <String, dynamic>{
          'legacyId': 'lesson-legacy',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'unitId': unitId,
          'title': 'Cloud lesson',
          'estimatedMinutes': 5,
          'blocks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '$lessonId.block.001',
              'type': 'concept',
              'conceptId': conceptId,
              'body': 'Public body',
            },
            <String, dynamic>{
              'id': '$lessonId.block.002',
              'type': 'check',
              'conceptId': conceptId,
              'questionId': questionId,
            },
          ],
        },
      ),
    ];
    final Lesson lesson = await _syncAndRead(
      fixtures,
      trackId: 'az-900',
      lessonId: 'lesson-legacy',
    );

    expect(lesson.unitId, 'unit-legacy');
    expect(lesson.domainId, 'domain-legacy');
    expect(lesson.blocks.last.check!.id, 'question-legacy');
    expect(lesson.blocks.last.check!.conceptId, 'concept-legacy');
    expect(lesson.publicManifestId, startsWith('sha256:'));
  });

  test('projects a deterministic practice lesson for a question-bank track', () async {
    const String certificationId = 'aws:clf-c02';
    const String domainId = 'aws.clf-c02.domain.cloud-concepts';
    const String conceptId = 'aws.clf-c02.concept.cloud-value';
    final List<ContentFixture> fixtures = <ContentFixture>[
      _catalog(certificationId, 'domain-1', 'Cloud Concepts'),
      _runtime(
        id: 'aws.clf-c02.track.main',
        type: 'track',
        path: 'runtime/tracks/aws/clf-c02/track.json',
        json: <String, dynamic>{
          'legacyId': 'aws-clf',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'mode': 'questionBank',
          'summary': 'Bank',
          'domainIds': <String>[domainId],
          'unitIds': <String>[],
        },
      ),
      _runtime(
        id: domainId,
        type: 'domain',
        path: 'runtime/domains/aws/clf-c02/domain.json',
        json: <String, dynamic>{
          'legacyId': 'aws-domain',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'objectiveId': 'domain-1',
        },
      ),
      _runtime(
        id: conceptId,
        type: 'concept',
        path: 'runtime/concepts/aws/clf-c02/concept.json',
        json: <String, dynamic>{
          'legacyId': 'aws-concept',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'domainId': domainId,
          'title': 'Value',
        },
      ),
      questionFixture(
        'aws.clf-c02.domain-1.cloud.001',
        certificationId: certificationId,
        domainId: domainId,
        conceptId: conceptId,
      ),
    ];
    final Lesson lesson = await _syncAndRead(
      fixtures,
      trackId: 'aws-clf',
      lessonId: 'aws-clf.lesson.domain-1.practice',
    );

    expect(lesson.unitId, 'aws-clf.unit.domain-1');
    expect(lesson.domainId, 'aws-domain');
    expect(lesson.title, 'Cloud Concepts practice');
    expect(lesson.blocks.single.check, isNotNull);
  });

  test('projects v5 matchPairs matches into the runtime quiz item', () async {
    const String certificationId = 'aws:clf-c02';
    const String domainId = 'aws.clf-c02.domain.cloud-concepts';
    const String conceptId = 'aws.clf-c02.concept.cloud-value';
    final List<ContentFixture> fixtures = <ContentFixture>[
      _catalog(certificationId, 'domain-1', 'Cloud Concepts'),
      _runtime(
        id: 'aws.clf-c02.track.main',
        type: 'track',
        path: 'runtime/tracks/aws/clf-c02/track.json',
        json: <String, dynamic>{
          'legacyId': 'aws-clf',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'mode': 'questionBank',
          'summary': 'Bank',
          'domainIds': <String>[domainId],
          'unitIds': <String>[],
        },
      ),
      _runtime(
        id: domainId,
        type: 'domain',
        path: 'runtime/domains/aws/clf-c02/domain.json',
        json: <String, dynamic>{
          'legacyId': 'aws-domain',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'objectiveId': 'domain-1',
        },
      ),
      _runtime(
        id: conceptId,
        type: 'concept',
        path: 'runtime/concepts/aws/clf-c02/concept.json',
        json: <String, dynamic>{
          'legacyId': 'aws-concept',
          'certificationId': certificationId,
          'blueprintVersion': '2026-08-17',
          'domainId': domainId,
          'title': 'Value',
        },
      ),
      questionFixture(
        'aws.clf-c02.domain-1.cloud.001',
        certificationId: certificationId,
        domainId: domainId,
        conceptId: conceptId,
        itemType: 'matchPairs',
        options: const <Map<String, String>>[
          <String, String>{'id': 'left-1', 'label': 'EC2'},
          <String, String>{'id': 'left-2', 'label': 'Lambda'},
        ],
        matches: const <Map<String, String>>[
          <String, String>{'id': 'right-1', 'label': 'IaaS'},
          <String, String>{'id': 'right-2', 'label': 'Serverless'},
        ],
      ),
    ];

    final Lesson lesson = await _syncAndRead(
      fixtures,
      trackId: 'aws-clf',
      lessonId: 'aws-clf.lesson.domain-1.practice',
    );

    final QuizItem item = lesson.blocks.single.check!;
    expect(item.type, ItemType.matchPairs);
    expect(item.matches.map((QuizOption option) => option.id), <String>['right-1', 'right-2']);
    expect(item.matches.map((QuizOption option) => option.label), <String>['IaaS', 'Serverless']);
  });

  test('treats a local storage failure as an offline cache miss', () async {
    final RuntimeContentLessonRepository repository = RuntimeContentLessonRepository(
      inner: _OfflineLessons(),
      store: _BrokenCacheStore(),
      ownerIdProvider: () => 'person-1',
    );

    final Result<Lesson> result = await repository.getLesson(
      trackId: 'az-900',
      lessonId: 'lesson-1',
    );

    expect(result, isA<Err<Lesson>>());
    expect((result as Err<Lesson>).failure, isA<NetworkFailure>());
  });
}

Future<Lesson> _syncAndRead(
  List<ContentFixture> fixtures, {
  required String trackId,
  required String lessonId,
}) async {
  final PublicContentManifest release = manifest(fixtures);
  final RuntimeContentPinRegistry pins = RuntimeContentPinRegistry();
  final _PinObservingStore store = _PinObservingStore(pins);
  final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
    source: FakePublicContentSource(release, fixtures),
    store: store,
    pins: pins,
    delay: (_) async {},
  );
  await synchronizer.sync(ownerId: 'person-1');
  final RuntimeContentLessonRepository repository = RuntimeContentLessonRepository(
    inner: _OfflineLessons(),
    store: store,
    pins: pins,
    ownerIdProvider: () => 'person-1',
  );

  final Result<Lesson> result = await repository.getLesson(
    trackId: trackId,
    lessonId: lessonId,
  );
  await synchronizer.dispose();
  expect(store.observedPinnedRead, isTrue);
  return result.valueOrNull!;
}

ContentFixture _catalog(
  String certificationId,
  String objectiveId,
  String objectiveTitle,
) =>
    jsonFixture(
      id: 'certification-catalog',
      path: 'catalog/certifications.json',
      resourceType: 'certificationCatalog',
      json: <String, dynamic>{
        'schema': 'certigo.certification-catalog/v1',
        'certifications': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': certificationId,
            'blueprint': <String, dynamic>{
              'objectives': <Map<String, dynamic>>[
                <String, dynamic>{'id': objectiveId, 'title': objectiveTitle},
              ],
            },
          },
        ],
      },
    );

ContentFixture _runtime({
  required String id,
  required String type,
  required String path,
  required Map<String, dynamic> json,
}) =>
    jsonFixture(
      id: id,
      path: path,
      resourceType: type,
      json: <String, dynamic>{
        'schema': 'certigo.runtime.$type/v1',
        'resourceType': type,
        'id': id,
        ...json,
        'lifecycle': const <String, dynamic>{'status': 'active'},
      },
    );
