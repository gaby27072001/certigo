// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// La couleur d'une piste doit être **la même à chaque lancement**. C'est
// exactement le genre de défaut qui ne se voit pas en développement et qui
// saute aux yeux d'un utilisateur : sa certification change de couleur sans
// raison. `hashValue` de Swift est réamorcé à chaque processus — ces tests
// existent pour garantir qu'on ne l'utilise pas par inadvertance.

import XCTest

@testable import DesignSystem

final class PrismSpectrumTests: XCTestCase {
    /// Le spectre compte six bandes.
    func testSixRefractedBands() {
        XCTAssertEqual(PrismSpectrum.bands.count, 6)
        XCTAssertEqual(
            PrismSpectrum.bands.map(\.name),
            ["violet", "magenta", "rose", "ambre", "vert", "cyan"]
        )
    }

    /// L'empreinte est figée sur des valeurs calculées hors de Swift.
    ///
    /// Les trois nombres ci-dessous ont été obtenus en exécutant FNV-1a
    /// 32 bits en Python le 2026-09-11. Si l'implémentation Swift dérive — un
    /// débordement traité autrement, un encodage différent — ce test le dit.
    func testDigestIsFnv1aAndStable() {
        XCTAssertEqual(PrismSpectrum.stableDigest(""), 2_166_136_261)
        XCTAssertEqual(PrismSpectrum.stableDigest("a"), 3_826_002_220)
        XCTAssertEqual(PrismSpectrum.stableDigest("certigo"), 2_775_154_492)
        XCTAssertEqual(PrismSpectrum.stableDigest("az-900"), 78_840_300)
    }

    /// L'attribution d'une bande est déterministe pour un même identifiant.
    func testBandAssignmentIsDeterministic() {
        for track in ShowcaseTrack.sample {
            let first = PrismSpectrum.band(forTrackId: track.id)
            let second = PrismSpectrum.band(forTrackId: track.id)
            XCTAssertEqual(first, second)
        }
    }

    /// Les identifiants réels tombent sur les bandes attendues.
    func testKnownTracksMapToExpectedBands() {
        let expected: [String: String] = [
            "az-900": "violet",
            "dp-900": "magenta",
            "az-104": "rose",
            "ms-900": "ambre",
            "ai-agent-builder-associate": "vert",
            "github-copilot": "cyan",
        ]
        for (trackId, bandName) in expected {
            XCTAssertEqual(
                PrismSpectrum.band(forTrackId: trackId).name,
                bandName,
                "\(trackId) devrait tomber sur la bande \(bandName)."
            )
        }
    }

    /// Les six pistes de la vitrine couvrent les six bandes, sans doublon.
    ///
    /// Sans ce test, un écran de démonstration pourrait afficher six fois la
    /// même couleur sans que personne ne s'en aperçoive depuis Windows.
    func testShowcaseCoversEveryBand() {
        let bands = ShowcaseTrack.sample.map(\.band.name)
        XCTAssertEqual(bands.count, 6)
        XCTAssertEqual(Set(bands).count, 6, "La vitrine ne montre pas les six bandes.")
    }

    /// Chaque bande est opaque et ses trois rôles sont distincts.
    func testEveryBandHasThreeDistinctRoles() {
        for band in PrismSpectrum.bands {
            XCTAssertEqual(band.ink.prismAlpha, 255)
            XCTAssertEqual(band.vivid.prismAlpha, 255)
            XCTAssertEqual(band.glow.prismAlpha, 255)
            XCTAssertEqual(
                Set([band.ink, band.vivid, band.glow]).count, 3,
                "La bande \(band.name) a deux rôles identiques."
            )
        }
    }

    /// La clarté croît de `ink` vers `glow` dans chaque bande.
    ///
    /// C'est la loi du modèle : `ink` sert sur fond clair, `glow` sur fond
    /// sombre. Une inversion rendrait un texte illisible sur toute une piste.
    func testLuminanceIncreasesFromInkToGlow() {
        for band in PrismSpectrum.bands {
            let ink = PrismContrast.relativeLuminance(band.ink)
            let vivid = PrismContrast.relativeLuminance(band.vivid)
            let glow = PrismContrast.relativeLuminance(band.glow)
            XCTAssertLessThan(ink, vivid, "Bande \(band.name) : ink n'est pas plus sombre que vivid.")
            XCTAssertLessThan(
                vivid, glow, "Bande \(band.name) : vivid n'est pas plus sombre que glow.")
        }
    }

    /// Chaque bande reste lisible dans son rôle prévu.
    ///
    /// `ink` sur la teinte claire de sa région, `glow` sur la teinte sombre.
    /// Le seuil est celui du **texte courant** (4,5:1) et non du grand texte :
    /// les douze ratios ont été calculés le 2026-09-11 et le plus faible rend
    /// **5,01:1**, donc le seuil strict passe avec de la marge.
    func testEachBandIsLegibleOnItsOwnRegion() {
        for band in PrismSpectrum.bands {
            let light = PrismContrast.ratio(band.ink, on: band.softLight)
            let dark = PrismContrast.ratio(band.glow, on: band.softDark)
            XCTAssertGreaterThanOrEqual(
                light, PrismContrast.aaNormalText,
                "Bande \(band.name) : ink sur softLight rend \(light):1.")
            XCTAssertGreaterThanOrEqual(
                dark, PrismContrast.aaNormalText,
                "Bande \(band.name) : glow sur softDark rend \(dark):1.")
        }
    }
}
