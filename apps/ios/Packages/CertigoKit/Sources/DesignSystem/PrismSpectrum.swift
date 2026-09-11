// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Le modèle de couleur de Prism, et la mécanique qui donne à Certigo la
// grammaire d'Apple Music : **la couleur vient du contenu et irradie sa
// région**. Chez Apple Music elle vient de la pochette ; ici elle vient de la
// piste de certification.
//
// Les bandes sont dérivées en OKLCH à **clarté constante** : à L fixe, le
// contraste contre un fond donné reste dans une plage étroite quelle que soit
// la teinte. C'est ce qui rend l'application colorée *et* ordonnée, plutôt que
// colorée *ou* ordonnée.

/// Une bande du spectre Prism, avec ses trois rôles.
public struct PrismBand: Sendable, Equatable {
    /// Nom de la bande, pour le diagnostic et les tests.
    public let name: String
    /// Rôle encre (L≈0.42) : texte et icônes sur surfaces claires.
    public let ink: UInt32
    /// Rôle remplissage (L≈0.62) : anneaux, progression, puces, grands titres.
    public let vivid: UInt32
    /// Rôle chrome sombre (L≈0.68) : texte et icônes sur surfaces sombres.
    public let glow: UInt32
    /// Teinte de région, mode clair.
    public let softLight: UInt32
    /// Teinte de région, mode sombre.
    public let softDark: UInt32
}

/// Les six bandes réfractées, transcrites depuis
/// `packages/prism_ui/lib/src/tokens/prism_colors.dart`.
///
/// Les 30 valeurs (6 bandes × 5 rôles) ont été comparées une à une aux
/// tableaux `color.primitiveSets.spectrum*` de
/// `packages/prism_ui/schemas/tokens/v1/prism-tokens.json` le 2026-09-11 :
/// zéro écart.
public enum PrismSpectrum {
    public static let bands: [PrismBand] = [
        PrismBand(
            name: "violet", ink: 0xFF3B_35F2, vivid: 0xFF61_78F6, glow: 0xFF80_97F8,
            softLight: 0xFFE9_ECF8, softDark: 0xFF19_2061),
        PrismBand(
            name: "magenta", ink: 0xFF90_1BAE, vivid: 0xFFC6_29EE, glow: 0xFFD7_64F8,
            softLight: 0xFFF4_E8F8, softDark: 0xFF3B_1945),
        PrismBand(
            name: "rose", ink: 0xFFA9_1A66, vivid: 0xFFE7_278D, glow: 0xFFF9_5DA5,
            softLight: 0xFFF8_E8ED, softDark: 0xFF45_182C),
        PrismBand(
            name: "ambre", ink: 0xFF92_4A13, vivid: 0xFFC9_681F, glow: 0xFFEC_7B26,
            softLight: 0xFFF8_EAE2, softDark: 0xFF3C_2314),
        PrismBand(
            name: "vert", ink: 0xFF17_7331, vivid: 0xFF24_A047, glow: 0xFF2D_BC55,
            softLight: 0xFFD4_F8D8, softDark: 0xFF17_311B),
        PrismBand(
            name: "cyan", ink: 0xFF17_6C7A, vivid: 0xFF24_96A9, glow: 0xFF2C_B0C7,
            softLight: 0xFFD9_F2F8, softDark: 0xFF16_2E33),
    ]

    /// Empreinte FNV-1a 32 bits d'une chaîne.
    ///
    /// **`hashValue` de Swift est réamorcé à chaque lancement du processus** :
    /// l'utiliser ferait changer la couleur d'une piste entre deux démarrages
    /// de l'application. Cette empreinte-ci est déterministe, et
    /// `PrismSpectrumTests` le vérifie sur des valeurs figées.
    public static func stableDigest(_ value: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }

    /// La bande d'une piste de certification.
    ///
    /// Déterministe, stable entre les lancements, et stable entre les
    /// plateformes tant que l'identifiant de piste ne change pas.
    public static func band(forTrackId trackId: String) -> PrismBand {
        bands[Int(stableDigest(trackId) % UInt32(bands.count))]
    }
}
