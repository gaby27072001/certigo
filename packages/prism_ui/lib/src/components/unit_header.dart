import 'package:flutter/material.dart';

import '../tokens/prism_radii.dart';
import 'aurora_mascot.dart';

/// Colored banner that opens each unit on the skill-path — "UNITÉ {index}",
/// the unit title, its Azure domain, a guardian mascot seated on the right and
/// a thin progress bar. Mirrors Duolingo's per-unit headers, themed by domain
/// accent.
class UnitHeader extends StatelessWidget {
  const UnitHeader({
    super.key,
    required this.index,
    required this.title,
    required this.accent,
    this.domainName,
    this.mascot,
    this.completed = 0,
    this.total = 0,
    this.onInfo,
  });

  final int index;
  final String title;
  final Color accent;
  final String? domainName;
  final AuroraMascot? mascot;
  final int completed;
  final int total;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final Color accentDark = _shift(accent, -0.16);
    final double ratio = total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);

    return Semantics(
      header: true,
      label:
          'Unité $index, $title${domainName != null ? ', $domainName' : ''}, '
          '$completed sur $total leçons',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          borderRadius: PrismRadii.cardXl,
          gradient: LinearGradient(
            colors: <Color>[_shift(accent, 0.06), accentDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withOpacity(0.34),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'UNITÉ $index',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      if (onInfo != null) ...<Widget>[
                        const Spacer(),
                        GestureDetector(
                          onTap: onInfo,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (domainName != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      domainName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (total > 0) ...<Widget>[
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Stack(
                              children: <Widget>[
                                Container(height: 8, color: Colors.white.withOpacity(0.28)),
                                FractionallySizedBox(
                                  widthFactor: ratio == 0 ? 0.001 : ratio,
                                  child: Container(height: 8, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$completed/$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (mascot != null) ...<Widget>[
              const SizedBox(width: 12),
              MascotAvatar(mascot: mascot!, size: 58, mood: MascotMood.happy),
            ],
          ],
        ),
      ),
    );
  }

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}
