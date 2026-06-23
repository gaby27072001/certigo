import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('NextBest.fromJson', () {
    test('parses a full ranked payload and exposes the top action', () {
      final NextBest next = NextBest.fromJson(<String, dynamic>{
        'trackId': 'az-900',
        'generatedAt': '2026-06-23T08:30:00Z',
        'items': <dynamic>[
          <String, dynamic>{
            'kind': 'review',
            'lessonId': 'shared-responsibility-1',
            'unitId': 'cloud-concepts',
            'conceptId': 'shared-responsibility',
            'title': 'Responsabilité partagée',
            'domainId': 'cloud-concepts',
            'domainName': 'Concepts du cloud',
            'reason': 'Tu risques d\'oublier ce concept bientôt.',
            'estMinutes': 4,
            'priority': 92,
            'masteryPct': 60,
            'forgettingRiskPct': 78,
          },
          <String, dynamic>{
            'kind': 'practice',
            'lessonId': 'pricing-1',
            'unitId': 'management',
            'conceptId': 'pricing',
            'title': 'Modèles de coût',
            'domainId': 'management',
            'domainName': 'Gestion et gouvernance',
            'reason': 'Tu butes souvent sur ce point.',
            'estMinutes': 5,
            'priority': 81,
            'masteryPct': 40,
            'forgettingRiskPct': 30,
          },
        ],
      });

      expect(next.trackId, 'az-900');
      expect(next.generatedAt, DateTime.utc(2026, 6, 23, 8, 30));
      expect(next.isEmpty, isFalse);
      expect(next.items, hasLength(2));

      final Recommendation top = next.top!;
      expect(top.kind, RecommendationKind.review);
      expect(top.lessonId, 'shared-responsibility-1');
      expect(top.unitId, 'cloud-concepts');
      expect(top.conceptId, 'shared-responsibility');
      expect(top.title, 'Responsabilité partagée');
      expect(top.domainName, 'Concepts du cloud');
      expect(top.reason, 'Tu risques d\'oublier ce concept bientôt.');
      expect(top.estMinutes, 4);
      expect(top.priority, 92);
      expect(top.masteryPct, 60);
      expect(top.forgettingRiskPct, 78);
      expect(top.hasLesson, isTrue);

      expect(next.items[1].kind, RecommendationKind.practice);
    });

    test('maps every wire kind, including the "start" fallback', () {
      Recommendation item(String? kind) => Recommendation.fromJson(<String, dynamic>{
            'kind': kind,
            'title': 't',
          });

      expect(item('practice').kind, RecommendationKind.practice);
      expect(item('review').kind, RecommendationKind.review);
      expect(item('resume').kind, RecommendationKind.resume);
      expect(item('start').kind, RecommendationKind.start);
      expect(item('mystery').kind, RecommendationKind.start);
      expect(item(null).kind, RecommendationKind.start);
    });

    test('tolerates a minimal/empty payload with safe defaults', () {
      final NextBest next = NextBest.fromJson(<String, dynamic>{});

      expect(next.trackId, '');
      expect(next.generatedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
      expect(next.isEmpty, isTrue);
      expect(next.items, isEmpty);
      expect(next.top, isNull);
    });

    test('defaults a sparse item and treats a missing lesson as no-lesson', () {
      final Recommendation r = Recommendation.fromJson(<String, dynamic>{
        'title': 'Démarre une leçon',
      });

      expect(r.kind, RecommendationKind.start);
      expect(r.lessonId, isNull);
      expect(r.unitId, isNull);
      expect(r.conceptId, isNull);
      expect(r.domainId, '');
      expect(r.domainName, '');
      expect(r.reason, '');
      expect(r.estMinutes, 0);
      expect(r.priority, 0);
      expect(r.masteryPct, 0);
      expect(r.forgettingRiskPct, 0);
      expect(r.hasLesson, isFalse);
    });
  });
}
