import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Route paths for the startup flow (splash → welcome → wizard → app), kept in
/// one place so the router, the redirect guard and the screens agree.
///
/// The sequence mirrors a polished learning-app onboarding: brand splash, a
/// greeting from the guide, a handful of tailoring questions interleaved with
/// short mascot "reactions", a couple of value/permission moments and a closing
/// readiness reveal. Reaction/loading screens hide the progress bar; question
/// and intro screens fill it as the learner advances.
abstract class OnboardingRoutes {
  // NOTE: must NOT collide with the auth splash (`Routes.splash == '/splash'`).
  // A shared path made GoRouter resolve `/splash` to the auth splash (registered
  // first) and turned the post-login redirect into a no-op, trapping freshly
  // authenticated users on the spinner instead of entering onboarding.
  static const String splash = '/onboarding/splash';
  static const String welcome = '/welcome';
  static const String intro = '/onboarding/intro';
  static const String birthYear = '/onboarding/birth-year';
  static const String certification = '/onboarding/certification';
  static const String domains = '/onboarding/domains';
  static const String building = '/onboarding/building';
  static const String attribution = '/onboarding/attribution';
  static const String level = '/onboarding/level';
  static const String levelReaction = '/onboarding/level-reaction';
  static const String reasons = '/onboarding/reasons';
  static const String reasonsReaction = '/onboarding/reasons-reaction';
  static const String routineIntro = '/onboarding/routine-intro';
  static const String goal = '/onboarding/goal';
  static const String goalReaction = '/onboarding/goal-reaction';
  static const String notifications = '/onboarding/notifications';

  /// Every location that belongs to the startup flow (i.e. lives *outside* the
  /// app shell). Used by the router redirect to gate entry to the app.
  static const Set<String> all = <String>{splash, welcome, certification};

  static bool isStartup(String location) => all.contains(location);
}

/// A mascot paired with a tailed speech bubble — the recurring "the guide asks
/// you something" header at the top of each wizard step.
///
/// The question "writes itself" via [TypewriterText] (instant under
/// reduced-motion). Set [typewriter] to `false` for a static bubble.
class MascotPrompt extends StatefulWidget {
  const MascotPrompt({
    super.key,
    required this.message,
    this.mascot = AuroraMascot.nimbus,
    this.mood = MascotMood.happy,
    this.size = 72,
    this.typewriter = true,
  });

  final String message;
  final AuroraMascot mascot;
  final MascotMood mood;
  final double size;

  /// Whether the message types itself in (defaults to the Duo-style reveal).
  final bool typewriter;

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
    final TextStyle bubbleStyle =
        t.titleMedium?.copyWith(height: 1.3, fontWeight: FontWeight.w600) ??
            const TextStyle(fontWeight: FontWeight.w600);
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
                  child: widget.typewriter
                      ? TypewriterText(widget.message, style: bubbleStyle)
                      : Text(widget.message, style: bubbleStyle),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
