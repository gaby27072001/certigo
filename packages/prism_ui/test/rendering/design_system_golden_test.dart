import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  setUpAll(() => debugDisableShadows = true);
  tearDownAll(() => debugDisableShadows = false);

  Future<void> pumpShowcase(
    WidgetTester tester, {
    required Size size,
    required Brightness brightness,
    required String golden,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ThemeData theme = brightness == Brightness.dark ? PrismTheme.dark() : PrismTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const _DesignSystemShowcase(),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey<String>('design-system-showcase')),
      matchesGoldenFile('goldens/$golden.png'),
    );
  }

  testWidgets('compact light showcase', (WidgetTester tester) async {
    await pumpShowcase(
      tester,
      size: const Size(390, 844),
      brightness: Brightness.light,
      golden: 'design_compact_light',
    );
  });

  testWidgets('compact dark showcase', (WidgetTester tester) async {
    await pumpShowcase(
      tester,
      size: const Size(390, 844),
      brightness: Brightness.dark,
      golden: 'design_compact_dark',
    );
  });

  testWidgets('wide light showcase', (WidgetTester tester) async {
    await pumpShowcase(
      tester,
      size: const Size(1024, 768),
      brightness: Brightness.light,
      golden: 'design_wide_light',
    );
  });
}

class _DesignSystemShowcase extends StatelessWidget {
  const _DesignSystemShowcase();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return RepaintBoundary(
      key: const ValueKey<String>('design-system-showcase'),
      child: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: PrismSpacing.screen,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: PrismSectionHeader(
                      title: 'Bonjour, Alex',
                      subtitle: 'Prêt pour une session calme et ciblée ?',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  const SizedBox(width: PrismSpacing.sm),
                  XpChip(xp: 2480),
                ],
              ),
              const SizedBox(height: PrismSpacing.lg),
              PrismCard(
                variant: PrismCardVariant.tonal,
                accent: p.primary,
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Préparation AZ-900', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: PrismSpacing.xs),
                    Text(
                      'Tu progresses régulièrement. Renforce les services cœur aujourd’hui.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: PrismSpacing.md),
                    const PrismProgressBar(value: 0.72, semanticLabel: 'Préparation AZ-900'),
                  ],
                ),
              ),
              const SizedBox(height: PrismSpacing.lg),
              const PrismSectionHeader(
                title: 'Question rapide',
                subtitle: 'Une seule réponse est correcte',
                icon: Icons.quiz_rounded,
                compact: true,
              ),
              const SizedBox(height: PrismSpacing.sm),
              const QuizOptionTile(
                leading: 'A',
                label: 'Azure Resource Manager',
                state: QuizOptionState.selected,
              ),
              const SizedBox(height: PrismSpacing.sm),
              const QuizOptionTile(
                leading: 'B',
                label: 'Azure DevOps',
                state: QuizOptionState.idle,
              ),
              const SizedBox(height: PrismSpacing.lg),
              PrismButton(label: 'Continuer', icon: Icons.arrow_forward_rounded, onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
