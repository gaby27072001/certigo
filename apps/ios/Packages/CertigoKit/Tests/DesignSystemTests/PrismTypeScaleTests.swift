// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Transposition de la garde `textThemeIsTotal` de `packages/prism_ui` : côté
// Flutter, trois créneaux oubliés ont fait rendre onze textes dans la police
// système au lieu de la police de marque, dont les deux lignes d'accroche du
// premier écran. Personne ne l'avait vu.

import XCTest

@testable import DesignSystem

final class PrismTypeScaleTests: XCTestCase {
    /// Les quinze créneaux sont là. Ni quatorze, ni un doublon.
    func testScaleIsTotal() {
        XCTAssertEqual(PrismTypeScale.all.count, 15)
        let names = Set(PrismTypeScale.all.map(\.name))
        XCTAssertEqual(names.count, 15, "Deux créneaux portent le même nom.")
    }

    /// Les métriques qui comptent, figées sur les valeurs Flutter.
    func testKeyMetricsMatchFlutter() {
        XCTAssertEqual(PrismTypeScale.bodyLarge.size, 17, "Le corps de texte iOS vaut 17 pt.")
        XCTAssertEqual(PrismTypeScale.displayLarge.size, 34)
        XCTAssertEqual(PrismTypeScale.labelSmall.size, 11, "Le plancher typographique vaut 11 pt.")
    }

    /// Aucun créneau ne descend sous le plancher de lisibilité de 11 pt.
    func testNoSlotFallsBelowTheFloor() {
        for entry in PrismTypeScale.all {
            XCTAssertGreaterThanOrEqual(
                entry.slot.size, 11, "\(entry.name) descend sous le plancher de 11 pt.")
        }
    }

    /// Dans chaque famille, les tailles décroissent. C'est ce qui fait repérer
    /// un créneau inséré au mauvais endroit.
    ///
    /// L'échelle **n'est pas** globalement décroissante, et ce n'est pas un
    /// défaut : `bodyLarge` (17 pt) suit `titleSmall` (15 pt), exactement comme
    /// dans le `TextTheme` de Flutter dont elle est transcrite.
    func testEachFamilyIsOrderedBySizeDescending() {
        let families = ["display", "headline", "title", "body", "label"]
        for family in families {
            let sizes = PrismTypeScale.all
                .filter { $0.name.hasPrefix(family) }
                .map(\.slot.size)
            XCTAssertEqual(sizes.count, 3, "La famille \(family) doit compter trois créneaux.")
            XCTAssertEqual(sizes, sizes.sorted(by: >), "La famille \(family) n'est plus ordonnée.")
        }
    }

    /// L'interligne absolu se calcule bien depuis le multiple.
    func testLineHeightIsComputedFromMultiple() {
        XCTAssertEqual(PrismTypeScale.bodyLarge.lineHeight, 25.5, accuracy: 0.001)
    }
}

final class PrismFontTests: XCTestCase {
    /// L'arrondi de graisse reproduit celui de Dart, cas limites compris.
    ///
    /// 750 et 650 montent : `(7.5).rounded()` vaut 8 en Swift comme en Dart.
    func testNearestWeightMatchesDartRounding() {
        XCTAssertEqual(PrismFont.nearestWeightIndex(800), 8)
        XCTAssertEqual(PrismFont.nearestWeightIndex(780), 8)
        XCTAssertEqual(PrismFont.nearestWeightIndex(750), 8)
        XCTAssertEqual(PrismFont.nearestWeightIndex(700), 7)
        XCTAssertEqual(PrismFont.nearestWeightIndex(650), 7)
        XCTAssertEqual(PrismFont.nearestWeightIndex(600), 6)
        XCTAssertEqual(PrismFont.nearestWeightIndex(400), 4)
    }

    /// L'index reste dans les bornes utilisables par `Font.Weight`.
    func testWeightIndexIsClamped() {
        XCTAssertEqual(PrismFont.nearestWeightIndex(0), 1)
        XCTAssertEqual(PrismFont.nearestWeightIndex(-500), 1)
        XCTAssertEqual(PrismFont.nearestWeightIndex(950), 9)
        XCTAssertEqual(PrismFont.nearestWeightIndex(10_000), 9)
    }

    /// Chaque créneau Prism est associé à un style natif de taille voisine.
    ///
    /// L'écart maximal toléré est de 3 pt, et un seul créneau l'atteint :
    /// `headlineLarge` (25 pt) n'a pas de style natif plus proche que `title`
    /// (28 pt). C'est le prix de la typographie dynamique, et il est assumé :
    /// une taille fixe suivrait le gabarit mais pas l'utilisateur.
    func testEverySlotMapsToANearbyNativeStyle() {
        for entry in PrismTypeScale.all {
            let native = PrismFont.nativeStyle(for: entry.name)
            let delta = abs(native.referenceSize - entry.slot.size)
            XCTAssertLessThanOrEqual(
                delta, 3,
                "\(entry.name) (\(entry.slot.size) pt) est associé à "
                    + "\(native.rawValue) (\(native.referenceSize) pt), soit \(delta) pt d'écart."
            )
        }
    }

    /// Un nom inconnu retombe sur le corps de texte plutôt que de planter.
    func testUnknownSlotFallsBackToBody() {
        XCTAssertEqual(PrismFont.nativeStyle(for: "créneauQuiNExistePas"), .body)
    }
}
