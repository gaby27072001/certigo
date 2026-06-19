import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A "Key takeaway" / recap block — the single sentence the learner must retain.
///
/// A gold accent bar on the leading edge ties it to the XP / reward language of
/// the product, signalling "this is the thing worth remembering".
class KeyTakeawayBlock extends StatelessWidget {
  const KeyTakeawayBlock({
    super.key,
    required this.body,
    this.title = 'À retenir',
  });

  final String body;
  final String title;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: p.xpGold.withOpacity(0.08),
        borderRadius: PrismRadii.cardMd,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: p.xpGold,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.star_rounded, color: p.xpGold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: t.labelLarge?.copyWith(
                            color: p.xpGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(body, style: t.bodyLarge?.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
