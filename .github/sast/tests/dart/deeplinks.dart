// Fixture for .github/sast/rules/dart-security.yaml — deep link / URL rules.

void deepLinks(BuildContext context, GoRouterState state, AppLinks appLinks, ApiClient api) async {
  // ruleid: dart-deeplink-untrusted-navigation
  context.go(state.uri.queryParameters['next']!);

  final String? from = state.uri.queryParameters['from'];
  // ruleid: dart-deeplink-untrusted-navigation
  context.push(from!);

  // ruleid: dart-deeplink-untrusted-navigation
  GoRouter.of(context).pushReplacement(state.pathParameters['target']!);

  // ok: dart-deeplink-untrusted-navigation
  context.go('/lesson/${Uri.encodeComponent(state.pathParameters['lessonId']!)}');

  // ok: dart-deeplink-untrusted-navigation
  context.go(Routes.home);

  // ruleid: dart-url-launch-dynamic
  launchUrl(Uri.parse(link));

  // ruleid: dart-url-launch-dynamic
  launchUrlString(link);

  // ok: dart-url-launch-dynamic
  launchUrl(Uri.parse('https://certigo.example/privacy'));

  // ok: dart-url-launch-dynamic
  launchUrl(Uri.https('certigo.example', '/privacy'));

  // ruleid: dart-deeplink-listener
  appLinks.uriLinkStream.listen((Uri uri) => handle(uri));

  // ruleid: dart-deeplink-listener
  final Uri? initial = await appLinks.getInitialLink();

  // ok: dart-deeplink-listener
  final Uri? unrelated = await cache.getInitialValue();

  // ruleid: dart-api-path-unencoded-interpolation
  api.postJson('/quiz/$lessonId/submit', body, SubmitQuizResult.fromJson);

  // ruleid: dart-api-path-unencoded-interpolation
  api.getJson('/lessons/${lesson.id}/content', Lesson.fromJson);

  // ruleid: dart-api-path-unencoded-interpolation
  dio.get<dynamic>('/raw/$trackId');

  // ruleid: dart-api-path-unencoded-interpolation
  api.getJson<Lesson>('/lessons/$lessonId', Lesson.fromJson);

  // ok: dart-api-path-unencoded-interpolation
  api.getJson<Lesson>('/lessons/${Uri.encodeComponent(lessonId)}', Lesson.fromJson);

  // ok: dart-api-path-unencoded-interpolation
  cache.get('lesson/$lessonId');

  // ok: dart-api-path-unencoded-interpolation
  api.postJson('/quiz/${Uri.encodeComponent(lessonId)}/submit', body, SubmitQuizResult.fromJson);

  // ok: dart-api-path-unencoded-interpolation
  api.getJson('/me/items?since=${since.toIso8601String()}', Items.fromJson);

  // ok: dart-api-path-unencoded-interpolation
  api.getBytesResponse('/$kActivePublicManifestRoute');

  // ok: dart-api-path-unencoded-interpolation
  api.getJson('/me/profile', Profile.fromJson);

  // ruleid: dart-api-path-unencoded-interpolation
  await engine.enqueue(kind: kQuizSubmitKind, endpoint: '/quiz/$lessonId/submit', payload: body);

  // ruleid: dart-api-path-unencoded-interpolation
  final SyncAction action = SyncAction(endpoint: '/friends/$friendId', payload: body);

  // ok: dart-api-path-unencoded-interpolation
  await engine.enqueue(kind: kQuizSubmitKind, endpoint: '/quiz/${Uri.encodeComponent(lessonId)}/submit');
}
