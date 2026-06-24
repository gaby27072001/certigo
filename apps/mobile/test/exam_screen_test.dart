import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/exam/presentation/exam_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget test for [ExamScreen].
///
/// The screen is presented above the app shell and reads the mock exam from
/// [examProvider] (which resolves the active track internally — overriding the
/// exam provider short-circuits that). Here we override it with a deterministic
/// fake exam and host the screen under a one-route [GoRouter] so we can assert
/// it renders the header and the first question stem. We never call
/// [WidgetTester.pumpAndSettle] — the aurora background never settles.
void main() {
  MockExam fakeExam() => const MockExam(
        examId: 'exam-1',
        trackId: 'az-900',
        trackCode: 'AZ-900',
        trackTitle: 'Fondamentaux Azure',
        timeLimitSeconds: 3600,
        passingScore: 700,
        blueprint: <MockExamBlueprintDomain>[
          MockExamBlueprintDomain(
            domainId: 'd1',
            name: 'Concepts du cloud',
            weight: 0.3,
            itemCount: 1,
          ),
        ],
        items: <MockExamItem>[
          MockExamItem(
            itemId: 'i1',
            lessonId: 'l1',
            domainId: 'd1',
            type: ItemType.mcq,
            stem: 'Quel modèle de service fournit des machines virtuelles ?',
            options: <QuizOption>[
              QuizOption(id: 'a', label: 'IaaS'),
              QuizOption(id: 'b', label: 'SaaS'),
            ],
          ),
        ],
      );

  Future<void> pumpExam(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/exam',
      routes: <RouteBase>[
        GoRoute(
          path: '/exam',
          builder: (BuildContext context, GoRouterState state) =>
              const ExamScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          examProvider.overrideWith((Ref ref) async => fakeExam()),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header and the first question stem', (tester) async {
    await pumpExam(tester);

    expect(find.text('Examen blanc'), findsOneWidget);
    expect(
      find.text('Quel modèle de service fournit des machines virtuelles ?'),
      findsOneWidget,
    );
  });
}
