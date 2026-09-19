import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'inline_error.dart';

/// Renders one *module* of a screen from one asynchronous source, so that the
/// source's failure degrades that module and leaves the rest of the screen
/// standing.
///
/// It separates the states the UX matrix asks us to distinguish, and they are
/// not the three branches of [AsyncValue.when]:
///
/// * **rien encore** — nothing has ever arrived: [loading], a skeleton that
///   holds the module's shape.
/// * **impossible de charger** — nothing has ever arrived *and* the source
///   failed: a module-scoped [PrismStatusView.error] carrying [onRetry].
/// * **déjà chargé** — a value arrived at least once: it stays on screen while
///   the source refreshes, and also *after a refresh fails*.
///
/// That last case is what [AsyncValue.when] gets wrong, and it is why this
/// widget exists. `when` chooses its branch on `hasError` without ever
/// consulting `hasValue`, so a refresh that fails replaces content the learner
/// is reading with a full-module error.
///
/// Measured on flutter_riverpod 2.5.1: a resolved provider that is invalidated
/// and then completes with an error paints `[DATA, ERROR]` — the data is gone,
/// even though the [AsyncValue] still carries it. A pull-to-refresh must never
/// be able to cost the learner what they already had, so a failed refresh is
/// reported *beside* the content as an [InlineError] instead of replacing it.
///
/// A successful refresh needs no special handling: `when` already defaults to
/// `skipLoadingOnRefresh: true`, and the same measurement shows the previous
/// value held across the reload. Only the failure path had to be fixed.
///
/// The widget fills its parent, so give it a bounded box — an [Expanded], or a
/// [SafeArea] body — rather than a slot inside an unbounded [ListView].
class AsyncModule<T> extends StatelessWidget {
  const AsyncModule({
    super.key,
    required this.state,
    required this.data,
    required this.loading,
    this.onRetry,
    this.errorMessage,
    this.staleMessage = defaultStaleMessage,
  });

  /// Shown beside content that is on screen but could not be refreshed.
  static const String defaultStaleMessage =
      'Mise à jour impossible. Voici les dernières données reçues.';

  /// The module's single source.
  final AsyncValue<T> state;

  /// Builds the module once a value exists — including while it is stale.
  final Widget Function(BuildContext context, T value) data;

  /// Builds the placeholder shown before any value has ever arrived.
  final WidgetBuilder loading;

  /// Retries [state]'s source. Only reachable from the cold-failure view.
  final VoidCallback? onRetry;

  /// Copy for the cold-failure view, scoped to what this module could not load.
  final String? errorMessage;

  /// Copy for the banner shown when a refresh failed over existing content.
  final String staleMessage;

  @override
  Widget build(BuildContext context) {
    if (state.hasValue) {
      final Widget content = data(context, state.requireValue);
      if (!state.hasError) {
        return content;
      }
      // Stale: the refresh failed, but the learner keeps what they had.
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.xs,
              PrismSpacing.gutter,
              0,
            ),
            child: InlineError(message: staleMessage),
          ),
          Expanded(child: content),
        ],
      );
    }
    if (state.hasError) {
      return ScrollableStatus(
        child: PrismStatusView.error(message: errorMessage, onRetry: onRetry),
      );
    }
    return loading(context);
  }
}

/// Lets a centered status view fill — and scroll within — its module, so a
/// [RefreshIndicator] above it still has a scrollable to drive.
///
/// Without this, pulling down works over a populated list and does nothing at
/// all over the empty or unreachable view of the same module, which are the two
/// moments a learner is most likely to pull.
class ScrollableStatus extends StatelessWidget {
  const ScrollableStatus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

/// Runs [refresh] and swallows its failure.
///
/// [RefreshIndicator.onRefresh] reports a thrown error as an unhandled
/// framework exception, and `ref.refresh(provider.future)` rethrows whatever
/// the provider threw. Swallowing it here loses nothing: the failure is already
/// carried by the provider's [AsyncValue], which is precisely what raises the
/// stale banner in [AsyncModule]. The future handed to the indicator only has
/// to say "finished" so the spinner can retract.
Future<void> refreshQuietly(Future<Object?> Function() refresh) async {
  try {
    await refresh();
  } catch (_) {
    // Surfaced by the provider's AsyncValue, not by the indicator.
    return;
  }
}
