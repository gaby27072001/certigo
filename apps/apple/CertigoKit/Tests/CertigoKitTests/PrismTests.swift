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

  @Test func masterFigmaScreenCatalogRegistersAll53ValidatedScreensWithUniqueNodeIdsAndChapters() throws {
    let expectedCodes: [String] = [
      "OB-01", "OB-02", "OB-03A", "OB-03B", "OB-04", "OB-06A", "OB-06B", "OB-06C", "OB-07", "OB-08A", "OB-08B",
      "01", "02", "03", "04", "05",
      "06A", "06B", "06C", "06D",
      "07A", "08", "08B-1", "08B-2",
      "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28",
      "Q_TYPE_01", "Q_TYPE_02", "Q_TYPE_03", "Q_TYPE_04", "Q_TYPE_05",
      "Q_TYPE_06", "Q_TYPE_07", "Q_TYPE_08", "Q_TYPE_09", "Q_TYPE_10",
      "SYS-01", "SYS-02", "RES-01", "RES-02",
    ]
    #expect(expectedCodes.count == 53)
    #expect(CertiGoMasterScreenCatalog.expectedScreenCount == 53)
    #expect(CertiGoMasterScreenCatalog.allScreens.count == 53)
    #expect(CertiGoMasterScreenCatalog.allScreenCodes == expectedCodes)
    #expect(Set(CertiGoMasterScreenCatalog.allScreens.map(\.screenCode)).count == 53)
    #expect(Set(CertiGoMasterScreenCatalog.allScreens.map(\.nodeId)).count == 53)
    #expect(CertiGoMasterScreenCatalog.onboardingScreens.count == 11)
    #expect(CertiGoMasterScreenCatalog.questionFormatScreens.count == 10)
    #expect(CertiGoMasterScreenCatalog.verifyAllInvariants())

    for chapter in CertiGoFigmaChapter.allCases {
      #expect(!CertiGoMasterScreenCatalog.screens(in: chapter).isEmpty)
    }

    for descriptor in CertiGoMasterScreenCatalog.allScreens {
      #expect(!descriptor.nodeId.isEmpty)
      #expect(descriptor.nodeId.contains(":"))
      #expect(!descriptor.title.isEmpty)
      #expect(!descriptor.chapter.isEmpty)
      #expect(CertiGoMasterScreenCatalog.descriptor(forScreenCode: descriptor.screenCode) == descriptor)
      #expect(CertiGoMasterScreenCatalog.descriptor(forNodeId: descriptor.nodeId) == descriptor)
    }
  }

  @Test func masterFigmaScreenCatalogEnforcesMascotPlacementInvariants() throws {
    let screen01 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "01"))
    #expect(screen01.nodeId == "37:375")
    #expect(screen01.mascotPose == .angle34LeftPath)
    #expect(screen01.mascotCount == 1)
    #expect(screen01.verifyMascotPlacementInvariant())

    let screen19 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "19"))
    #expect(screen19.nodeId == "26:912")
    #expect(screen19.mascotPose == .angleFrontCelebration)
    #expect(screen19.mascotCount == 1)
    #expect(screen19.verifyMascotPlacementInvariant())

    for code in ["20", "22", "27"] {
      let screen = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: code))
      #expect(screen.mascotPose == nil, "Expected nil mascot on screen \(code)")
      #expect(screen.mascotCount == 0, "Expected 0 mascot count on screen \(code)")
      #expect(screen.verifyMascotPlacementInvariant())
    }

    for index in 1...10 {
      let code = String(format: "Q_TYPE_%02d", index)
      let screen = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: code))
      let pose = try #require(screen.mascotPose, "Expected specialist mascot on \(code)")
      #expect(pose.isRight34Specialist, "Expected 3/4 right specialist mascot on \(code), got \(pose)")
      #expect(pose.isRight34QuizPose)
      #expect(screen.mascotCount == 1)
      #expect(screen.verifyMascotPlacementInvariant())
    }

    let res01 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "RES-01"))
    #expect(res01.nodeId == "162:93")
    #expect(res01.mascotPose == .poseReaderMemo)

    let res02 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "RES-02"))
    #expect(res02.nodeId == "162:120")
    #expect(res02.mascotPose == .emotionOopsCaring)

    let sys01 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "SYS-01"))
    #expect(sys01.nodeId == "161:93")
    #expect(sys01.mascotPose == .emotionOnFire)

    let sys02 = try #require(CertiGoMasterScreenCatalog.descriptor(forScreenCode: "SYS-02"))
    #expect(sys02.nodeId == "161:134")
    #expect(sys02.mascotPose == nil)

    // Negative checks: violating mascot placement rules must fail verification
    let invalidScreen01 = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "01",
      nodeId: "37:375",
      title: "Invalid 01",
      chapterKind: .homeAndWaymoPath,
      figmaPageId: "0:1",
      mascotPose: .angleFrontCelebration
    )
    #expect(!invalidScreen01.verifyMascotPlacementInvariant())
    #expect(!invalidScreen01.verifyVisualInvariants())

    let invalidScreen22 = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "22",
      nodeId: "26:1009",
      title: "Invalid 22",
      chapterKind: .pearsonVueExamSimulationPage09,
      figmaPageId: "0:1",
      mascotPose: .posePresenter
    )
    #expect(!invalidScreen22.verifyMascotPlacementInvariant())
    #expect(!invalidScreen22.verifyVisualInvariants())

    let invalidQuestionScreen = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "Q_TYPE_01",
      nodeId: "73:393",
      title: "Invalid Q_TYPE_01",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .angle34LeftPath
    )
    #expect(!invalidQuestionScreen.verifyMascotPlacementInvariant())
    #expect(!invalidQuestionScreen.verifyVisualInvariants())
  }

  @Test func masterFigmaScreenCatalogEnforcesZeroGeometricRegressionInvariants() {
    for descriptor in CertiGoMasterScreenCatalog.allScreens {
      #expect(descriptor.hasZeroTextOverlap, "Text overlap detected on \(descriptor.screenCode)")
      #expect(descriptor.hasZeroBoxOverflow, "Box overflow detected on \(descriptor.screenCode)")
      #expect(descriptor.clipsRoundedCorners, "Unclipped rounded corners on \(descriptor.screenCode)")
      #expect(descriptor.canvasWidth == 393)
      #expect(descriptor.canvasHeight == 852)
      #expect(descriptor.passesVisualInvariants)
      #expect(descriptor.verifyVisualInvariants())
    }

    let overlapping = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "OB-01",
      nodeId: "132:182",
      title: "Overlap",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .angleFrontCelebration,
      hasZeroTextOverlap: false
    )
    #expect(!overlapping.verifyVisualInvariants())

    let overflowing = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "OB-01",
      nodeId: "132:182",
      title: "Overflow",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .angleFrontCelebration,
      hasZeroBoxOverflow: false
    )
    #expect(!overflowing.verifyVisualInvariants())

    let unclipped = CertiGoMasterFigmaScreenDescriptor(
      screenCode: "OB-01",
      nodeId: "132:182",
      title: "Unclipped",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .angleFrontCelebration,
      clipsRoundedCorners: false
    )
    #expect(!unclipped.verifyVisualInvariants())
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

    @MainActor @Test func masterScreenCatalogRendersDeterministicPNGSnapshotsAcrossFourAppearancesAndThreeDynamicTypes() throws {
      #expect(PrismSnapshotHarness.normativeAppearances == PrismAppearance.allCases)
      #expect(PrismSnapshotHarness.normativeDynamicTypeSizes == [.large, .accessibility3, .accessibility5])

      let matrix = try CertiGoMasterScreenCatalog.renderSnapshotMatrix(
        forScreenCode: "01",
        size: CGSize(width: 393, height: 852)
      )
      #expect(matrix.count == 12)
      for entry in matrix {
        #expect(entry.screenCode == "01")
        #expect(entry.nodeId == "37:375")
        #expect(!entry.pngData.isEmpty)
        let decoded = try PrismSnapshotHarness.decodePNG(entry.pngData)
        #expect(decoded.matches(entry.snapshot))
      }
    }
  }
#endif
