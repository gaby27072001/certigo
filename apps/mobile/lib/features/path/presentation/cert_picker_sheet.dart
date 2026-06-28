import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';

/// Opens the Duolingo-style course picker: the learner browses the
/// certifications the app offers and taps one to switch the Path screen to it.
Future<void> showCertPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) => const CertPickerSheet(),
  );
}

/// French labels for the authoring levels. Certification titles themselves stay
/// in the vendor's official English wording (e.g. "Azure Fundamentals").
const Map<String, String> _levelLabels = <String, String>{
  'fundamentals': 'Fondamentaux',
  'associate': 'Associé',
  'professional': 'Professionnel',
  'specialty': 'Spécialité',
  'expert': 'Expert',
  'master': 'Master',
};

/// Display names for each certification vendor (used as section headers/chips).
const Map<String, String> _providerLabels = <String, String>{
  'microsoft': 'Microsoft',
  'aws': 'AWS',
  'google': 'Google',
  'oracle': 'Oracle',
  'anthropic': 'Anthropic',
  'openai': 'OpenAI',
};

/// Stable display order for provider sections and filter chips.
const List<String> _providerOrder = <String>[
  'microsoft',
  'aws',
  'google',
  'oracle',
  'anthropic',
  'openai',
];

/// Brand-ish accent color per vendor, picked for distinct hues that read well
/// in both light and dark mode.
const Map<String, Color> _providerColors = <String, Color>{
  'microsoft': Color(0xFF0078D4),
  'aws': Color(0xFFFF9900),
  'google': Color(0xFF34A853),
  'oracle': Color(0xFFC74634),
  'anthropic': Color(0xFFCC785C),
  'openai': Color(0xFF10A37F),
};

Color _providerColor(String provider) =>
    _providerColors[provider] ?? const Color(0xFF7C8AA0);

String _providerLabel(String provider) =>
    _providerLabels[provider] ?? (provider.isEmpty ? 'Autre' : provider);

/// Bottom sheet listing every certification track, grouped by vendor, with a
/// search field and per-provider filter chips. Reads the catalog lazily (only
/// while open) and the active track from [activeTrackProvider]; selecting a
/// track updates that provider and closes.
class CertPickerSheet extends ConsumerStatefulWidget {
  const CertPickerSheet({super.key});

  @override
  ConsumerState<CertPickerSheet> createState() => _CertPickerSheetState();
}

class _CertPickerSheetState extends ConsumerState<CertPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _providerFilter; // null => all providers.

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<List<TrackSummary>> catalog = ref.watch(catalogProvider);
    final String activeId = ref.watch(activeTrackProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: p.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Grip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Mes certifications',
                            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Choisis le parcours à suivre',
                            style: text.labelMedium?.copyWith(color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: p.textSecondary),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              catalog.maybeWhen(
                data: (List<TrackSummary> tracks) => _SearchBar(
                  controller: _searchController,
                  onChanged: (String value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              catalog.maybeWhen(
                data: (List<TrackSummary> tracks) => _ProviderFilterBar(
                  providers: _providersIn(tracks),
                  selected: _providerFilter,
                  onSelect: (String? provider) =>
                      setState(() => _providerFilter = provider),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              Flexible(
                child: catalog.when(
                  data: (List<TrackSummary> tracks) => _CertList(
                    groups: _grouped(tracks),
                    activeId: activeId,
                    onSelect: (String id) {
                      ref.read(activeTrackProvider.notifier).state = id;
                      Navigator.of(context).maybePop();
                    },
                  ),
                  loading: () => const _CertLoading(),
                  error: (Object _, StackTrace __) => _CertError(
                    onRetry: () => ref.invalidate(catalogProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Distinct providers present in the catalog, in canonical display order.
  List<String> _providersIn(List<TrackSummary> tracks) {
    final Set<String> present = tracks.map((TrackSummary t) => t.provider).toSet();
    final List<String> ordered =
        _providerOrder.where(present.contains).toList(growable: true);
    // Append any unexpected providers so nothing is hidden.
    for (final String provider in present) {
      if (!ordered.contains(provider)) ordered.add(provider);
    }
    return ordered;
  }

  /// Filters tracks by the search query and active provider chip, then groups
  /// them by provider in canonical order.
  List<_ProviderGroup> _grouped(List<TrackSummary> tracks) {
    final String q = _query.trim().toLowerCase();
    final Iterable<TrackSummary> filtered = tracks.where((TrackSummary t) {
      if (_providerFilter != null && t.provider != _providerFilter) return false;
      if (q.isEmpty) return true;
      return t.code.toLowerCase().contains(q) ||
          t.title.toLowerCase().contains(q);
    });

    final Map<String, List<TrackSummary>> byProvider =
        <String, List<TrackSummary>>{};
    for (final TrackSummary t in filtered) {
      byProvider.putIfAbsent(t.provider, () => <TrackSummary>[]).add(t);
    }

    final List<String> order = <String>[
      ..._providerOrder.where(byProvider.containsKey),
      ...byProvider.keys.where((String k) => !_providerOrder.contains(k)),
    ];

    return <_ProviderGroup>[
      for (final String provider in order)
        _ProviderGroup(provider: provider, tracks: byProvider[provider]!),
    ];
  }
}

/// One vendor's tracks, ready to render as a titled section.
class _ProviderGroup {
  const _ProviderGroup({required this.provider, required this.tracks});

  final String provider;
  final List<TrackSummary> tracks;
}

/// Search field filtering on exam code or title.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: p.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher (code ou titre)…',
          hintStyle: TextStyle(color: p.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: p.textSecondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  tooltip: 'Effacer',
                ),
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of provider filter chips ("Tous" + one per vendor present).
class _ProviderFilterBar extends StatelessWidget {
  const _ProviderFilterBar({
    required this.providers,
    required this.selected,
    required this.onSelect,
  });

  final List<String> providers;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (providers.length < 2) return const SizedBox(height: 4);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          _FilterChip(
            label: 'Tous',
            color: context.prism.primary,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final String provider in providers) ...<Widget>[
            _FilterChip(
              label: _providerLabel(provider),
              color: _providerColor(provider),
              selected: selected == provider,
              onTap: () => onSelect(provider),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: PrismRadii.pillAll,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.16) : p.surface,
            borderRadius: PrismRadii.pillAll,
            border: Border.all(
              color: selected ? color : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : p.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CertList extends StatelessWidget {
  const _CertList({
    required this.groups,
    required this.activeId,
    required this.onSelect,
  });

  final List<_ProviderGroup> groups;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      final PrismColorScheme p = context.prism;
      final TextTheme text = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        child: Text(
          'Aucune certification ne correspond à ta recherche.',
          style: text.bodyMedium?.copyWith(color: p.textSecondary),
        ),
      );
    }

    final List<Widget> children = <Widget>[];
    for (final _ProviderGroup group in groups) {
      final Color accent = _providerColor(group.provider);
      children.add(_SectionHeader(
        label: _providerLabel(group.provider),
        count: group.tracks.length,
        accent: accent,
      ));
      for (final TrackSummary track in group.tracks) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CertCard(
            track: track,
            accent: accent,
            selected: track.id == activeId,
            onTap: () => onSelect(track.id),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }
}

/// Sticky-looking vendor section title with a colored dot and a track count.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.accent,
  });

  final String label;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: PrismRadii.pillAll,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Divider(color: p.border, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// One Duolingo-style course card: a colored emblem with the exam code, the
/// official title, a level chip and lesson/chapter counts, plus a selected mark.
class _CertCard extends StatelessWidget {
  const _CertCard({
    required this.track,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TrackSummary track;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final String level = _levelLabels[track.level] ?? track.level;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.10) : p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              _Emblem(code: track.code, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      track.title,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        track.summary,
                        style: text.bodySmall?.copyWith(color: p.textSecondary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: <Widget>[
                        if (level.isNotEmpty) ...<Widget>[
                          _MetaChip(label: level, color: accent),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.menu_book_rounded, size: 14, color: p.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${track.lessonCount} leçons · ${track.unitCount} chapitres',
                            style: text.labelSmall?.copyWith(color: p.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? accent : p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.code, required this.accent});

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent, accent.withOpacity(0.74)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: PrismRadii.pillAll,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      decoration: BoxDecoration(
        color: p.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _CertLoading extends StatelessWidget {
  const _CertLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        PrismSkeleton(height: 88),
        SizedBox(height: 12),
        PrismSkeleton(height: 88),
        SizedBox(height: 12),
        PrismSkeleton(height: 88),
      ],
    );
  }
}

class _CertError extends StatelessWidget {
  const _CertError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        const CalloutBlock(
          kind: CalloutKind.warning,
          title: 'Catalogue indisponible',
          text: 'Impossible de charger les certifications. Réessaie dans un instant.',
        ),
        const SizedBox(height: 18),
        PrismButton.secondary(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
