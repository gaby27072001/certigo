import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_spacing.dart';
import 'prism_card.dart';
import 'vendor_brand.dart';

/// A large, pressable catalogue tile for one software [VendorBrand] — the top
/// level of the Duolingo-style content shelf (vendor → certification → chapter).
///
/// Catalogued providers show a live certification count and route into their
/// catalogue; showcase providers are [locked] and dimmed.
class VendorTile extends StatelessWidget {
  const VendorTile({
    super.key,
    required this.brand,
    required this.subtitle,
    this.locked = false,
    this.onTap,
  });

  final VendorBrand brand;

  /// One-line caption: e.g. "12 certifications" for real vendors, "Bientôt" for
  /// showcase ones.
  final String subtitle;

  /// Whether the vendor is a showcase placeholder (dimmed + padlock, inert).
  final bool locked;

  /// Tap handler; ignored when [locked].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = brand.brandColor;

    final Widget card = PrismCard(
      variant: PrismCardVariant.tonal,
      accent: accent,
      elevation: 0,
      onTap: locked ? null : onTap,
      padding: const EdgeInsets.all(PrismSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _LogoBadge(brand: brand),
              const Spacer(),
              if (locked)
                Icon(Icons.lock_rounded, size: 18, color: p.textSecondary)
              else
                Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
          const SizedBox(height: PrismSpacing.md),
          Text(brand.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: PrismSpacing.xxs),
          Text(subtitle, style: text.labelMedium?.copyWith(color: p.textSecondary)),
        ],
      ),
    );

    if (!locked) return card;

    // Showcase vendors read as "coming soon": dimmed art with a legible caption.
    return Semantics(
      label: '${brand.label}, bientôt disponible',
      button: false,
      child: Opacity(opacity: 0.66, child: card),
    );
  }
}

/// The vendor logo on a soft white chip, so multicolor marks stay legible on
/// the tonal card wash.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.brand});

  final VendorBrand brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(PrismSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PrismRadii.cardMd,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: VendorLogo(brand: brand, size: 36),
    );
  }
}
