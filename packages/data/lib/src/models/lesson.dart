/// Lesson content model. A lesson is an ordered list of typed [LessonBlock]s
/// that drive the "Learn Loop" (Hook → Concept → Example → Check → Apply →
/// Recap). Quiz items embedded for checks are *public* — they never include the
/// correct answer; grading happens server-side.
library;

/// The kinds of content blocks a lesson can contain.
enum BlockType { hook, concept, example, code, check, recap, unknown }

BlockType _blockTypeFrom(String? raw) => switch (raw) {
  'hook' => BlockType.hook,
  'concept' => BlockType.concept,
  'example' => BlockType.example,
  'code' => BlockType.code,
  'check' => BlockType.check,
  'recap' => BlockType.recap,
  _ => BlockType.unknown,
};

/// Serialises a [BlockType] back to its wire string. Symmetric with the private
/// decoder above; public so the offline cache can round-trip a lesson to JSON.
String blockTypeToWire(BlockType t) => switch (t) {
  BlockType.hook => 'hook',
  BlockType.concept => 'concept',
  BlockType.example => 'example',
  BlockType.code => 'code',
  BlockType.check => 'check',
  BlockType.recap => 'recap',
  BlockType.unknown => 'unknown',
};

class Lesson {
  const Lesson({
    required this.id,
    required this.trackId,
    required this.unitId,
    required this.domainId,
    required this.title,
    required this.estMinutes,
    required this.blocks,
  });

  final String id;
  final String trackId;
  final String unitId;
  final String domainId;
  final String title;
  final int estMinutes;
  final List<LessonBlock> blocks;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    trackId: json['trackId'] as String? ?? '',
    unitId: json['unitId'] as String? ?? '',
    domainId: json['domainId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    estMinutes: (json['estMinutes'] as num?)?.toInt() ?? 5,
    blocks: (json['blocks'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => LessonBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Serialises the lesson to a JSON-ready map, symmetric with [Lesson.fromJson].
  /// Used by the offline lesson cache to persist a full session for airplane-mode
  /// reading; not sent to the server (lessons are read-only for the client).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trackId': trackId,
    'unitId': unitId,
    'domainId': domainId,
    'title': title,
    'estMinutes': estMinutes,
    'blocks': blocks.map((LessonBlock b) => b.toJson()).toList(),
  };
}

/// A single block of a lesson. Polymorphic but flattened into one class for
/// simple JSON handling; consumers switch on [type].
class LessonBlock {
  const LessonBlock({
    required this.type,
    required this.conceptId,
    this.title,
    this.body,
    this.code,
    this.language,
    this.check,
  });

  final BlockType type;

  /// Concept this block teaches/verifies — links content to mastery state.
  final String conceptId;
  final String? title;

  /// Markdown body for hook/concept/example/recap blocks.
  final String? body;

  /// Source for code blocks (rendered with the mono type + syntax tint).
  final String? code;
  final String? language;

  /// Inline check question for `check` blocks.
  final QuizItem? check;

  factory LessonBlock.fromJson(Map<String, dynamic> json) => LessonBlock(
    type: _blockTypeFrom(json['type'] as String?),
    conceptId: json['conceptId'] as String? ?? '',
    title: json['title'] as String?,
    body: json['body'] as String?,
    code: json['code'] as String?,
    language: json['language'] as String?,
    check: json['check'] == null ? null : QuizItem.fromJson(json['check'] as Map<String, dynamic>),
  );

  /// Serialises the block, symmetric with [LessonBlock.fromJson]. Optional
  /// fields are omitted when null so the round-trip decodes back identically.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': blockTypeToWire(type),
    'conceptId': conceptId,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (code != null) 'code': code,
    if (language != null) 'language': language,
    if (check != null) 'check': check!.toJson(),
  };
}

/// The interaction types supported by the quiz engine.
enum ItemType { mcq, multi, scenario, cloze, ordering, matchPairs, spotTheIssue, applied, unknown }

ItemType itemTypeFrom(String? raw) => switch (raw) {
  'mcq' => ItemType.mcq,
  'multi' => ItemType.multi,
  'scenario' => ItemType.scenario,
  'cloze' => ItemType.cloze,
  'ordering' => ItemType.ordering,
  'matchPairs' => ItemType.matchPairs,
  'spotTheIssue' => ItemType.spotTheIssue,
  'applied' => ItemType.applied,
  _ => ItemType.unknown,
};

String itemTypeToWire(ItemType t) => switch (t) {
  ItemType.mcq => 'mcq',
  ItemType.multi => 'multi',
  ItemType.scenario => 'scenario',
  ItemType.cloze => 'cloze',
  ItemType.ordering => 'ordering',
  ItemType.matchPairs => 'matchPairs',
  ItemType.spotTheIssue => 'spotTheIssue',
  ItemType.applied => 'applied',
  ItemType.unknown => 'unknown',
};

/// A *public* quiz item — sent to the client WITHOUT the correct answer.
class QuizItem {
  const QuizItem({
    required this.id,
    required this.conceptId,
    required this.type,
    required this.stem,
    required this.options,
    this.matches = const <QuizOption>[],
  });

  final String id;
  final String conceptId;
  final ItemType type;

  /// The question / prompt (markdown).
  final String stem;

  /// The primary choices. For `matchPairs` this is the *left* column
  /// (concepts); for `cloze`/`ordering` it is the word/step bank; for the
  /// select family (mcq/multi/scenario/spotTheIssue) it is the answer set.
  final List<QuizOption> options;

  /// The *right* column for `matchPairs` (definitions to pair with [options]).
  /// Empty for every other item type — backward-compatible: server payloads
  /// that omit it simply decode to `const []`.
  final List<QuizOption> matches;

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
    id: json['id'] as String,
    conceptId: json['conceptId'] as String? ?? '',
    type: itemTypeFrom(json['type'] as String?),
    stem: json['stem'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    matches: (json['matches'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Serialises the public quiz item, symmetric with [QuizItem.fromJson]. Still
  /// answer-free — this only persists what the server already sent to the client.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'conceptId': conceptId,
    'type': itemTypeToWire(type),
    'stem': stem,
    'options': options.map((QuizOption o) => o.toJson()).toList(),
    'matches': matches.map((QuizOption o) => o.toJson()).toList(),
  };
}

class QuizOption {
  const QuizOption({required this.id, required this.label});

  final String id;
  final String label;

  factory QuizOption.fromJson(Map<String, dynamic> json) =>
      QuizOption(id: json['id'] as String, label: json['label'] as String? ?? '');

  /// Serialises the option, symmetric with [QuizOption.fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'label': label};
}
