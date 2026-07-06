import 'package:flutter/widgets.dart';

/// Text that "types itself" character by character — the signature way a playful
/// learning guide asks a question, one glyph at a time.
///
/// Reveals [text] progressively with an [AnimationController], then calls
/// [onComplete]. Honours reduced-motion: when the platform disables animations
/// the full string is shown instantly (and [onComplete] fires next frame), so
/// the effect never blocks readers who opt out.
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.charDuration = const Duration(milliseconds: 26),
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Time spent revealing a single character.
  final Duration charDuration;

  /// Fired once the whole string is visible (instantly under reduced-motion).
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration(widget.text))
      ..addStatusListener(_onStatus);
  }

  Duration _totalDuration(String text) {
    final int chars = text.characters.length;
    if (chars == 0) return Duration.zero;
    return widget.charDuration * chars;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onComplete?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || widget.text.characters.isEmpty) {
      _controller.value = 1;
      // Notify completion for callers that gate a CTA on it.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete?.call());
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller
        ..duration = _totalDuration(widget.text)
        ..reset();
      final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion || widget.text.characters.isEmpty) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Characters chars = widget.text.characters;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final int count = (chars.length * _controller.value).round().clamp(0, chars.length);
        final String shown = chars.take(count).toString();
        // A hidden full-text layer reserves the final size so the bubble does
        // not jump line-count as characters appear (calmer, premium reveal).
        return Stack(
          children: <Widget>[
            Opacity(
              opacity: 0,
              child: Text(widget.text, style: widget.style, textAlign: widget.textAlign),
            ),
            Text(shown, style: widget.style, textAlign: widget.textAlign),
          ],
        );
      },
    );
  }
}
