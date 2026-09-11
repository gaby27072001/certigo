// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// ⚠️ Les ratios attendus de ce fichier sont les **seules valeurs de tout le
// squelette qui ont été réellement calculées** avant d'être écrites : la même
// formule WCAG 2.1 a été exécutée en Python sur les mêmes littéraux, depuis
// Windows, le 2026-09-11. Tout le reste du code Swift de cette branche est
// non vérifié par construction.

import XCTest

@testable import DesignSystem

final class PrismContrastTests: XCTestCase {
    /// Chaque paire réellement utilisée par l'interface franchit le seuil AA.
    ///
    /// C'est la transposition de la garde `tools/contrast.mjs`, que le dépôt
    /// exige de préserver à travers la migration.
    func testEveryAuditedPairMeetsWcagAA() {
        XCTAssertFalse(
            PrismContrast.auditedPairs.isEmpty,
            "Une liste de paires vide ferait passer ce test sans rien mesurer."
        )
        for pair in PrismContrast.auditedPairs {
            let ratio = PrismContrast.ratio(pair.foreground, on: pair.background)
            XCTAssertGreaterThanOrEqual(
                ratio,
                PrismContrast.aaNormalText,
                "\(pair.name) : \(ratio):1 est sous le seuil AA de 4,5:1."
            )
        }
    }

    /// Les ratios exacts, figés. Un jeton de couleur qui dérive casse ici, et
    /// le message dit de combien.
    func testMeasuredRatiosAreStable() {
        let expected: [(String, UInt32, UInt32, Double)] = [
            ("lightTextPrimary sur lightBg", 0xFF16_1A29, 0xFFEC_EEF5, 14.923),
            ("lightTextPrimary sur lightSurface", 0xFF16_1A29, 0xFFFF_FFFF, 17.300),
            ("lightTextSecondary sur lightSurface", 0xFF55_5A6B, 0xFFFF_FFFF, 6.860),
            ("blanc sur primary", 0xFFFF_FFFF, 0xFF3B_35F2, 7.053),
            ("blanc sur error", 0xFFFF_FFFF, 0xFFB0_1B2D, 6.906),
            ("blanc sur success", 0xFFFF_FFFF, 0xFF17_7331, 5.944),
            ("darkTextPrimary sur darkBg", 0xFFF5_F7FC, 0xFF0D_1019, 17.726),
            ("darkTextPrimary sur darkSurface", 0xFFF5_F7FC, 0xFF1C_1F2B, 15.304),
            ("darkTextSecondary sur darkSurface", 0xFFAD_B1C0, 0xFF1C_1F2B, 7.676),
        ]
        for (name, foreground, background, value) in expected {
            XCTAssertEqual(
                PrismContrast.ratio(foreground, on: background),
                value,
                accuracy: 0.01,
                "\(name) a dérivé."
            )
        }
    }

    /// Une couleur sur elle-même vaut exactement 1:1, le noir sur blanc 21:1.
    /// Deux points d'ancrage qui prouvent que la formule n'a pas été recopiée
    /// de travers.
    func testFormulaAnchors() {
        XCTAssertEqual(PrismContrast.ratio(0xFF12_3456, on: 0xFF12_3456), 1.0, accuracy: 0.0001)
        XCTAssertEqual(PrismContrast.ratio(0xFF00_0000, on: 0xFFFF_FFFF), 21.0, accuracy: 0.0001)
    }

    /// L'alpha n'entre pas dans le calcul : seule la couleur composée compte.
    func testAlphaIsIgnored() {
        XCTAssertEqual(
            PrismContrast.relativeLuminance(0xFF3B_35F2),
            PrismContrast.relativeLuminance(0x003B_35F2),
            accuracy: 0.000_001
        )
    }
}

final class PrismPaletteTests: XCTestCase {
    /// La décomposition ARGB est exacte, sur la couleur de marque.
    func testArgbDecomposition() {
        let primary = PrismPalette.primary
        XCTAssertEqual(primary.prismAlpha, 255)
        XCTAssertEqual(primary.prismRed, 0x3B)
        XCTAssertEqual(primary.prismGreen, 0x35)
        XCTAssertEqual(primary.prismBlue, 0xF2)
    }

    /// Toutes les couleurs de la palette sont opaques.
    ///
    /// Les couleurs translucides de Prism (le « verre ») ne sont volontairement
    /// pas encore transcrites : elles demandent un rendu de matériau que ce
    /// squelette n'aborde pas.
    func testPaletteIsOpaque() {
        let all: [UInt32] = [
            PrismPalette.primary, PrismPalette.primaryDark, PrismPalette.primarySoft,
            PrismPalette.ember, PrismPalette.xpGold, PrismPalette.success,
            PrismPalette.warning, PrismPalette.error, PrismPalette.info,
            PrismPalette.lightBg, PrismPalette.lightSurface, PrismPalette.lightTextPrimary,
            PrismPalette.darkBg, PrismPalette.darkSurface, PrismPalette.darkTextPrimary,
        ]
        for color in all {
            XCTAssertEqual(color.prismAlpha, 255, "0x\(String(color, radix: 16)) n'est pas opaque.")
        }
    }
}
