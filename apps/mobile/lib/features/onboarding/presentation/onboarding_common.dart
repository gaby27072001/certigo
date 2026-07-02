import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Route paths for the startup flow (splash → welcome → wizard → app), kept in
/// one place so the router, the redirect guard and the screens agree.
abstract class OnboardingRoutes {
  // NOTE: must NOT collide with the auth splash (`Routes.splash == '/splash'`).
  // A shared path made GoRouter resolve `/splash` to the auth splash (registered
  // first) and turned the post-login redirect into a no-op, trapping freshly
  // authenticated users on the spinner instead of entering onboarding.
  static const String splash = '/onboarding/splash';
  static const String welcome = '/welcome';
  static const String start = '/onboarding/start';
  static const String reasons = '/onboarding/reasons';
  static const String domains = '/onboarding/domains';
  static const String level = '/onboarding/level';
  static const String goal = '/onboarding/goal';
  static const String routine = '/onboarding/routine';
  static const String promise = '/onboarding/promise';
  static const String login = '/login';
  static const String birthYear = '/onboarding/birth-year';

  /// Every location that belongs to the startup flow (i.e. lives *outside* the
  /// app shell). Used by the router redirect to gate entry to the app.
  static const Set<String> all = <String>{
    splash,
    welcome,
    start,
    reasons,
    domains,
    level,
    goal,
    routine,
    promise,
    login,
    birthYear,
  };

  static bool isStartup(String location) =>
      all.contains(location) || location.startsWith('/onboarding');
}

/// A mascot paired with a tailed speech bubble — the recurring "the guide asks
/// you something" header at the top of each wizard step.
class MascotPrompt extends StatefulWidget {
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
  State<MascotPrompt> createState() => _MascotPromptState();
}

class _MascotPromptState extends State<MascotPrompt> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration d = reduceMotion ? Duration.zero : PrismMotion.base;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(-0.08, 0),
          duration: d,
          curve: PrismMotion.decelerate,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: d,
            curve: PrismMotion.decelerate,
            child: MascotAvatar(
              mascot: widget.mascot,
              mood: widget.mood,
              size: widget.size,
              showBadge: false,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0.08, 0),
              duration: d,
              curve: PrismMotion.decelerate,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: d,
                curve: PrismMotion.decelerate,
                child: SpeechBubble(
                  tail: SpeechTail.left,
                  tailAlignment: 0.32,
                  child: Text(
                    widget.message,
                    style: t.titleMedium?.copyWith(height: 1.3, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
