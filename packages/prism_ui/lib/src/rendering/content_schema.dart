import 'content_block.dart';

/// Canonical content-schema *generation* shipped by wp-p1-02 ("v2").
///
/// This is distinct from [RendererSchema.current] (the renderer *contract*
/// version, expressed on the wire as `renderer/N`). A block advertises the
/// contract it targets through [ContentBlock.schemaVersion]; the constant below
/// records which generation of canonical block definitions this build carries.
/// The portable AJV artifact (`schemas/content/v2/block.schema.json`) pins the
/// same number via `x-contentSchemaVersion`, and a coherence test keeps the two
/// in lock-step.
const int kContentSchemaVersion = 2;

/// Envelope field reserved for the future multi-tenant (B2B) boundary
/// (Partie 28).
///
/// The field is *reserved, not implemented*: canonical v2 content may carry it,
/// the validator tolerates it (a [String]), and the renderer never consumes it.
/// No B2B behaviour is wired here — this only pins the name so future work does
/// not collide with an existing payload key.
const String kReservedTenantIdField = 'tenantId';

/// The canonical block types covered by content-schema v2.
///
/// Each value carries its wire string (the value that appears in
/// [ContentBlock.type]). These are the *content* contract names; they are
/// intentionally independent from whichever keys a concrete [RendererRegistry]
/// happens to wire, so the catalogue can describe blocks the current build does
/// not yet paint.
enum CanonicalBlockType {
  /// Opening splash / motivational lead-in.
  hero('hero'),

  /// A single teaching concept.
  concept('concept'),

  /// A worked example.
  example('example'),

  /// A diagram (e.g. Mermaid source or an asset reference).
  diagram('diagram'),

  /// Multiple-choice quiz item.
  quizMultipleChoice('quiz.multipleChoice'),

  /// True / false quiz item.
  quizTrueFalse('quiz.trueFalse'),

  /// Matching-pairs quiz item.
  quizMatching('quiz.matching'),

  /// A narrative scenario.
  scenario('scenario'),

  /// A longer-form case study.
  caseStudy('caseStudy'),

  /// A single hands-on lab step.
  labStep('labStep'),

  /// A prompt handed to the in-app AI tutor.
  aiTutorPrompt('aiTutorPrompt'),

  /// A graded exam question.
  examQuestion('examQuestion'),

  /// A closing summary.
  summary('summary');

  const CanonicalBlockType(this.wire);

  /// The wire string that appears in [ContentBlock.type].
  final String wire;

  /// Resolves a wire string to its [CanonicalBlockType], or `null` when the
  /// string is not part of the canonical v2 catalogue.
  static CanonicalBlockType? fromWire(String wire) {
    for (final CanonicalBlockType type in CanonicalBlockType.values) {
      if (type.wire == wire) {
        return type;
      }
    }
    return null;
  }
}

/// The shape a required payload field must satisfy.
enum FieldKind {
  /// A non-empty [String].
  stringNonEmpty,

  /// A [bool].
  boolean,

  /// A [List] with at least one element.
  nonEmptyList,
}

/// A single required field of a block payload.
class FieldSpec {
  /// Describes a required [name] whose value must satisfy [kind].
  const FieldSpec(this.name, this.kind);

  /// The key read from [ContentBlock.data].
  final String name;

  /// The expected shape of the value.
  final FieldKind kind;
}

/// The canonical definition of one block type's payload.
class BlockContentSchema {
  /// Describes the required payload fields for [type].
  const BlockContentSchema({required this.type, required this.requiredFields});

  /// The block type this schema describes.
  final CanonicalBlockType type;

  /// The fields a conforming payload must provide.
  final List<FieldSpec> requiredFields;

  /// The bare names of [requiredFields], in declaration order.
  ///
  /// The coherence test asserts this set equals the matching JSON Schema
  /// `data.required` array, so the Dart catalogue and the AJV artifact can never
  /// silently drift.
  List<String> get requiredFieldNames =>
      requiredFields.map((FieldSpec field) => field.name).toList(growable: false);
}

/// The canonical v2 payload definitions, one per [CanonicalBlockType].
///
/// Kept as a top-level `const` so the whole catalogue is a compile-time
/// constant; [ContentSchemaRegistry.canonicalV2] indexes it lazily.
const List<BlockContentSchema> _canonicalV2Specs = <BlockContentSchema>[
  BlockContentSchema(
    type: CanonicalBlockType.hero,
    requiredFields: <FieldSpec>[FieldSpec('title', FieldKind.stringNonEmpty)],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.concept,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('body', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.example,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('body', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.diagram,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('source', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.quizMultipleChoice,
    requiredFields: <FieldSpec>[
      FieldSpec('prompt', FieldKind.stringNonEmpty),
      FieldSpec('options', FieldKind.nonEmptyList),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.quizTrueFalse,
    requiredFields: <FieldSpec>[
      FieldSpec('prompt', FieldKind.stringNonEmpty),
      FieldSpec('answer', FieldKind.boolean),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.quizMatching,
    requiredFields: <FieldSpec>[
      FieldSpec('prompt', FieldKind.stringNonEmpty),
      FieldSpec('pairs', FieldKind.nonEmptyList),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.scenario,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('body', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.caseStudy,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('body', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.labStep,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('instructions', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.aiTutorPrompt,
    requiredFields: <FieldSpec>[FieldSpec('prompt', FieldKind.stringNonEmpty)],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.examQuestion,
    requiredFields: <FieldSpec>[
      FieldSpec('prompt', FieldKind.stringNonEmpty),
      FieldSpec('options', FieldKind.nonEmptyList),
      FieldSpec('answer', FieldKind.stringNonEmpty),
    ],
  ),
  BlockContentSchema(
    type: CanonicalBlockType.summary,
    requiredFields: <FieldSpec>[
      FieldSpec('title', FieldKind.stringNonEmpty),
      FieldSpec('points', FieldKind.nonEmptyList),
    ],
  ),
];

/// An indexed, immutable catalogue of canonical block schemas.
class ContentSchemaRegistry {
  ContentSchemaRegistry._(this._byType);

  final Map<CanonicalBlockType, BlockContentSchema> _byType;

  static ContentSchemaRegistry? _canonical;

  /// The canonical v2 catalogue (cached after first use).
  factory ContentSchemaRegistry.canonicalV2() {
    return _canonical ??= ContentSchemaRegistry._(<CanonicalBlockType, BlockContentSchema>{
      for (final BlockContentSchema spec in _canonicalV2Specs) spec.type: spec,
    });
  }

  /// The schema for [type], or `null` when the type is absent.
  BlockContentSchema? schemaFor(CanonicalBlockType type) => _byType[type];

  /// Every type the catalogue describes.
  Iterable<CanonicalBlockType> get types => _byType.keys;

  /// The number of block types described.
  int get length => _byType.length;
}

/// Why a [ContentBlock] failed validation.
enum SchemaViolationKind {
  /// [ContentBlock.type] is not a canonical v2 type.
  unknownType,

  /// [ContentBlock.schemaVersion] is outside the supported renderer range.
  unsupportedSchema,

  /// A required field is absent (or explicitly `null`).
  missingField,

  /// A required field is present but has the wrong shape.
  wrongFieldType,

  /// The reserved [kReservedTenantIdField] is present with a non-string value.
  reservedFieldMisuse,
}

/// A single validation problem.
class SchemaViolation {
  /// Records a [kind] of problem, optionally scoped to [field].
  const SchemaViolation({required this.kind, required this.message, this.field = ''});

  /// The category of the problem.
  final SchemaViolationKind kind;

  /// The offending field name, or the empty string when block-scoped.
  final String field;

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => '[${kind.name}] ${field.isEmpty ? '' : '$field: '}$message';
}

/// The outcome of validating one [ContentBlock].
class SchemaValidationResult {
  /// Wraps the [violations] found (empty means valid).
  const SchemaValidationResult(this.violations);

  /// Every problem found, in discovery order.
  final List<SchemaViolation> violations;

  /// Whether the block conforms to canonical v2.
  bool get isValid => violations.isEmpty;
}

/// Validates [ContentBlock]s against the canonical v2 catalogue.
///
/// The validator is deliberately dependency-free (no external JSON-Schema
/// package): it mirrors the portable AJV artifact so it can run inside the
/// font-free hermetic test harness and, eventually, at content ingestion time.
class ContentBlockValidator {
  /// Validates against [registry], defaulting to the canonical v2 catalogue.
  ContentBlockValidator([ContentSchemaRegistry? registry])
    : _registry = registry ?? ContentSchemaRegistry.canonicalV2();

  final ContentSchemaRegistry _registry;

  /// Whether [block] conforms to canonical v2.
  bool isValid(ContentBlock block) => validate(block).violations.isEmpty;

  /// Fully validates [block], collecting every violation.
  SchemaValidationResult validate(ContentBlock block) {
    final List<SchemaViolation> violations = <SchemaViolation>[];

    final CanonicalBlockType? type = CanonicalBlockType.fromWire(block.type);
    if (type == null) {
      violations.add(
        SchemaViolation(
          kind: SchemaViolationKind.unknownType,
          field: 'type',
          message: 'Type de bloc non canonique : "${block.type}".',
        ),
      );
      _checkReservedTenantId(block, violations);
      return SchemaValidationResult(violations);
    }

    if (!RendererSchema.supports(block.schemaVersion)) {
      violations.add(
        SchemaViolation(
          kind: SchemaViolationKind.unsupportedSchema,
          field: 'schemaVersion',
          message:
              'Version de schema non supportee : ${block.schemaVersion} '
              '(supporte 1..${RendererSchema.current}).',
        ),
      );
    }

    final BlockContentSchema schema = _registry.schemaFor(type)!;
    for (final FieldSpec spec in schema.requiredFields) {
      _checkRequiredField(block, spec, violations);
    }

    _checkReservedTenantId(block, violations);
    return SchemaValidationResult(violations);
  }

  void _checkRequiredField(ContentBlock block, FieldSpec spec, List<SchemaViolation> out) {
    final bool present = block.data.containsKey(spec.name);
    final Object? value = block.data[spec.name];
    if (!present || value == null) {
      out.add(
        SchemaViolation(
          kind: SchemaViolationKind.missingField,
          field: spec.name,
          message: 'Champ requis absent.',
        ),
      );
      return;
    }

    final bool ok = switch (spec.kind) {
      FieldKind.stringNonEmpty => value is String && value.isNotEmpty,
      FieldKind.boolean => value is bool,
      FieldKind.nonEmptyList => value is List && value.isNotEmpty,
    };
    if (!ok) {
      out.add(
        SchemaViolation(
          kind: SchemaViolationKind.wrongFieldType,
          field: spec.name,
          message: 'Format invalide : attendu ${spec.kind.name}.',
        ),
      );
    }
  }

  void _checkReservedTenantId(ContentBlock block, List<SchemaViolation> out) {
    if (!block.data.containsKey(kReservedTenantIdField)) {
      return;
    }
    final Object? value = block.data[kReservedTenantIdField];
    if (value != null && value is! String) {
      out.add(
        SchemaViolation(
          kind: SchemaViolationKind.reservedFieldMisuse,
          field: kReservedTenantIdField,
          message:
              'Champ reserve "$kReservedTenantIdField" (Partie 28) doit '
              'etre une chaine ; accepte mais non consomme par le renderer v2.',
        ),
      );
    }
  }
}
