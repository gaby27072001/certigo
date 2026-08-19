import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../app/router.dart';

/// Back-bar header shared by above-shell feature screens
/// (achievements, friends, shop, quests, seasons).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.sm,
        PrismSpacing.xs,
        PrismSpacing.sm,
        PrismSpacing.xs,
      ),
      child: GlassSurface(
        elevation: 0,
        borderRadius: PrismRadii.pillAll,
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xs),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.home);
                }
              },
            ),
            const SizedBox(width: PrismSpacing.xxs),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
