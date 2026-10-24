import Foundation
import Testing

@testable import Prism

@Suite struct PrismTests {
  @Test func normativeSizesAndMotionRemainAccessible() {
    #expect(
      [
        PrismSpacing.xxs, PrismSpacing.xs, PrismSpacing.s, PrismSpacing.m,
        PrismSpacing.l, PrismSpacing.xl, PrismSpacing.xxl, PrismSpacing.xxxl,
        PrismSpacing.huge, PrismSpacing.giant,
      ] == [2, 4, 8, 12, 16, 20, 24, 32, 48, 64])
    #expect([PrismRadius.s, PrismRadius.m, PrismRadius.l, PrismRadius.xl] == [8, 12, 16, 24])
    #expect(PrismRadius.capsule == .capsule)
    #expect(
      [
        PrismSize.minTouch, PrismSize.primaryButtonHeight, PrismSize.readableWidth,
        PrismSize.brandS, PrismSize.brandM, PrismSize.brandL, PrismSize.brandXL,
      ] == [44, 50, 672, 20, 28, 40, 56])
    for token in PrismMotionToken.allCases {
      let reduced = PrismMotion.resolve(token, reduceMotion: true)
      #expect(reduced.opacityOnly)
      #expect(reduced.duration <= 0.3)
      #expect(reduced.curve == .easeOut)
      #expect(PrismMotion.resolve(token, reduceMotion: false).duration <= 1.2)
    }
    for material in PrismMaterialRole.allCases {
      #expect(material.usesOpaqueSurface(reduceTransparency: true))
      #expect(!material.usesOpaqueSurface(reduceTransparency: false))
    }
    #expect(PrismCelebrationLevel.allCases.map(\.rawValue) == [0, 1, 2, 3])
    #expect(PrismCelebrationLevel.milestone.resolved(calmMode: true) == .pulse)
    #expect(PrismTextStyle.allCases.count == 14)
  }

  @Test func wcagTextAndNonTextPairsMeetNormativeThresholds() {
    let backgrounds: [PrismColorRole] = [.canvas, .surface, .surfaceRaised, .surfaceArtifact]
    // Secondary/tertiary labels are platform-owned deemphasized text, not body/accent roles.
    let foregrounds: [PrismColorRole] = [.textPrimary, .accent, .positive, .negative, .caution]
    for appearance in PrismAppearance.allCases {
      for background in backgrounds {
        let back = background.rgba(in: appearance)
        for foreground in foregrounds {
          let ratio = foreground.rgba(in: appearance).contrastRatio(over: back)
          #expect(ratio >= 4.5, "\(foreground)/\(background)/\(appearance): \(ratio)")
          #expect(ratio >= 3, "Non-text: \(foreground)/\(background)/\(appearance)")
        }
        for region in PrismRegion.allCases {
          let ratio = region.rgba(in: appearance).contrastRatio(over: back)
          #expect(ratio >= 4.5, "\(region)/\(background)/\(appearance): \(ratio)")
          let soft = region.soft.rgba(in: appearance).composited(over: back)
          #expect(
            PrismColorRole.textPrimary.rgba(in: appearance).contrastRatio(over: soft) >= 4.5,
            "textPrimary/\(region).soft/\(background)/\(appearance)")
        }
      }
      let ratio = PrismColorRole.onAccent.rgba(in: appearance)
        .contrastRatio(over: PrismColorRole.accentFill.rgba(in: appearance))
      #expect(ratio >= 4.5, "onAccent/accentFill/\(appearance): \(ratio)")
      #expect(
        PrismColorRole.textPrimary.rgba(in: appearance).contrastRatio(
          over: PrismSyntax.flaggedLineBackground.rgba(in: appearance)) >= 4.5)
      for syntax in PrismSyntax.allCases where syntax != .flaggedLineBackground {
        for background in [
          PrismColorRole.surfaceArtifact.rgba(in: appearance),
          PrismSyntax.flaggedLineBackground.rgba(in: appearance),
        ] {
          let ratio = syntax.rgba(in: appearance).contrastRatio(over: background)
          #expect(
            ratio >= (appearance.isHighContrast ? 7 : 4.5),
            "syntax.\(syntax)/\(appearance): \(ratio)")
        }
      }
    }
  }

  @Test func regionSoftOpacityAndCompositingFollowAppearance() {
    for region in PrismRegion.allCases {
      for appearance in PrismAppearance.allCases {
        let soft = region.soft.rgba(in: appearance)
        #expect(soft.alpha == (appearance.isDark ? 0.2 : 0.12))
        #expect(soft.composited(over: .init(hex: 0xFFFFFF)).alpha == 1)
      }
    }
    #expect(PrismRGBA(hex: 0).contrastRatio(over: .init(hex: 0xFFFFFF)) == 21)
    #expect(PrismRGBA(hex: 0, alpha: 0).contrastRatio(over: .init(hex: 0xFFFFFF)) == 1)
  }

  @Test func snapshotsUseDeterministicDimensionsAndPixelsNotPNGMetadata() throws {
    let pixels = Data([255, 0, 0, 255, 0, 255, 0, 255])
    let snapshot = try PrismSnapshot(width: 2, height: 1, pixels: pixels)
    #expect(snapshot.fingerprint == "a5aac2e9e121144e")
    #expect(snapshot.matches(try PrismSnapshot(width: 2, height: 1, pixels: pixels)))
    #expect(
      snapshot.fingerprint == (try PrismSnapshot(width: 2, height: 1, pixels: pixels)).fingerprint)
    #expect(!snapshot.matches(try PrismSnapshot(width: 1, height: 2, pixels: pixels)))
    #expect(
      !snapshot.matches(
        try PrismSnapshot(
          width: 2, height: 1, pixels: Data([0, 0, 0, 255, 0, 255, 0, 255]))))
    #expect(
      snapshot.fingerprint != (try PrismSnapshot(width: 1, height: 2, pixels: pixels)).fingerprint)
    #expect(throws: PrismSnapshotError.invalidDimensions) {
      try PrismSnapshot(width: 0, height: 2, pixels: pixels)
    }
    #expect(throws: PrismSnapshotError.invalidPixelCount) {
      try PrismSnapshot(width: Int.max, height: 2, pixels: pixels)
    }
    #expect(throws: PrismSnapshotError.invalidPixelCount) {
      try PrismSnapshot(width: 1, height: 1, pixels: Data())
    }
  }
}

#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI

  extension PrismTests {
    @MainActor @Test func nativeRendererRoundTripsPNGInEveryAppearance() throws {
      for appearance in PrismAppearance.allCases {
        for dynamicType in [DynamicTypeSize.large, .accessibility3, .accessibility5] {
          for locale in ["fr", "en", "de"] {
            let configuration = PrismSnapshotHarness.Configuration(
              size: CGSize(width: 320, height: 480), appearance: appearance,
              dynamicType: dynamicType, locale: Locale(identifier: locale))
            let view = Text(verbatim: "Prism").prismTextStyle(.body)
              .foregroundStyle(PrismColor.textPrimary)
              .padding(PrismSpacing.l).background(PrismColor.surface)
            let snapshot = try PrismSnapshotHarness.render(view, configuration: configuration)
            #expect(
              snapshot.matches(
                try PrismSnapshotHarness.render(view, configuration: configuration)))
            #expect(
              snapshot.matches(
                try PrismSnapshotHarness.decodePNG(
                  PrismSnapshotHarness.pngData(snapshot))))
          }
        }
      }
    }
  }
#endif
