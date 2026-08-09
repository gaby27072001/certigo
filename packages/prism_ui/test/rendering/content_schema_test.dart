// Hermetic tests for the canonical content-schema catalogue + validator (v2).
//
// These tests import the schema primitives directly and exercise them as plain
// Dart. The portable AJV artifact (`schemas/content/v2/block.schema.json`) is
// loaded from disk so a coherence test can prove the Dart catalogue and the
// JSON Schema never silently drift.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/src/rendering/content_block.dart';
import 'package:prism_ui/src/rendering/content_schema.dart';

/// One minimal, conforming payload per canonical type.
///
/// The catalogue-coverage test asserts every [CanonicalBlockType] appears here,
/// so a new type cannot be added without a matching valid fixture.
const Map<CanonicalBlockType, ContentBlock> _validFixtures = <CanonicalBlockType, ContentBlock>{
  CanonicalBlockType.hero: ContentBlock(
    type: 'hero',
    data: <String, dynamic>{'title': 'Bienvenue'},
  ),
  CanonicalBlockType.concept: ContentBlock(
    type: 'concept',
    data: <String, dynamic>{'title': 'Idee', 'body': 'Explication'},
  ),
  CanonicalBlockType.example: ContentBlock(
    type: 'example',
    data: <String, dynamic>{'title': 'Exemple', 'body': 'Detail'},
  ),
  CanonicalBlockType.diagram: ContentBlock(
    type: 'diagram',
    data: <String, dynamic>{'title': 'Flux', 'source': 'graph TD; A --> B'},
  ),
  CanonicalBlockType.quizMultipleChoice: ContentBlock(
    type: 'quiz.multipleChoice',
    data: <String, dynamic>{
      'prompt': 'Quelle reponse ?',
      'options': <Object>['a', 'b'],
    },
  ),
  CanonicalBlockType.quizTrueFalse: ContentBlock(
    type: 'quiz.trueFalse',
    data: <String, dynamic>{'prompt': 'Vrai ou faux ?', 'answer': true},
  ),
  CanonicalBlockType.quizMatching: ContentBlock(
    type: 'quiz.matching',
    data: <String, dynamic>{
      'prompt': 'Associez',
      'pairs': <Object>[
        <String, String>{'left': 'terme', 'right': 'definition'},
      ],
    },
  ),
  CanonicalBlockType.scenario: ContentBlock(
    type: 'scenario',
    data: <String, dynamic>{'title': 'Scenario', 'body': 'Recit'},
  ),
  CanonicalBlockType.caseStudy: ContentBlock(
    type: 'caseStudy',
    data: <String, dynamic>{'title': 'Cas', 'body': 'Analyse'},
  ),
  CanonicalBlockType.labStep: ContentBlock(
    type: 'labStep',
    data: <String, dynamic>{'title': 'Etape', 'instructions': 'Faites ceci'},
  ),
  CanonicalBlockType.aiTutorPrompt: ContentBlock(
    type: 'aiTutorPrompt',
    data: <String, dynamic>{'prompt': 'Explique-moi ce concept'},
  ),
  CanonicalBlockType.examQuestion: ContentBlock(
    type: 'examQuestion',
    data: <String, dynamic>{
      'prompt': 'Question notee',
      'options': <Object>['a', 'b'],
      'answer': 'a',
    },
  ),
  CanonicalBlockType.summary: ContentBlock(
    type: 'summary',
    data: <String, dynamic>{
      'title': 'Resume',
      'points': <Object>['point 1', 'point 2'],
    },
  ),
};

/// Loads the portable AJV artifact from whichever working directory the test
/// runner uses (`packages/prism_ui` under `flutter test`, or the repo root).
Map<String, dynamic> _loadBlockSchema() {
  const List<String> candidates = <String>[
    'schemas/content/v2/block.schema.json',
    'packages/prism_ui/schemas/content/v2/block.schema.json',
  ];
  for (final String path in candidates) {
    final File file = File(path);
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
  }
  fail('block.schema.json introuvable (essaye: ${candidates.join(', ')})');
}

/// The `$defs` key that describes [type]'s payload in the JSON Schema.
String _dataDefKey(CanonicalBlockType type) => 'data_${type.wire.replaceAll('.', '_')}';

void main() {
  final ContentBlockValidator validator = ContentBlockValidator();

  group('canonical catalogue', () {
    final ContentSchemaRegistry registry = ContentSchemaRegistry.canonicalV2();

    test('describes the 13 canonical types', () {
      expect(registry.length, 13);
      expect(CanonicalBlockType.values, hasLength(13));
    });

    test('exposes a schema for every canonical type', () {
      for (final CanonicalBlockType type in CanonicalBlockType.values) {
        expect(registry.schemaFor(type), isNotNull, reason: 'aucun schema pour ${type.wire}');
      }
    });

    test('round-trips every wire string through fromWire', () {
      for (final CanonicalBlockType type in CanonicalBlockType.values) {
        expect(CanonicalBlockType.fromWire(type.wire), type);
      }
      expect(CanonicalBlockType.fromWire('does.not.exist'), isNull);
    });

    test('pins the content-schema generation to v2', () {
      expect(kContentSchemaVersion, 2);
      expect(kReservedTenantIdField, 'tenantId');
    });
  });

  group('valid payloads', () {
    test('a fixture is provided for every canonical type', () {
      expect(_validFixtures.keys, unorderedEquals(CanonicalBlockType.values));
    });

    for (final MapEntry<CanonicalBlockType, ContentBlock> entry in _validFixtures.entries) {
      test('accepts a minimal ${entry.key.wire} block', () {
        final SchemaValidationResult result = validator.validate(entry.value);
        expect(
          result.isValid,
          isTrue,
          reason: result.violations.map((SchemaViolation v) => v.toString()).join('; '),
        );
        expect(validator.isValid(entry.value), isTrue);
      });
    }
  });

  group('invalid payloads', () {
    test('rejects a non-canonical type', () {
      const ContentBlock block = ContentBlock(
        type: 'totallyUnknown',
        data: <String, dynamic>{'title': 'x'},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(result.isValid, isFalse);
      expect(
        result.violations.map((SchemaViolation v) => v.kind),
        contains(SchemaViolationKind.unknownType),
      );
    });

    test('rejects a missing required field', () {
      const ContentBlock block = ContentBlock(
        type: 'concept',
        data: <String, dynamic>{'title': 'Idee'},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(result.isValid, isFalse);
      expect(
        result.violations.any(
          (SchemaViolation v) => v.kind == SchemaViolationKind.missingField && v.field == 'body',
        ),
        isTrue,
      );
    });

    test('rejects a string field carrying the wrong shape', () {
      const ContentBlock block = ContentBlock(
        type: 'concept',
        data: <String, dynamic>{'title': 'Idee', 'body': 3},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(
        result.violations.any(
          (SchemaViolation v) => v.kind == SchemaViolationKind.wrongFieldType && v.field == 'body',
        ),
        isTrue,
      );
    });

    test('rejects an empty list where a non-empty list is required', () {
      const ContentBlock block = ContentBlock(
        type: 'quiz.multipleChoice',
        data: <String, dynamic>{'prompt': 'Q', 'options': <Object>[]},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(
        result.violations.any(
          (SchemaViolation v) =>
              v.kind == SchemaViolationKind.wrongFieldType && v.field == 'options',
        ),
        isTrue,
      );
    });

    test('rejects a boolean field given a string', () {
      const ContentBlock block = ContentBlock(
        type: 'quiz.trueFalse',
        data: <String, dynamic>{'prompt': 'Q', 'answer': 'oui'},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(
        result.violations.any(
          (SchemaViolation v) =>
              v.kind == SchemaViolationKind.wrongFieldType && v.field == 'answer',
        ),
        isTrue,
      );
    });

    test('rejects an unsupported renderer schema version', () {
      const ContentBlock block = ContentBlock(
        type: 'hero',
        data: <String, dynamic>{'title': 'Bienvenue'},
        schemaVersion: 99,
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(
        result.violations.map((SchemaViolation v) => v.kind),
        contains(SchemaViolationKind.unsupportedSchema),
      );
    });
  });

  group('reserved tenantId (Partie 28)', () {
    test('tolerates a string tenantId without consuming it', () {
      const ContentBlock block = ContentBlock(
        type: 'hero',
        data: <String, dynamic>{'title': 'Bienvenue', 'tenantId': 'acme'},
      );
      expect(validator.isValid(block), isTrue);
    });

    test('tolerates a null tenantId', () {
      const ContentBlock block = ContentBlock(
        type: 'hero',
        data: <String, dynamic>{'title': 'Bienvenue', 'tenantId': null},
      );
      expect(validator.isValid(block), isTrue);
    });

    test('rejects a non-string tenantId', () {
      const ContentBlock block = ContentBlock(
        type: 'hero',
        data: <String, dynamic>{'title': 'Bienvenue', 'tenantId': 42},
      );
      final SchemaValidationResult result = validator.validate(block);
      expect(
        result.violations.map((SchemaViolation v) => v.kind),
        contains(SchemaViolationKind.reservedFieldMisuse),
      );
    });

    test('still checks the reserved field for an unknown type', () {
      const ContentBlock block = ContentBlock(type: 'nope', data: <String, dynamic>{'tenantId': 7});
      final Set<SchemaViolationKind> kinds = validator
          .validate(block)
          .violations
          .map((SchemaViolation v) => v.kind)
          .toSet();
      expect(kinds, contains(SchemaViolationKind.unknownType));
      expect(kinds, contains(SchemaViolationKind.reservedFieldMisuse));
    });
  });

  group('JSON <-> Dart coherence', () {
    final Map<String, dynamic> schema = _loadBlockSchema();
    final ContentSchemaRegistry registry = ContentSchemaRegistry.canonicalV2();

    test('is a draft 2020-12 schema pinned to v2', () {
      expect(schema[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
      expect(schema['x-contentSchemaVersion'], 2);
      expect(
        (schema['required'] as List<dynamic>).cast<String>(),
        unorderedEquals(<String>['type', 'data']),
      );
    });

    test('oneOf dispatches on exactly the 13 canonical wire strings', () {
      final List<dynamic> branches = schema['oneOf'] as List<dynamic>;
      expect(branches, hasLength(13));
      final List<String> consts = <String>[];
      for (final dynamic branch in branches) {
        final Map<String, dynamic> properties =
            (branch as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
        final Map<String, dynamic> typeSchema = properties['type'] as Map<String, dynamic>;
        consts.add(typeSchema['const'] as String);
      }
      expect(
        consts,
        unorderedEquals(<String>[
          for (final CanonicalBlockType type in CanonicalBlockType.values) type.wire,
        ]),
      );
    });

    test('each data required array matches the Dart catalogue', () {
      final Map<String, dynamic> defs = schema[r'$defs'] as Map<String, dynamic>;
      for (final CanonicalBlockType type in CanonicalBlockType.values) {
        final Map<String, dynamic> def = defs[_dataDefKey(type)] as Map<String, dynamic>;
        final List<String> jsonRequired = (def['required'] as List<dynamic>).cast<String>();
        final List<String> dartRequired = registry.schemaFor(type)!.requiredFieldNames;
        expect(
          jsonRequired,
          unorderedEquals(dartRequired),
          reason: 'derive de champs requis pour ${type.wire}',
        );
      }
    });

    test('reserves tenantId as an optional string (Partie 28)', () {
      final Map<String, dynamic> defs = schema[r'$defs'] as Map<String, dynamic>;
      final Map<String, dynamic> tenantId = defs[kReservedTenantIdField] as Map<String, dynamic>;
      expect(tenantId['type'], 'string');
      expect(tenantId['minLength'], 1);
      expect(tenantId.containsKey(r'$comment'), isTrue);
      expect(tenantId[r'$comment'] as String, contains('Partie 28'));
    });
  });
}
