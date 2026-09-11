// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Pont entre les jetons Prism (données pures) et SwiftUI (rendu).
// C'est le seul fichier du système de design autorisé à appeler
// `Font.system` : partout ailleurs, on passe par `PrismFont`.

import SwiftUI

extension Color {
    /// Construit une couleur depuis un littéral ARGB Prism.
    ///
    /// L'espace est explicitement `.sRGB` : le défaut de SwiftUI est
    /// `sRGBLinear` pour certains initialisateurs, et une couleur de marque qui
    /// dérive d'un espace à l'autre est exactement le genre d'écart que
    /// personne ne remarque avant la capture d'écran de l'App Store.
    public init(prism argb: UInt32) {
        self.init(
            .sRGB,
            red: Double(argb.prismRed) / 255.0,
            green: Double(argb.prismGreen) / 255.0,
            blue: Double(argb.prismBlue) / 255.0,
            opacity: Double(argb.prismAlpha) / 255.0
        )
    }
}

/// Correspondance entre un créneau Prism et la typographie dynamique d'iOS.
public enum PrismFont {
    /// Les styles de texte natifs, avec leur taille au réglage par défaut.
    ///
    /// Ces tailles sont celles publiées par Apple pour la taille dynamique
    /// « Large » (le défaut). Elles ne sont **pas vérifiées à l'exécution** ici :
    /// `PrismFontTests` vérifie seulement que chaque créneau Prism est associé à
    /// un style dont la taille de référence est proche de la sienne.
    public enum NativeStyle: String, CaseIterable, Sendable {
        case largeTitle, title, title2, title3, headline, body
        case callout, subheadline, footnote, caption, caption2

        /// Taille de référence en points, au réglage dynamique par défaut.
        public var referenceSize: Double {
            switch self {
            case .largeTitle: 34
            case .title: 28
            case .title2: 22
            case .title3: 20
            case .headline: 17
            case .body: 17
            case .callout: 16
            case .subheadline: 15
            case .footnote: 13
            case .caption: 12
            case .caption2: 11
            }
        }

        var textStyle: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subheadline: .subheadline
            case .footnote: .footnote
            case .caption: .caption
            case .caption2: .caption2
            }
        }
    }

    /// Le style natif retenu pour un créneau Prism.
    ///
    /// **Aucune taille fixe.** C'est la règle d'accessibilité la plus stricte
    /// du système : une taille en dur ne suit pas la taille dynamique, et un
    /// utilisateur qui a grossi son texte voit une application cassée.
    public static func nativeStyle(for name: String) -> NativeStyle {
        switch name {
        case "displayLarge": .largeTitle
        case "displayMedium", "displaySmall", "headlineLarge": .title
        case "headlineMedium": .title2
        case "headlineSmall", "titleLarge": .title3
        case "titleMedium": .headline
        case "bodyLarge": .body
        case "titleSmall", "bodyMedium", "labelLarge": .subheadline
        case "bodySmall", "labelMedium": .footnote
        case "labelSmall": .caption2
        default: .body
        }
    }

    /// Index de graisse le plus proche, de 1 à 9.
    ///
    /// Reproduit exactement `PrismTypography._nearestWeight` côté Dart, y
    /// compris son arrondi : 750 et 650 montent, comme en Dart.
    public static func nearestWeightIndex(_ weight: Double) -> Int {
        min(max(Int((weight / 100).rounded()), 1), 9)
    }

    static func weight(_ value: Double) -> Font.Weight {
        switch nearestWeightIndex(value) {
        case 1: .ultraLight
        case 2: .thin
        case 3: .light
        case 4: .regular
        case 5: .medium
        case 6: .semibold
        case 7: .bold
        case 8: .heavy
        default: .black
        }
    }

    /// La police SwiftUI d'un créneau Prism nommé.
    ///
    /// La police de marque **Archivo n'est pas embarquée** dans ce squelette :
    /// le rendu utilise la police système aux mêmes métriques. Voir
    /// DEMARRAGE.md, « Ce que ce squelette ne fait pas ».
    public static func font(_ name: String, weight rawWeight: Double) -> Font {
        .system(nativeStyle(for: name).textStyle, weight: weight(rawWeight))
    }
}

extension View {
    /// Applique un créneau typographique Prism, approche comprise.
    public func prismType(_ named: String) -> some View {
        let slot = PrismTypeScale.all.first { $0.name == named }?.slot ?? PrismTypeScale.bodyLarge
        return self
            .font(PrismFont.font(named, weight: slot.weight))
            .tracking(slot.tracking)
    }
}
