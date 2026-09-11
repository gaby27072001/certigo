// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Aucun `import` : la palette est du Swift pur. C'est délibéré.
// Les valeurs sont la seule source de vérité portable entre Dart et Swift, et
// un fichier sans dépendance de plateforme est testable partout, y compris là
// où SwiftUI n'existe pas.

/// Palette Prism, transcrite à l'identique depuis
/// `packages/prism_ui/lib/src/tokens/prism_colors.dart`.
///
/// Les littéraux sont conservés au format **ARGB** exactement comme côté Dart
/// (`Color(0xFF3B35F2)`), pour qu'une comparaison entre les deux fichiers reste
/// lisible à l'œil nu et automatisable plus tard.
///
/// **Source neutre.** Depuis `#473`, `packages/prism_ui/schemas/tokens/v1/`
/// `prism-tokens.json` publie ces mêmes valeurs dans un format indépendant du
/// langage. Les 32 jetons ci-dessous **ont été comparés un à un** à ce fichier
/// le 2026-09-11 : zéro écart. À terme, cette transcription manuelle doit être
/// remplacée par une génération depuis ce JSON, avec un contrôle de CI
/// vérifiant que la régénération est identique à l'octet.
public enum PrismPalette {
    // MARK: Marque

    public static let primary: UInt32 = 0xFF3B_35F2
    public static let primaryDark: UInt32 = 0xFF2B_1AC4
    public static let primarySoft: UInt32 = 0xFFE9_ECF8
    public static let primarySoftDark: UInt32 = 0xFF19_2061
    public static let primaryVivid: UInt32 = 0xFF61_78F6
    public static let primaryGlow: UInt32 = 0xFF80_97F8

    // MARK: Accents produit

    public static let ember: UInt32 = 0xFFB0_2013
    public static let emberVivid: UInt32 = 0xFFF1_2F1E
    public static let xpGold: UInt32 = 0xFF92_4A13
    public static let xpGoldVivid: UInt32 = 0xFFC9_681F

    // MARK: Sémantique

    public static let success: UInt32 = 0xFF17_7331
    public static let successVivid: UInt32 = 0xFF24_A047
    public static let warning: UInt32 = 0xFF80_5713
    public static let warningVivid: UInt32 = 0xFFB0_7A1F
    public static let error: UInt32 = 0xFFB0_1B2D
    public static let errorVivid: UInt32 = 0xFFF1_2941
    public static let info: UInt32 = 0xFF15_62AA
    public static let infoVivid: UInt32 = 0xFF21_88E8

    // MARK: Surfaces claires

    public static let lightBg: UInt32 = 0xFFEC_EEF5
    public static let lightSurface: UInt32 = 0xFFFF_FFFF
    public static let lightSurfaceAlt: UInt32 = 0xFFDD_E0EC
    public static let lightTextPrimary: UInt32 = 0xFF16_1A29
    public static let lightTextSecondary: UInt32 = 0xFF55_5A6B
    public static let lightTextDisabled: UInt32 = 0xFF85_8894
    public static let lightBorder: UInt32 = 0xFFC2_C6D4

    // MARK: Surfaces sombres

    public static let darkBg: UInt32 = 0xFF0D_1019
    public static let darkSurface: UInt32 = 0xFF1C_1F2B
    public static let darkSurfaceAlt: UInt32 = 0xFF29_2E3D
    public static let darkTextPrimary: UInt32 = 0xFFF5_F7FC
    public static let darkTextSecondary: UInt32 = 0xFFAD_B1C0
    public static let darkTextDisabled: UInt32 = 0xFF76_7A87
    public static let darkBorder: UInt32 = 0xFF41_4759
}

extension UInt32 {
    /// Composante alpha d'un littéral ARGB, de 0 à 255.
    public var prismAlpha: UInt8 { UInt8((self >> 24) & 0xFF) }
    /// Composante rouge, de 0 à 255.
    public var prismRed: UInt8 { UInt8((self >> 16) & 0xFF) }
    /// Composante verte, de 0 à 255.
    public var prismGreen: UInt8 { UInt8((self >> 8) & 0xFF) }
    /// Composante bleue, de 0 à 255.
    public var prismBlue: UInt8 { UInt8(self & 0xFF) }
}
