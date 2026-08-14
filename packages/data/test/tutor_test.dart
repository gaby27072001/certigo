import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('TutorExplainRequest.toJson', () {
    test('emits the exact wire contract and never leaks a userId', () {
      const TutorExplainRequest req = TutorExplainRequest(
        trackId: 'az-900',
        lessonId: 'cloud-concepts-1',
        itemId: 'item-3',
        selected: <String>['b', 'd'],
      );

      final Map<String, dynamic> json = req.toJson();

      expect(json, <String, dynamic>{
        'trackId': 'az-900',
        'lessonId': 'cloud-concepts-1',
        'itemId': 'item-3',
        'selected': <String>['b', 'd'],
      });
      expect(json.containsKey('userId'), isFalse);
    });
  });

  group('TutorExplanation.fromJson', () {
    test('parses a full grounded payload with personalization', () {
      final TutorExplanation exp = TutorExplanation.fromJson(<String, dynamic>{
        'itemId': 'item-3',
        'conceptId': 'shared-responsibility',
        'correct': false,
        'headline': 'Tu butes encore sur la responsabilité partagée.',
        'points': <dynamic>[
          'Le client garde la responsabilité des données.',
          'Azure gère le socle physique.',
        ],
        'encouragement': 'On y revient ensemble, ça rentre.',
        'recommendation': 'Refais la leçon « Responsabilité partagée ».',
        'citedConceptIds': <dynamic>['shared-responsibility', 'iaas-paas-saas'],
        'source': 'ai',
        'personalization': <String, dynamic>{
          'attempts': 4,
          'errors': 3,
          'accuracyPct': 25,
          'recurringStruggle': true,
          'masteredBefore': false,
          'trend': 'slipping',
          'topConfusedOption': 'Le fournisseur cloud est seul responsable',
        },
      });

      expect(exp.itemId, 'item-3');
      expect(exp.conceptId, 'shared-responsibility');
      expect(exp.correct, isFalse);
      expect(exp.points, hasLength(2));
      expect(exp.citedConceptIds, contains('iaas-paas-saas'));
      expect(exp.source, 'ai');
      expect(exp.isAiGenerated, isTrue);

      final TutorPersonalization p = exp.personalization;
      expect(p.attempts, 4);
      expect(p.errors, 3);
      expect(p.accuracyPct, 25);
      expect(p.recurringStruggle, isTrue);
      expect(p.masteredBefore, isFalse);
      expect(p.trend, 'slipping');
      expect(p.isSlipping, isTrue);
      expect(p.isImproving, isFalse);
      expect(p.topConfusedOption, isNotNull);
    });

    test('tolerates a minimal payload with safe defaults', () {
      final TutorExplanation exp = TutorExplanation.fromJson(<String, dynamic>{'itemId': 'item-1'});

      expect(exp.conceptId, '');
      expect(exp.correct, isFalse);
      expect(exp.points, isEmpty);
      expect(exp.citedConceptIds, isEmpty);
      expect(exp.source, 'grounded');
      expect(exp.isAiGenerated, isFalse);
      expect(exp.personalization.attempts, 0);
      expect(exp.personalization.trend, 'steady');
      expect(exp.personalization.isImproving, isFalse);
      expect(exp.personalization.isSlipping, isFalse);
      expect(exp.personalization.topConfusedOption, isNull);
    });
  });
}
