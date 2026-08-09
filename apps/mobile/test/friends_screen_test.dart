import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/friends/presentation/friends_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget test for [FriendsScreen].
///
/// The screen is presented above the app shell and reads the roster from
/// [friendListProvider]; here we override that provider with a deterministic
/// fake and host the screen under a one-route [GoRouter] so we can assert it
/// renders the header, the always-present "add a friend" card and an individual
/// friend row. The fake omits [Friend.avatarUrl] so no network image is
/// requested. We never call [WidgetTester.pumpAndSettle] — the aurora
/// background never settles.
void main() {
  FriendList fakeFriends() => FriendList(
    count: 1,
    friends: <Friend>[
      Friend(
        userId: 'u-alex',
        displayName: 'Alex Martin',
        handle: 'alex#1234',
        level: 7,
        streakDays: 12,
        xp: 3400,
        friendsSince: DateTime(2024, 1, 1),
      ),
    ],
  );

  Future<void> pumpFriends(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/friends',
      routes: <RouteBase>[
        GoRoute(
          path: '/friends',
          builder: (BuildContext context, GoRouterState state) => const FriendsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[friendListProvider.overrideWith((Ref ref) async => fakeFriends())],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header, the add-friend card and a friend row', (tester) async {
    await pumpFriends(tester);

    expect(find.text('Amis'), findsOneWidget);
    expect(find.text('Ajouter un ami'), findsOneWidget);
    expect(find.text('Alex Martin'), findsOneWidget);
  });
}
