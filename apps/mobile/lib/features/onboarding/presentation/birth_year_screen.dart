import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/birth_year_provider.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Final onboarding step — collects the learner's year of birth.
///
/// Validates that the user is at least 13 years old (EU/COPPA requirement),
/// stores the year in [SharedPreferences] via [birthYearProvider], then marks
/// onboarding complete and enters the app.
class BirthYearScreen extends ConsumerStatefulWidget {
  const BirthYearScreen({super.key});

  @override
  ConsumerState<BirthYearScreen> createState() => _BirthYearScreenState();
}

class _BirthYearScreenState extends ConsumerState<BirthYearScreen> {
  static final int _currentYear = DateTime.now().year;

  /// Oldest year shown in the picker.
  static const int _minYear = 1910;

  /// Newest selectable year: user must be at least 13.
  static final int _maxYear = _currentYear - 13;

  static final int _yearCount = _maxYear - _minYear + 1;

  late int _selectedYear;
  late final FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Default selection: a plausible 20-year-old learner.
    _selectedYear = (_currentYear - 20).clamp(_minYear, _maxYear);
    _scrollController =
        FixedExtentScrollController(initialItem: _selectedYear - _minYear);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    await ref.read(birthYearProvider.notifier).save(_selectedYear);
    if (!mounted) return;
    ref.read(onboardingControllerProvider).complete();
    context.go('/path');
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: 1,
      onBack: () => context.go(OnboardingRoutes.promise),
      primaryLabel: 'C\'EST PARTI',
      onPrimary: _confirm,
      scrollable: false,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          const MascotPrompt(message: 'En quelle année es-tu né(e) ?'),
          const SizedBox(height: 8),
          Text(
            'Tu dois avoir au moins 13 ans pour utiliser Certigo.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _YearWheel(
              scrollController: _scrollController,
              minYear: _minYear,
              yearCount: _yearCount,
              selectedYear: _selectedYear,
              onYearChanged: (int year) => setState(() => _selectedYear = year),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _YearWheel extends StatelessWidget {
  const _YearWheel({
    required this.scrollController,
    required this.minYear,
    required this.yearCount,
    required this.selectedYear,
    required this.onYearChanged,
  });

  final FixedExtentScrollController scrollController;
  final int minYear;
  final int yearCount;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Selection highlight sits behind the list items.
        Align(
          child: Container(
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: p.primary.withOpacity(0.10),
              borderRadius: PrismRadii.cardMd,
              border: Border.all(
                color: p.primary.withOpacity(0.30),
                width: 1.5,
              ),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: scrollController,
          itemExtent: 54,
          perspective: 0.003,
          diameterRatio: 2.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (int index) => onYearChanged(minYear + index),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: yearCount,
            builder: (BuildContext ctx, int index) {
              if (index < 0 || index >= yearCount) return null;
              final int year = minYear + index;
              final bool selected = year == selectedYear;
              return Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 120),
                  style: selected
                      ? (t.headlineMedium ?? const TextStyle()).copyWith(
                          color: p.primary,
                          fontWeight: FontWeight.w800,
                        )
                      : (t.titleMedium ?? const TextStyle()).copyWith(
                          color: p.textSecondary.withOpacity(0.55),
                          fontWeight: FontWeight.w400,
                        ),
                  child: Text('$year'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
