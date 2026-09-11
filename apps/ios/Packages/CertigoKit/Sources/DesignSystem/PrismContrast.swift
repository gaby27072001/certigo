// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Ce fichier porte la seule garde de ce squelette dont les valeurs attendues
// ont été *calculées*, et non supposées : les ratios vérifiés par
// `PrismContrastTests` ont été obtenus en exécutant la même formule WCAG 2.1
// en Python sur les mêmes littéraux, depuis Windows.
//
// C'est la transposition Swift de `tools/contrast.mjs`, dont `AGENTS.md`
// demande que la garde survive à la migration.

import Foundation

/// Calcul de contraste WCAG 2.1, en arithmétique pure.
public enum PrismContrast {
    /// Luminance relative d'un canal 0–255, après linéarisation sRGB.
    private static func linearized(_ channel: UInt8) -> Double {
        let value = Double(channel) / 255.0
        return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// Luminance relative d'une couleur ARGB. L'alpha est ignoré : le contraste
    /// se mesure sur une couleur composée, pas sur une couleur translucide.
    public static func relativeLuminance(_ argb: UInt32) -> Double {
        0.2126 * linearized(argb.prismRed)
            + 0.7152 * linearized(argb.prismGreen)
            + 0.0722 * linearized(argb.prismBlue)
    }

    /// Ratio de contraste entre deux couleurs, de 1 à 21.
    public static func ratio(_ foreground: UInt32, on background: UInt32) -> Double {
        let a = relativeLuminance(foreground)
        let b = relativeLuminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Seuil WCAG AA pour du texte courant.
    public static let aaNormalText: Double = 4.5
    /// Seuil WCAG AA pour du grand texte et les éléments non textuels.
    public static let aaLargeText: Double = 3.0

    /// Les paires réellement utilisées par l'écran vitrine, et par tout écran
    /// à venir. Les tests les parcourent toutes : ajouter une paire ici, c'est
    /// la soumettre à la garde.
    public static let auditedPairs: [(name: String, foreground: UInt32, background: UInt32)] = [
        ("lightTextPrimary sur lightBg", PrismPalette.lightTextPrimary, PrismPalette.lightBg),
        (
            "lightTextPrimary sur lightSurface", PrismPalette.lightTextPrimary,
            PrismPalette.lightSurface
        ),
        (
            "lightTextSecondary sur lightSurface", PrismPalette.lightTextSecondary,
            PrismPalette.lightSurface
        ),
        ("lightSurface sur primary", PrismPalette.lightSurface, PrismPalette.primary),
        ("lightSurface sur error", PrismPalette.lightSurface, PrismPalette.error),
        ("lightSurface sur success", PrismPalette.lightSurface, PrismPalette.success),
        ("darkTextPrimary sur darkBg", PrismPalette.darkTextPrimary, PrismPalette.darkBg),
        (
            "darkTextPrimary sur darkSurface", PrismPalette.darkTextPrimary,
            PrismPalette.darkSurface
        ),
        (
            "darkTextSecondary sur darkSurface", PrismPalette.darkTextSecondary,
            PrismPalette.darkSurface
        ),
    ]
}
