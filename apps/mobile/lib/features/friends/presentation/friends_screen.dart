import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Friends — add learners by handle, view their level/streak, and remove them.
/// The whole screen is stateful because it owns the add-friend text field; the
/// roster itself comes from `friendListProvider`. Mutations return a two-layer
/// result (transport + domain) and we invalidate the list on any success so the
/// roster and count reflect the server's truth.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _handleController = TextEditingController();
  bool _adding = false;
  String? _removingId;
  String? _error;

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String handle = _handleController.text.trim();
    if (handle.isEmpty) {
      setState(() => _error = 'Saisis un identifiant.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    final Result<FriendActionResult> result =
        await ref.read(friendRepositoryProvider).addFriend(AddFriendRequest(handle: handle));
    if (!mounted) {
      return;
    }
    result.when(
      success: (FriendActionResult r) {
        setState(() {
          _adding = false;
          _error = r.success ? null : (r.error ?? 'Cet identifiant est introuvable.');
          if (r.success) {
            _handleController.clear();
          }
        });
        if (r.success) {
          ref.invalidate(friendListProvider);
        }
      },
      failure: (Failure f) {
        setState(() {
          _adding = false;
          _error = f.message;
        });
      },
    );
  }

  Future<void> _remove(Friend friend) async {
    setState(() {
      _removingId = friend.userId;
      _error = null;
    });
    final Result<FriendActionResult> result =
        await ref.read(friendRepositoryProvider).removeFriend(friend.userId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (FriendActionResult r) {
        setState(() {
          _removingId = null;
          _error = r.success ? null : (r.error ?? 'Impossible de retirer cet ami.');
        });
        if (r.success) {
          ref.invalidate(friendListProvider);
        }
      },
      failure: (Failure f) {
        setState(() {
          _removingId = null;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FriendList> async = ref.watch(friendListProvider);

    return AuroraBackground(
      // The friends screen renders above the shell (no Scaffold), but its
      // "Ajouter un ami" TextField requires a Material ancestor. A transparent
      // Material supplies one without painting over the aurora backdrop.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const _ScreenHeader(title: 'Amis'),
              _AddFriendCard(
                controller: _handleController,
                adding: _adding,
                onSubmit: _add,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _InlineError(message: _error!),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  data: (FriendList list) => _FriendRoster(
                    list: list,
                    removingId: _removingId,
                    onRemove: _removingId == null ? _remove : null,
                  ),
                  loading: () => const _FriendsLoading(),
                  error: (Object error, StackTrace _) => PrismStatusView.error(
                    onRetry: () => ref.invalidate(friendListProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFriendCard extends StatelessWidget {
  const _AddFriendCard({
    required this.controller,
    required this.adding,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool adding;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: PrismCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ajouter un ami', style: t.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: !adding,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!adding) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                hintText: 'identifiant (ex. alex#1234)',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                filled: true,
                fillColor: p.surfaceAlt,
                border: const OutlineInputBorder(
                  borderRadius: PrismRadii.cardMd,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Ajouter',
              icon: Icons.person_add_alt_1_rounded,
              loading: adding,
              expand: true,
              onPressed: adding ? null : () => onSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRoster extends StatelessWidget {
  const _FriendRoster({
    required this.list,
    required this.removingId,
    required this.onRemove,
  });

  final FriendList list;
  final String? removingId;
  final Future<void> Function(Friend friend)? onRemove;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    if (list.friends.isEmpty) {
      return const PrismStatusView(
        icon: Icons.group_outlined,
        title: 'Aucun ami pour l\'instant',
        message: 'Ajoute un ami avec son identifiant pour vous motiver mutuellement.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            '${list.count} ami${list.count > 1 ? 's' : ''}',
            style: t.labelLarge?.copyWith(color: p.textSecondary),
          ),
        ),
        for (final Friend friend in list.friends) ...<Widget>[
          _FriendCard(
            friend: friend,
            removing: removingId == friend.userId,
            onRemove: onRemove == null ? null : () => onRemove!(friend),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.removing,
    required this.onRemove,
  });

  final Friend friend;
  final bool removing;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool hasAvatar = friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty;

    return PrismCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: p.primary.withOpacity(0.16),
            backgroundImage: hasAvatar ? NetworkImage(friend.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : Text(
                    _initials(friend.displayName),
                    style: t.titleMedium?.copyWith(
                      color: p.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  friend.displayName,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  '@${friend.handle}',
                  style: t.bodySmall?.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _Stat(icon: Icons.military_tech_rounded, label: 'Niv. ${friend.level}', color: p.primary),
                    const SizedBox(width: 10),
                    _Stat(
                      icon: Icons.local_fire_department_rounded,
                      label: '${friend.streakDays} j',
                      color: p.ember,
                    ),
                    const SizedBox(width: 10),
                    _Stat(icon: Icons.bolt_rounded, label: '${friend.xp} XP', color: p.xpGold),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (removing)
            const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.person_remove_rounded, color: p.textSecondary),
              tooltip: 'Retirer',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FriendsLoading extends StatelessWidget {
  const _FriendsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: const <Widget>[
        PrismSkeleton(height: 74),
        SizedBox(height: 10),
        PrismSkeleton(height: 74),
        SizedBox(height: 10),
        PrismSkeleton(height: 74),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.error.withOpacity(0.12),
        borderRadius: PrismRadii.cardMd,
        border: Border.all(color: p.error.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: p.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: t.bodySmall?.copyWith(color: p.error)),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.home);
              }
            },
          ),
          const SizedBox(width: 4),
          Text(title, style: t.headlineSmall),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
