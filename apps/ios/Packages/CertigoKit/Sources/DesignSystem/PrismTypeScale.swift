// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Swift pur, sans SwiftUI : l'échelle typographique est une donnée, pas une
// vue. Le pont vers `Font` vit dans `PrismFont.swift`.

/// Un créneau typographique Prism, transcrit depuis
/// `packages/prism_ui/lib/src/tokens/prism_typography.dart`.
///
/// `width` est l'axe de chasse de la police variable Archivo. Il est conservé
/// ici bien qu'inutilisé par le squelette : **la police Archivo n'est pas
/// encore embarquée dans l'application iOS** (voir DEMARRAGE.md, « Ce que ce
/// squelette ne fait pas »). Supprimer la valeur maintenant obligerait à la
/// retrouver plus tard.
public struct PrismTypeSlot: Sendable, Equatable {
    /// Taille en points, identique à la valeur Flutter.
    public let size: Double
    /// Poids sur l'axe `wght` d'Archivo, de 100 à 900.
    public let weight: Double
    /// Interligne exprimé en multiple de la taille, comme `height` en Flutter.
    public let lineHeightMultiple: Double
    /// Approche, en points.
    public let tracking: Double
    /// Chasse sur l'axe `wdth` d'Archivo.
    public let width: Double

    public init(
        size: Double,
        weight: Double,
        lineHeightMultiple: Double,
        tracking: Double,
        width: Double
    ) {
        self.size = size
        self.weight = weight
        self.lineHeightMultiple = lineHeightMultiple
        self.tracking = tracking
        self.width = width
    }

    /// Interligne absolu en points.
    public var lineHeight: Double { size * lineHeightMultiple }
}

/// Les quinze créneaux typographiques de Prism.
///
/// **Ils sont quinze, et `PrismTypeScaleTests` échoue si l'un disparaît.**
/// C'est la transposition directe de la garde `textThemeIsTotal` côté Flutter,
/// écrite après que trois créneaux oubliés ont fait rendre onze textes — dont
/// les deux lignes d'accroche de l'écran d'entrée — dans la police système au
/// lieu de la police de marque.
public enum PrismTypeScale {
    private static let displayWidth: Double = 112
    private static let titleWidth: Double = 104
    private static let uiWidth: Double = 100

    public static let displayLarge = PrismTypeSlot(
        size: 34, weight: 800, lineHeightMultiple: 1.06, tracking: -1.0, width: displayWidth)
    public static let displayMedium = PrismTypeSlot(
        size: 28, weight: 800, lineHeightMultiple: 1.10, tracking: -0.8, width: displayWidth)
    public static let displaySmall = PrismTypeSlot(
        size: 26, weight: 800, lineHeightMultiple: 1.12, tracking: -0.7, width: displayWidth)
    public static let headlineLarge = PrismTypeSlot(
        size: 25, weight: 780, lineHeightMultiple: 1.14, tracking: -0.6, width: displayWidth)
    public static let headlineMedium = PrismTypeSlot(
        size: 24, weight: 750, lineHeightMultiple: 1.16, tracking: -0.5, width: displayWidth)
    public static let headlineSmall = PrismTypeSlot(
        size: 20, weight: 750, lineHeightMultiple: 1.20, tracking: -0.4, width: displayWidth)
    public static let titleLarge = PrismTypeSlot(
        size: 20, weight: 700, lineHeightMultiple: 1.22, tracking: -0.3, width: titleWidth)
    public static let titleMedium = PrismTypeSlot(
        size: 17, weight: 650, lineHeightMultiple: 1.30, tracking: -0.15, width: titleWidth)
    public static let titleSmall = PrismTypeSlot(
        size: 15, weight: 650, lineHeightMultiple: 1.30, tracking: -0.05, width: titleWidth)
    public static let bodyLarge = PrismTypeSlot(
        size: 17, weight: 400, lineHeightMultiple: 1.50, tracking: 0, width: uiWidth)
    public static let bodyMedium = PrismTypeSlot(
        size: 15, weight: 400, lineHeightMultiple: 1.50, tracking: 0, width: uiWidth)
    public static let bodySmall = PrismTypeSlot(
        size: 13, weight: 400, lineHeightMultiple: 1.48, tracking: 0.1, width: uiWidth)
    public static let labelLarge = PrismTypeSlot(
        size: 15, weight: 600, lineHeightMultiple: 1.20, tracking: 0.1, width: uiWidth)
    public static let labelMedium = PrismTypeSlot(
        size: 13, weight: 600, lineHeightMultiple: 1.22, tracking: 0.15, width: uiWidth)
    public static let labelSmall = PrismTypeSlot(
        size: 11, weight: 600, lineHeightMultiple: 1.15, tracking: 0.25, width: uiWidth)

    /// Les quinze créneaux, avec leur nom, groupés par famille comme le
    /// `TextTheme` de Flutter dont ils sont transcrits.
    ///
    /// Un créneau absent de cette liste est un créneau que la garde ne voit
    /// pas : l'ajout d'un créneau doit passer ici.
    public static let all: [(name: String, slot: PrismTypeSlot)] = [
        ("displayLarge", displayLarge),
        ("displayMedium", displayMedium),
        ("displaySmall", displaySmall),
        ("headlineLarge", headlineLarge),
        ("headlineMedium", headlineMedium),
        ("headlineSmall", headlineSmall),
        ("titleLarge", titleLarge),
        ("titleMedium", titleMedium),
        ("titleSmall", titleSmall),
        ("bodyLarge", bodyLarge),
        ("bodyMedium", bodyMedium),
        ("bodySmall", bodySmall),
        ("labelLarge", labelLarge),
        ("labelMedium", labelMedium),
        ("labelSmall", labelSmall),
    ]
}

/// Espacements Prism, transcrits depuis `prism_spacing.dart`.
///
/// Les valeurs `debtN` de Flutter ne sont **pas** reprises : ce sont des dettes
/// nommées, pas des jetons. Les reprendre reviendrait à importer la dette.
public enum PrismSpace {
    public static let xxs: Double = 4
    public static let xs: Double = 8
    public static let sm: Double = 12
    public static let md: Double = 16
    public static let lg: Double = 24
    public static let xl: Double = 32
    public static let xxl: Double = 48
    public static let xxxl: Double = 64
    public static let gutter: Double = 20
    public static let cardInset: Double = 18
}

/// Rayons Prism, transcrits depuis `prism_radii.dart`.
public enum PrismRadius {
    public static let sm: Double = 8
    public static let md: Double = 12
    public static let lg: Double = 16
    public static let xl: Double = 24
    public static let xxl: Double = 30
    public static let button: Double = 20
    public static let pill: Double = 999
}
