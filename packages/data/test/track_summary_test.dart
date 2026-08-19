import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('TrackSummary', () {
    test('decodes legacy Microsoft catalog payloads without breaking their level', () {
      final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
        'id': 'az-900',
        'code': 'AZ-900',
        'title': 'Microsoft Azure Fundamentals',
        'level': 'fundamentals',
        'summary': 'Cloud basics',
        'unitCount': 4,
        'lessonCount': 20,
      });

      expect(track.provider, CertificationProvider.microsoft);
      expect(track.level, 'fundamentals');
      expect(track.normalizedLevel, CertificationLevel.foundational);
      expect(track.status, CertificationLifecycleStatus.active);
      expect(track.hasLearningContent, isTrue);
    });

    test('infers GitHub only for legacy payloads that have no provider field', () {
      final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
        'id': 'github-foundations',
        'code': 'GH-900',
      });

      expect(track.provider, CertificationProvider.github);
    });

    test('keeps the four legacy Microsoft fundamentals selectable', () {
      for (final String code in <String>['AZ-900', 'AI-900', 'DP-900', 'SC-900']) {
        final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
          'id': code.toLowerCase(),
          'code': code,
          'title': code,
          'level': 'fundamentals',
          'contentStatus': 'available',
        });

        expect(track.provider, CertificationProvider.microsoft);
        expect(track.normalizedLevel, CertificationLevel.foundational);
        expect(track.hasLearningContent, isTrue);
      }
    });

    test('round-trips complete AWS metadata through the cache shape', () {
      const TrackSummary original = TrackSummary(
        id: 'aws:ans-c01',
        code: 'ANS-C01',
        title: 'AWS Certified Advanced Networking - Specialty',
        level: 'specialty',
        summary: '',
        unitCount: 0,
        lessonCount: 0,
        provider: CertificationProvider.aws,
        family: 'networking',
        certificationLevel: CertificationLevel.specialty,
        contentStatus: CertificationContentStatus.planned,
        officialUrl:
            'https://aws.amazon.com/certification/certified-advanced-networking-specialty/',
        examGuideUrl: 'https://docs.aws.amazon.com/aws-certification/latest/'
            'advanced-networking-specialty-01/advanced-networking-specialty-01.html',
        catalogVersion: '2026-08-17',
        status: CertificationLifecycleStatus.activeRetiring,
        officialCode: 'ANS-C01',
        slug: 'ans-c01',
        officialSlug: 'certified-advanced-networking-specialty',
        blueprint: CertificationBlueprint(
          version: '2026-08-17',
          objectives: <CertificationObjective>[
            CertificationObjective(
              id: 'domain-1',
              title: 'Network Design',
              weightPercent: 30.5,
              weightType: 'exact',
            ),
          ],
        ),
        lifecycleDetails: CertificationLifecycle(lastExamOn: '2026-08-25', note: 'Last exam date.'),
      );

      final TrackSummary decoded = TrackSummary.fromJson(original.toJson());

      expect(decoded.provider, CertificationProvider.aws);
      expect(decoded.normalizedLevel, CertificationLevel.specialty);
      expect(decoded.contentStatus, CertificationContentStatus.planned);
      expect(decoded.id, 'aws:ans-c01');
      expect(decoded.status, CertificationLifecycleStatus.activeRetiring);
      expect(decoded.isActive, isTrue);
      expect(decoded.blueprint!.objectives.single.weightPercent, 30.5);
      expect(decoded.lifecycleDetails!.lastExamOn, '2026-08-25');
      expect(decoded.hasLearningContent, isFalse);
    });

    test('uses a provider badge when Google publishes no public exam code', () {
      const TrackSummary track = TrackSummary(
        id: 'gcp:cloud-digital-leader',
        code: '',
        title: 'Cloud Digital Leader',
        level: 'foundational',
        summary: '',
        unitCount: 0,
        lessonCount: 0,
        provider: CertificationProvider.gcp,
      );

      expect(track.code, isEmpty);
      expect(track.displayCode, 'GCP');
    });

    test('accepts all canonical lifecycle states and rejects unknown values', () {
      const Map<String, CertificationLifecycleStatus> expected =
          <String, CertificationLifecycleStatus>{
        'announced': CertificationLifecycleStatus.announced,
        'active': CertificationLifecycleStatus.active,
        'active-retiring': CertificationLifecycleStatus.activeRetiring,
        'retired': CertificationLifecycleStatus.retired,
        'replaced': CertificationLifecycleStatus.replaced,
      };
      for (final MapEntry<String, CertificationLifecycleStatus> entry in expected.entries) {
        final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
          'id': 'aws:test',
          'provider': 'aws',
          'status': entry.key,
        });
        expect(track.status, entry.value);
      }

      expect(
        () => TrackSummary.fromJson(<String, dynamic>{'id': 'unknown', 'provider': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => TrackSummary.fromJson(<String, dynamic>{
          'id': 'aws:test',
          'provider': 'aws',
          'status': 'preview',
        }),
        throwsFormatException,
      );
    });

    test('decodes canonical GCP metadata without inventing an exam code', () {
      final TrackSummary track = TrackSummary.fromJson(<String, dynamic>{
        'id': 'gcp:cloud-digital-leader',
        'provider': 'gcp',
        'code': '',
        'officialCode': null,
        'status': 'active',
        'blueprint': <String, dynamic>{
          'version': '2026-08-17',
          'objectives': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'section-1',
              'title': 'Digital Transformation with Google Cloud',
              'weightPercent': 18.5,
              'weightType': 'approximate',
            },
          ],
        },
      });

      expect(track.officialCode, isNull);
      expect(track.displayCode, 'GCP');
      expect(track.blueprint!.objectives.single.weightPercent, 18.5);
      expect(track.blueprint!.objectives.single.weightLabel, '~18.5%');
    });
  });
}
