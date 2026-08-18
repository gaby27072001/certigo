/// A lightweight summary of one certification track, for discovery and selection.
///
/// The catalog endpoint (`GET /catalog/tracks`) returns one of these per
/// certification. Learning content may still be [CertificationContentStatus.planned]:
/// this lets Certigo publish an official multi-cloud inventory before lessons arrive.
library;

enum CertificationProvider { microsoft, aws, gcp, github }

extension CertificationProviderInfo on CertificationProvider {
  String get wireName => name;

  String get displayName => switch (this) {
        CertificationProvider.microsoft => 'Microsoft',
        CertificationProvider.aws => 'AWS',
        CertificationProvider.gcp => 'Google Cloud',
        CertificationProvider.github => 'GitHub',
      };

  String get badgeLabel => switch (this) {
        CertificationProvider.microsoft => 'MS',
        CertificationProvider.aws => 'AWS',
        CertificationProvider.gcp => 'GCP',
        CertificationProvider.github => 'GH',
      };
}

enum CertificationLevel { foundational, associate, professional, specialty, unspecified }

extension CertificationLevelInfo on CertificationLevel {
  String get wireName => name;
}

enum CertificationLifecycleStatus { active, retired }

enum CertificationContentStatus { available, planned }

CertificationProvider _providerFromJson(Map<String, dynamic> json) {
  final String? raw = json['provider'] as String?;
  if (raw != null && raw.isNotEmpty) {
    return CertificationProvider.values.firstWhere(
      (CertificationProvider provider) => provider.wireName == raw.toLowerCase(),
      orElse: () => throw FormatException('Unsupported certification provider: $raw'),
    );
  }

  final String id = (json['id'] as String? ?? '').toLowerCase();
  final String code = (json['code'] as String? ?? '').toLowerCase();
  if (id.startsWith('github') || id.startsWith('gh-') || code.startsWith('gh')) {
    return CertificationProvider.github;
  }
  return CertificationProvider.microsoft;
}

CertificationLevel _levelFromWire(String raw) => switch (raw.toLowerCase()) {
      'foundational' || 'fundamentals' => CertificationLevel.foundational,
      'associate' => CertificationLevel.associate,
      'professional' || 'expert' => CertificationLevel.professional,
      'specialty' => CertificationLevel.specialty,
      _ => CertificationLevel.unspecified,
    };

T _enumFromWire<T extends Enum>(String raw, List<T> values, String fieldName) {
  return values.firstWhere(
    (T value) => value.name == raw.toLowerCase(),
    orElse: () => throw FormatException('Unsupported $fieldName: $raw'),
  );
}

class TrackSummary {
  const TrackSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.level,
    required this.summary,
    required this.unitCount,
    required this.lessonCount,
    this.domains = const <CertificationDomain>[],
    this.prerequisites = '',
    this.studyGuideUrl = '',
    this.examUrl = '',
    this.blueprintDate = '',
    this.lifecycle = '',
    this.lifecycleNote = '',
    this.examDetailsNote = '',
    this.learningAvailable = true,
    this.replacementCode = '',
    this.migrationNote = '',
    this.provider = CertificationProvider.microsoft,
    this.family = 'other',
    this.certificationLevel = CertificationLevel.unspecified,
    this.status = CertificationLifecycleStatus.active,
    this.contentStatus = CertificationContentStatus.available,
    this.officialUrl,
    this.examGuideUrl,
    this.catalogVersion,
    this.blueprintPublishedOn,
    this.blueprintVersion,
    this.languages = const <String>[],
    this.durationMinutes,
    this.aliases = const <String>[],
    this.replacedBy,
    this.retiresOn,
    this.retiredOn,
  });

  final String id;
  final String code;
  final String title;

  /// Legacy authoring level retained for catalog v1 compatibility.
  final String level;

  final String summary;
  final int unitCount;
  final int lessonCount;

  /// Microsoft 2026 overlay fields retained as a compatible wire façade.
  final List<CertificationDomain> domains;
  final String prerequisites;
  final String studyGuideUrl;
  final String examUrl;
  final String blueprintDate;
  final String lifecycle;
  final String lifecycleNote;
  final String examDetailsNote;
  final bool learningAvailable;
  final String replacementCode;
  final String migrationNote;

  final CertificationProvider provider;
  final String family;
  final CertificationLevel certificationLevel;
  final CertificationLifecycleStatus status;
  final CertificationContentStatus contentStatus;
  final String? officialUrl;
  final String? examGuideUrl;
  final String? catalogVersion;
  final String? blueprintPublishedOn;
  final String? blueprintVersion;
  final List<String> languages;
  final int? durationMinutes;
  final List<String> aliases;
  final String? replacedBy;
  final String? retiresOn;
  final String? retiredOn;

  CertificationLevel get normalizedLevel => certificationLevel == CertificationLevel.unspecified
      ? _levelFromWire(level)
      : certificationLevel;

  bool get isRetired => status == CertificationLifecycleStatus.retired || lifecycle == 'retired';

  bool get isActive => !isRetired;

  bool get hasLearningContent =>
      learningAvailable && contentStatus == CertificationContentStatus.available;

  bool get hasOfficialMetadata =>
      domains.isNotEmpty ||
      prerequisites.isNotEmpty ||
      officialStudyGuideUrl.isNotEmpty ||
      officialExamUrl.isNotEmpty ||
      blueprintLabel.isNotEmpty ||
      lifecycleNote.isNotEmpty ||
      migrationNote.isNotEmpty;

  String get displayCode => code.isEmpty ? provider.badgeLabel : code;

  String get officialStudyGuideUrl => studyGuideUrl.isNotEmpty ? studyGuideUrl : examGuideUrl ?? '';

  String get officialExamUrl => examUrl.isNotEmpty ? examUrl : officialUrl ?? '';

  String get blueprintLabel {
    if (blueprintDate.isNotEmpty) return blueprintDate;
    return <String>[
      if (blueprintVersion?.isNotEmpty ?? false) blueprintVersion!,
      if (blueprintPublishedOn?.isNotEmpty ?? false) blueprintPublishedOn!,
    ].join(' · ');
  }

  factory TrackSummary.fromJson(Map<String, dynamic> json) {
    final String legacyLevel = json['level'] as String? ?? '';
    final String normalizedLevel = json['certificationLevel'] as String? ?? legacyLevel;
    final String lifecycle = json['lifecycle'] as String? ?? '';
    final String rawStatus = json['status'] as String? ??
        (lifecycle == 'active' || lifecycle == 'retired' ? lifecycle : 'active');
    final bool learningAvailable =
        json['learningAvailable'] as bool? ?? json['contentStatus'] != 'planned';
    final String rawContentStatus =
        json['contentStatus'] as String? ?? (learningAvailable ? 'available' : 'planned');

    return TrackSummary(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: legacyLevel,
      summary: json['summary'] as String? ?? '',
      unitCount: (json['unitCount'] as num?)?.toInt() ?? 0,
      lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
      domains: (json['domains'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => CertificationDomain.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      prerequisites: json['prerequisites'] as String? ?? '',
      studyGuideUrl: json['studyGuideUrl'] as String? ?? '',
      examUrl: json['examUrl'] as String? ?? '',
      blueprintDate: json['blueprintDate'] as String? ?? '',
      lifecycle: lifecycle,
      lifecycleNote: json['lifecycleNote'] as String? ?? '',
      examDetailsNote: json['examDetailsNote'] as String? ?? '',
      learningAvailable: learningAvailable,
      replacementCode: json['replacementCode'] as String? ?? '',
      migrationNote: json['migrationNote'] as String? ?? '',
      provider: _providerFromJson(json),
      family: json['family'] as String? ?? 'other',
      certificationLevel: _levelFromWire(normalizedLevel),
      status: _enumFromWire<CertificationLifecycleStatus>(
        rawStatus,
        CertificationLifecycleStatus.values,
        'certification status',
      ),
      contentStatus: _enumFromWire<CertificationContentStatus>(
        rawContentStatus,
        CertificationContentStatus.values,
        'content status',
      ),
      officialUrl: json['officialUrl'] as String?,
      examGuideUrl: json['examGuideUrl'] as String?,
      catalogVersion: json['catalogVersion'] as String?,
      blueprintPublishedOn: json['blueprintPublishedOn'] as String?,
      blueprintVersion: json['blueprintVersion'] as String?,
      languages: (json['languages'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic language) => language as String)
          .toList(growable: false),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      aliases: (json['aliases'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic alias) => alias as String)
          .toList(growable: false),
      replacedBy: json['replacedBy'] as String?,
      retiresOn: json['retiresOn'] as String?,
      retiredOn: json['retiredOn'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'title': title,
        'level': level,
        'summary': summary,
        'unitCount': unitCount,
        'lessonCount': lessonCount,
        'domains': domains.map((CertificationDomain domain) => domain.toJson()).toList(),
        'prerequisites': prerequisites,
        'studyGuideUrl': studyGuideUrl,
        'examUrl': examUrl,
        'blueprintDate': blueprintDate,
        'lifecycle': lifecycle,
        'lifecycleNote': lifecycleNote,
        'examDetailsNote': examDetailsNote,
        'learningAvailable': hasLearningContent,
        'replacementCode': replacementCode,
        'migrationNote': migrationNote,
        'provider': provider.wireName,
        'family': family,
        'certificationLevel': normalizedLevel.wireName,
        'status': isRetired ? 'retired' : status.name,
        'contentStatus': hasLearningContent ? 'available' : 'planned',
        'officialUrl': officialUrl,
        'examGuideUrl': examGuideUrl,
        'catalogVersion': catalogVersion,
        'blueprintPublishedOn': blueprintPublishedOn,
        'blueprintVersion': blueprintVersion,
        'languages': languages,
        'durationMinutes': durationMinutes,
        'aliases': aliases,
        'replacedBy': replacedBy,
        'retiresOn': retiresOn,
        'retiredOn': retiredOn,
      };
}

class CertificationDomain {
  const CertificationDomain({
    required this.id,
    required this.name,
    required this.minWeightPct,
    required this.maxWeightPct,
  });

  final String id;
  final String name;
  final int minWeightPct;
  final int maxWeightPct;

  String get weightLabel =>
      minWeightPct == maxWeightPct ? '$minWeightPct%' : '$minWeightPct–$maxWeightPct%';

  factory CertificationDomain.fromJson(Map<String, dynamic> json) => CertificationDomain(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        minWeightPct: (json['minWeightPct'] as num?)?.toInt() ?? 0,
        maxWeightPct: (json['maxWeightPct'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'minWeightPct': minWeightPct,
        'maxWeightPct': maxWeightPct,
      };
}
