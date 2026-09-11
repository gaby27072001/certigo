import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../../shared/widgets/app_text_field.dart';

/// Prism-native replacements for the stock Material dialogs the Profile used
/// for every one of its pickers.
///
/// The Profile carried the app's densest cluster of raw Material: five
/// `AlertDialog`s built from `RadioListTile`, `CheckboxListTile`, `ListTile`
/// and bare `TextButton` actions. A stock component dropped into a bespoke
/// system is one of the most reliable ways to make an app feel unfinished, and
/// on iOS — where the owner tests — a Material dialog is doubly foreign.
///
/// These sheets do not invent a selection language. They use [ChoiceTile], the
/// component whose selected state is already correct everywhere else in the
/// app, and [PrismButton] for the commit action.

/// The shared chrome: a rounded Prism surface with a grab handle, a title, the
/// caller's content, and a commit action. Presented as a bottom sheet rather
/// than a centred dialog — it is reachable with a thumb and it is what both
/// platforms now use for this kind of choice.
Future<T?> _showSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, StateSetter setSheetState) content,
  required T? Function() onConfirm,
  bool Function()? canConfirm,
}) {
  final PrismColorScheme p = context.prism;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setSheetState) {
        final TextTheme t = Theme.of(ctx).textTheme;
        return Padding(
          // Lifts the sheet above the keyboard when the content is a field.
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadii.xxl)),
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.gutter,
                  PrismSpacing.sm,
                  PrismSpacing.gutter,
                  PrismSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: PrismRadii.pillAll,
                        ),
                      ),
                    ),
                    const SizedBox(height: PrismSpacing.md),
                    Text(title, style: t.titleLarge),
                    const SizedBox(height: PrismSpacing.md),
                    // Caps the sheet so it reads as a sheet rather than a
                    // takeover, and fades its last row instead of letting the
                    // commit button slice it flat — the same edge treatment
                    // the certification list uses.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.52,
                        ),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
                            stops: <double>[0, 0.93, 1],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: PrismSpacing.xs),
                            child: content(ctx, setSheetState),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: PrismSpacing.lg),
                    PrismButton(
                      label: ProfileSheetLabels.save,
                      onPressed: (canConfirm?.call() ?? true)
                          ? () => Navigator.of(ctx).pop(onConfirm())
                          : null,
                    ),
                    const SizedBox(height: PrismSpacing.xs),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(ProfileSheetLabels.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Copy asserted by tests. Named so a wording change cannot silently turn a
/// widget test red from an unrelated branch.
abstract final class ProfileSheetLabels {
  static const String save = 'Enregistrer';
  static const String cancel = 'Annuler';
  static const String handleRule = 'Minuscules, chiffres et _ uniquement';
}

/// One option in a [showProfileChoiceSheet] / [showProfileMultiChoiceSheet].
class ProfileOption<T> {
  const ProfileOption({required this.value, required this.label, this.trailing, this.leading});

  final T value;
  final String label;

  /// Optional right-aligned secondary label, e.g. "10 min / j".
  final String? trailing;
  final Widget? leading;
}

/// Pick exactly one value. Replaces an `AlertDialog` of `RadioListTile`s.
Future<T?> showProfileChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<ProfileOption<T>> options,
  required T selected,
}) {
  T current = selected;
  return _showSheet<T>(
    context: context,
    title: title,
    onConfirm: () => current,
    content: (BuildContext ctx, StateSetter setSheetState) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ProfileOption<T> option in options) ...<Widget>[
          ChoiceTile(
            title: option.label,
            leading: option.leading,
            trailingLabel: option.trailing,
            selected: option.value == current,
            showCheckbox: false,
            onTap: () => setSheetState(() => current = option.value),
          ),
          const SizedBox(height: PrismSpacing.xs),
        ],
      ],
    ),
  );
}

/// Pick any number of values. Replaces an `AlertDialog` of `CheckboxListTile`s.
Future<Set<T>?> showProfileMultiChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<ProfileOption<T>> options,
  required Set<T> selected,
}) {
  Set<T> current = Set<T>.from(selected);
  return _showSheet<Set<T>>(
    context: context,
    title: title,
    onConfirm: () => current,
    content: (BuildContext ctx, StateSetter setSheetState) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ProfileOption<T> option in options) ...<Widget>[
          ChoiceTile(
            title: option.label,
            leading: option.leading,
            selected: current.contains(option.value),
            onTap: () => setSheetState(() {
              current = current.contains(option.value)
                  ? (current.where((T x) => x != option.value).toSet())
                  : <T>{...current, option.value};
            }),
          ),
          const SizedBox(height: PrismSpacing.xs),
        ],
      ],
    ),
  );
}

/// Edit a single line of text. Replaces an `AlertDialog` wrapping a bare
/// `TextField` with a floating Material label.
///
/// [validate] returns an error message, or null when the value is acceptable;
/// the commit action stays disabled while it returns non-null.
Future<String?> showProfileTextSheet({
  required BuildContext context,
  required String title,
  required String hint,
  required String initial,
  String? Function(String value)? validate,
}) {
  String value = initial;
  String? error = validate?.call(initial);
  return _showSheet<String>(
    context: context,
    title: title,
    canConfirm: () => error == null,
    onConfirm: () => value,
    content: (BuildContext ctx, StateSetter setSheetState) {
      final PrismColorScheme p = ctx.prism;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SheetField(
            initial: initial,
            hint: hint,
            onChanged: (String v) => setSheetState(() {
              value = v;
              error = validate?.call(v);
            }),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: PrismSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: p.error),
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Owns its [TextEditingController] so the controller's lifetime is tied to the
/// field's element rather than to the sheet's future.
///
/// Disposing it on the future's completion instead looked equivalent and was
/// not: the route keeps rebuilding through its exit animation, and the field
/// then rebuilt against a disposed controller.
class _SheetField extends StatefulWidget {
  const _SheetField({required this.initial, required this.hint, required this.onChanged});

  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends State<_SheetField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      hint: widget.hint,
      autofocus: true,
      autocorrect: false,
      onChanged: widget.onChanged,
    );
  }
}
