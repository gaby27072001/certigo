import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Route paths for the startup flow (splash → welcome → wizard → app), kept in
/// one place so the router, the redirect guard and the screens agree.
abstract class OnboardingRoutes {
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String start = '/onboarding/start';
  static const String reasons = '/onboarding/reasons';
  static const String goal = '/onboarding/goal';
  static const String routine = '/onboarding/routine';
  static const String promise = '/onboarding/promise';
  static const String login = '/login';

  /// Every location that belongs to the startup flow (i.e. lives *outside* the
  /// app shell). Used by the router redirect to gate entry to the app.
  static const Set<String> all = <String>{
    splash,
    welcome,
    start,
    reasons,
    goal,
    routine,
    promise,
    login,
  };

  static bool isStartup(String location) =>
      all.contains(location) || location.startsWith('/onboarding');
}

/// A mascot paired with a tailed speech bubble — the recurring "the guide asks
/// you something" header at the top of each wizard step.
class MascotPrompt extends StatelessWidget {
  const MascotPrompt({
    super.key,
    required this.message,
    this.mascot = AuroraMascot.nimbus,
    this.mood = MascotMood.happy,
    this.size = 72,
  });

  final String message;
  final AuroraMascot mascot;
  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MascotAvatar(mascot: mascot, mood: mood, size: size, showBadge: false),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SpeechBubble(
              tail: SpeechTail.left,
              tailAlignment: 0.32,
              child: Text(
                message,
                style: t.titleMedium?.copyWith(height: 1.3, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
