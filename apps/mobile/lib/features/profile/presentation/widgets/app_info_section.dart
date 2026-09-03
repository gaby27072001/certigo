import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../../app/capabilities/release_profile_provider.dart';
import '../../../../app/capabilities/release_strings.dart';

class AppInfoSection extends ConsumerWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool isPrivateAlpha = ref.watch(
      releaseProfileProvider.select((ReleaseProfile profile) => profile.isPrivateAlpha),
    );
    final ReleaseStrings releaseStrings = ReleaseStrings.of(context);
    return PrismCard(
      child: Column(
        children: <Widget>[
          if (isPrivateAlpha) ...<Widget>[
            Semantics(
              label: releaseStrings.privateAlpha,
              child: Row(
                key: const Key('private-alpha-indicator'),
                children: <Widget>[
                  Icon(Icons.science_outlined, color: p.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      releaseStrings.privateAlpha,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    releaseStrings.privateAlphaLimit,
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(color: p.border, height: 24),
          ],
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, color: p.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Version de l\'app', style: t.bodyLarge)),
              Text('0.1.0 (build 1)', style: t.labelMedium?.copyWith(color: p.textSecondary)),
            ],
          ),
          Divider(color: p.border, height: 24),
          InkWell(
            onTap: () => showLicensePage(context: context, applicationName: 'Certigo'),
            borderRadius: BorderRadius.circular(PrismRadii.sm),
            child: Row(
              children: <Widget>[
                Icon(Icons.description_outlined, color: p.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Licences', style: t.bodyLarge)),
                Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
