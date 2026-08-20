import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';

/// Redirects a restored session to its durable deletion workflow before the
/// learner can continue using the shell. The backend independently blocks every
/// non-deletion API, so this widget is UX recovery rather than a security boundary.
class AccountDeletionResumeScope extends ConsumerStatefulWidget {
  const AccountDeletionResumeScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountDeletionResumeScope> createState() => _AccountDeletionResumeScopeState();
}

class _AccountDeletionResumeScopeState extends ConsumerState<AccountDeletionResumeScope> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeIfNeeded());
  }

  Future<void> _resumeIfNeeded() async {
    if (_checked) return;
    _checked = true;
    final Result<AccountDeletion> result =
        await ref.read(accountDeletionRepositoryProvider).getStatus();
    result.when(
      success: (AccountDeletion deletion) {
        if (mounted && deletion.status != AccountDeletionPhase.notRequested) {
          context.go(Routes.accountDeletion);
        }
      },
      failure: (Failure failure) {
        // A transient status lookup must not claim deletion. Normal API calls
        // remain protected by the server's 423 guard if a request already exists.
        debugPrint('[account-deletion] recovery status failed: ${failure.code}');
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
