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

enum CertificationLifecycleStatus { announced, active, activeRetiring, retired, replaced }

extension CertificationLifecycleStatusInfo on CertificationLifecycleStatus {
  String get wireName => switch (this) {
        CertificationLifecycleStatus.activeRetiring => 'active-retiring',
        _ => name,
      };
}

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
  final String namespace = id.split(':').first;
  if (id.contains(':')) {
    return switch (namespace) {
      'aws' => CertificationProvider.aws,
      'gcp' => CertificationProvider.gcp,
      'github' => CertificationProvider.github,
      'microsoft' => CertificationProvider.microsoft,
      _ => throw FormatException('Unsupported certification namespace: $namespace'),
    };
  }
  if (id.startsWith('github') || id.startsWith('gh-') || code.startsWith('gh')) {
    return CertificationProvider.github;
  }
  return CertificationProvider.microsoft;
}

CertificationLifecycleStatus _lifecycleStatusFromWire(String raw) => switch (raw.toLowerCase()) {
      'announced' => CertificationLifecycleStatus.announced,
      'active' => CertificationLifecycleStatus.active,
      'active-retiring' => CertificationLifecycleStatus.activeRetiring,
      'retired' => CertificationLifecycleStatus.retired,
      'replaced' => CertificationLifecycleStatus.replaced,
      _ => throw FormatException('Unsupported certification status: $raw'),
    };

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
    this.officialCode,
    this.slug,
    this.officialSlug,
    this.guide,
    this.blueprint,
    this.lifecycleDetails,
    this.provenance,
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
  final String? officialCode;
  final String? slug;
  final String? officialSlug;
  final CertificationGuide? guide;
  final CertificationBlueprint? blueprint;
  final CertificationLifecycle? lifecycleDetails;
  final CertificationProvenance? provenance;

  CertificationLevel get normalizedLevel => certificationLevel == CertificationLevel.unspecified
      ? _levelFromWire(level)
      : certificationLevel;

  bool get isRetired =>
      status == CertificationLifecycleStatus.retired ||
      status == CertificationLifecycleStatus.replaced ||
      lifecycle == 'retired' ||
      lifecycle == 'replaced';

  bool get isActive =>
      status == CertificationLifecycleStatus.active ||
      status == CertificationLifecycleStatus.activeRetiring;

  bool get isDiscoverable => status == CertificationLifecycleStatus.announced || isActive;

  bool get hasLearningContent =>
      learningAvailable && contentStatus == CertificationContentStatus.available;

  bool get hasOfficialMetadata =>
      domains.isNotEmpty ||
      prerequisites.isNotEmpty ||
      officialStudyGuideUrl.isNotEmpty ||
      officialExamUrl.isNotEmpty ||
      blueprintLabel.isNotEmpty ||
      (blueprint?.objectives.isNotEmpty ?? false) ||
      lifecycleNote.isNotEmpty ||
      migrationNote.isNotEmpty;

  String get displayCode => code.isEmpty ? provider.badgeLabel : code;

  String get officialStudyGuideUrl => studyGuideUrl.isNotEmpty ? studyGuideUrl : examGuideUrl ?? '';

  String get officialExamUrl => examUrl.isNotEmpty ? examUrl : officialUrl ?? '';

  String get blueprintLabel {
    if (blueprintDate.isNotEmpty) return blueprintDate;
    return <String>[
      if (blueprint?.version.isNotEmpty ?? false) blueprint!.version,
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
      status: _lifecycleStatusFromWire(rawStatus),
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
      officialCode: json['officialCode'] as String?,
      slug: json['slug'] as String?,
      officialSlug: json['officialSlug'] as String?,
      guide: json['guide'] is Map<String, dynamic>
          ? CertificationGuide.fromJson(json['guide'] as Map<String, dynamic>)
          : null,
      blueprint: json['blueprint'] is Map<String, dynamic>
          ? CertificationBlueprint.fromJson(json['blueprint'] as Map<String, dynamic>)
          : null,
      lifecycleDetails: json['lifecycleDetails'] is Map<String, dynamic>
          ? CertificationLifecycle.fromJson(json['lifecycleDetails'] as Map<String, dynamic>)
          : null,
      provenance: json['provenance'] is Map<String, dynamic>
          ? CertificationProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
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
        'status': status.wireName,
        'contentStatus': contentStatus.name,
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
        'officialCode': officialCode,
        'slug': slug,
        'officialSlug': officialSlug,
        'guide': guide?.toJson(),
        'blueprint': blueprint?.toJson(),
        'lifecycleDetails': lifecycleDetails?.toJson(),
        'provenance': provenance?.toJson(),
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

class CertificationGuide {
  const CertificationGuide({
    required this.url,
    this.version,
    this.publishedOn,
    this.versionSource,
    this.revisionToken,
  });

  final String url;
  final String? version;
  final String? publishedOn;
  final String? versionSource;
  final String? revisionToken;

  factory CertificationGuide.fromJson(Map<String, dynamic> json) => CertificationGuide(
        url: json['url'] as String? ?? '',
        version: json['version'] as String?,
        publishedOn: json['publishedOn'] as String?,
        versionSource: json['versionSource'] as String?,
        revisionToken: json['revisionToken'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'version': version,
        'publishedOn': publishedOn,
        'versionSource': versionSource,
        'revisionToken': revisionToken,
      };
}

class CertificationBlueprint {
  const CertificationBlueprint({required this.version, required this.objectives});

  final String version;
  final List<CertificationObjective> objectives;

  factory CertificationBlueprint.fromJson(Map<String, dynamic> json) => CertificationBlueprint(
        version: json['version'] as String? ?? '',
        objectives: (json['objectives'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => CertificationObjective.fromJson(value as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'objectives': objectives
            .map((CertificationObjective objective) => objective.toJson())
            .toList(growable: false),
      };
}

class CertificationObjective {
  const CertificationObjective({
    required this.id,
    required this.title,
    required this.weightPercent,
    required this.weightType,
  });

  final String id;
  final String title;
  final double weightPercent;
  final String weightType;

  String get weightLabel {
    final String weight = weightPercent == weightPercent.roundToDouble()
        ? weightPercent.toInt().toString()
        : weightPercent.toString();
    return '${weightType == 'approximate' ? '~' : ''}$weight%';
  }

  factory CertificationObjective.fromJson(Map<String, dynamic> json) => CertificationObjective(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        weightPercent: (json['weightPercent'] as num?)?.toDouble() ?? 0,
        weightType: json['weightType'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'weightPercent': weightPercent,
        'weightType': weightType,
      };
}

class CertificationLifecycle {
  const CertificationLifecycle({
    this.reviewOn,
    this.lastExamOn,
    this.replaces = const <String>[],
    this.successor,
    this.note,
  });

  final String? reviewOn;
  final String? lastExamOn;
  final List<String> replaces;
  final String? successor;
  final String? note;

  factory CertificationLifecycle.fromJson(Map<String, dynamic> json) => CertificationLifecycle(
        reviewOn: json['reviewOn'] as String?,
        lastExamOn: json['lastExamOn'] as String?,
        replaces: (json['replaces'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => value as String)
            .toList(growable: false),
        successor: json['successor'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reviewOn': reviewOn,
        'lastExamOn': lastExamOn,
        'replaces': replaces,
        'successor': successor,
        'note': note,
      };
}

class CertificationProvenance {
  const CertificationProvenance({required this.checkedOn, required this.sources});

  final String checkedOn;
  final List<CertificationSource> sources;

  factory CertificationProvenance.fromJson(Map<String, dynamic> json) => CertificationProvenance(
        checkedOn: json['checkedOn'] as String? ?? '',
        sources: (json['sources'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => CertificationSource.fromJson(value as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'checkedOn': checkedOn,
        'sources':
            sources.map((CertificationSource source) => source.toJson()).toList(growable: false),
      };
}

class CertificationSource {
  const CertificationSource({required this.kind, required this.url});

  final String kind;
  final String url;

  factory CertificationSource.fromJson(Map<String, dynamic> json) =>
      CertificationSource(kind: json['kind'] as String? ?? '', url: json['url'] as String? ?? '');

  Map<String, dynamic> toJson() => <String, dynamic>{'kind': kind, 'url': url};
}
