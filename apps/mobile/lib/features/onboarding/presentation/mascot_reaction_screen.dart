import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// A between-questions "reaction" interstitial — a bigger [MascotHero] Nimbus
/// with a celebratory speech bubble and a sticky **CONTINUER** CTA, the beat
/// the guide takes to react to what you just answered ("On part de ce que tu
/// sais !", "Excellent choix !").
///
/// By design the learner **taps to continue**. An optional short [autoAdvance]
/// can nudge the flow forward, but it is disabled under reduced-motion so a
/// reader who opts out always keeps control.
class MascotReactionScreen extends StatefulWidget {
  const MascotReactionScreen({
    super.key,
    required this.message,
    required this.onPrimary,
    this.onBack,
    this.primaryLabel = 'CONTINUER',
    this.mood = MascotMood.celebrate,
    this.mascot = AuroraMascot.nimbus,
    this.highlight,
    this.progress,
    this.autoAdvance = false,
    this.autoAdvanceDelay = const Duration(milliseconds: 1200),
  });

  final String message;
  final VoidCallback onPrimary;
  final VoidCallback? onBack;
  final String primaryLabel;
  final MascotMood mood;
  final AuroraMascot mascot;

  /// Optional widget shown between the bubble and the CTA (e.g. a metric badge).
  final Widget? highlight;

  /// 0..1 progress; `null` hides the bar for a full-bleed celebration.
  final double? progress;

  /// Whether to auto-advance after [autoAdvanceDelay] (ignored under
  /// reduced-motion, where a tap is always required).
  final bool autoAdvance;
  final Duration autoAdvanceDelay;

  @override
  State<MascotReactionScreen> createState() => _MascotReactionScreenState();
}

class _MascotReactionScreenState extends State<MascotReactionScreen> {
  Timer? _timer;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || !widget.autoAdvance) return;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return;
    _scheduled = true;
    _timer = Timer(widget.autoAdvanceDelay, () {
      if (mounted) widget.onPrimary();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: widget.progress,
      onBack: widget.onBack,
      primaryLabel: widget.primaryLabel,
      onPrimary: widget.onPrimary,
      scrollable: false,
      child: Column(
        children: <Widget>[
          const Spacer(flex: 2),
          MascotHero(mascot: widget.mascot, mood: widget.mood, size: 150),
          const SizedBox(height: 22),
          SpeechBubble(
            tail: SpeechTail.up,
            maxWidth: 320,
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
          if (widget.highlight != null) ...<Widget>[
            const SizedBox(height: 28),
            widget.highlight!,
          ],
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
