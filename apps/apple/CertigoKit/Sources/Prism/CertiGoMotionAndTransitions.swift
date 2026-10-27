import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Page 13 Figma Pro — 8 Validated Spring & Micro-Interaction Presets (ANIM_01 .. ANIM_08)

public enum CertiGoAnimationPresetID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
  case anim01Tactile3DPress = "ANIM_01"
  case anim02ApplePayBottomSheet = "ANIM_02"
  case anim03Mascot34SpeechBubblePop = "ANIM_03"
  case anim04Claude85DrawerPush = "ANIM_04"
  case anim05NovaLiveVoicePulse = "ANIM_05"
  case anim06PearsonBarometerFill = "ANIM_06"
  case anim07DualCurveAndFitnessRings = "ANIM_07"
  case anim08CelebrationVictoryJump = "ANIM_08"

  public var id: String { rawValue }

  public var mass: Double {
    1.0
  }

  public var stiffness: Double {
    switch self {
    case .anim01Tactile3DPress:
      return 600.0
    case .anim02ApplePayBottomSheet:
      return 340.0
    case .anim03Mascot34SpeechBubblePop:
      return 380.0
    case .anim04Claude85DrawerPush:
      return 360.0
    case .anim05NovaLiveVoicePulse:
      return 220.0
    case .anim06PearsonBarometerFill:
      return 280.0
    case .anim07DualCurveAndFitnessRings:
      return 260.0
    case .anim08CelebrationVictoryJump:
      return 280.0
    }
  }

  public var damping: Double {
    switch self {
    case .anim01Tactile3DPress:
      return 28.0
    case .anim02ApplePayBottomSheet:
      return 26.0
    case .anim03Mascot34SpeechBubblePop:
      return 24.0
    case .anim04Claude85DrawerPush:
      return 28.0
    case .anim05NovaLiveVoicePulse:
      return 18.0
    case .anim06PearsonBarometerFill:
      return 22.0
    case .anim07DualCurveAndFitnessRings:
      return 24.0
    case .anim08CelebrationVictoryJump:
      return 16.0
    }
  }

  public var durationSeconds: Double {
    switch self {
    case .anim01Tactile3DPress:
      return 0.12
    case .anim02ApplePayBottomSheet:
      return 0.38
    case .anim03Mascot34SpeechBubblePop:
      return 0.32
    case .anim04Claude85DrawerPush:
      return 0.36
    case .anim05NovaLiveVoicePulse:
      return 0.65
    case .anim06PearsonBarometerFill:
      return 0.48
    case .anim07DualCurveAndFitnessRings:
      return 0.52
    case .anim08CelebrationVictoryJump:
      return 0.48
    }
  }

  public var headerSpecDurationMilliseconds: Int {
    switch self {
    case .anim01Tactile3DPress:
      return 80
    case .anim02ApplePayBottomSheet:
      return 380
    case .anim03Mascot34SpeechBubblePop:
      return 320
    case .anim04Claude85DrawerPush:
      return 360
    case .anim05NovaLiveVoicePulse:
      return 1200
    case .anim06PearsonBarometerFill:
      return 480
    case .anim07DualCurveAndFitnessRings:
      return 520
    case .anim08CelebrationVictoryJump:
      return 480
    }
  }

  public var figmaTransitionType: String {
    switch self {
    case .anim01Tactile3DPress:
      return "CUSTOM_SPRING"
    case .anim02ApplePayBottomSheet:
      return "MOVE_IN BOTTOM"
    case .anim03Mascot34SpeechBubblePop:
      return "SMART_ANIMATE"
    case .anim04Claude85DrawerPush:
      return "PUSH RIGHT"
    case .anim05NovaLiveVoicePulse:
      return "KEYFRAMES / SMART_ANIMATE"
    case .anim06PearsonBarometerFill:
      return "SMART_ANIMATE"
    case .anim07DualCurveAndFitnessRings:
      return "SMART_ANIMATE"
    case .anim08CelebrationVictoryJump:
      return "BOUNCY SPRING"
    }
  }

  public var stageLayerNames: [String] {
    switch self {
    case .anim01Tactile3DPress:
      return ["M_OPT_CARD", "M_CTA_LIP", "M_CTA_FACE"]
    case .anim02ApplePayBottomSheet:
      return ["M_DIM_BACKDROP", "M_APPLE_PAY_SHEET", "M_CREST_HALO"]
    case .anim03Mascot34SpeechBubblePop:
      return ["M_MASCOT_34", "M_SPEECH_BUBBLE"]
    case .anim04Claude85DrawerPush:
      return ["M_CLAUDE_DRAWER", "M_MAIN_CHAT"]
    case .anim05NovaLiveVoicePulse:
      return ["M_VOICE_HALO_OUTER", "M_VOICE_HALO_MID", "M_VOICE_CORE"]
    case .anim06PearsonBarometerFill:
      return ["M_BAROMETER_CARD", "M_BAROMETER_TRACK", "M_BAROMETER_FILL"]
    case .anim07DualCurveAndFitnessRings:
      return ["M_DUAL_CURVE_BOX", "M_CURVE_WITH_CERTIGO", "M_CURVE_WITHOUT_CERTIGO"]
    case .anim08CelebrationVictoryJump:
      return ["M_CELEB_MASCOT", "M_CELEB_STATS"]
    }
  }

  public var canonicalCopyText: String {
    switch self {
    case .anim01Tactile3DPress:
      return "A · privatelink.blob.core.windows.net"
    case .anim02ApplePayBottomSheet:
      return "Examen Blanc AZ-104 · 50 items · 90 min · Seuil 700 / 1000"
    case .anim03Mascot34SpeechBubblePop:
      return "SCÉNARIO ARCHITECTURE · Quelle zone DNS privée résout un Blob Storage Private Endpoint ?"
    case .anim04Claude85DrawerPush:
      return "06D · Historique IA (85%) · 06B · Conversation IA Active"
    case .anim05NovaLiveVoicePulse:
      return "✦ NOVA · 🎙️ Nova explique le routage VNet en direct..."
    case .anim06PearsonBarometerFill:
      return "785 / 1000 · ADMIS ✓ · Seuil officiel Pearson VUE : 700 / 1000"
    case .anim07DualCurveAndFitnessRings:
      return "AVEC CERTIGO · 845 / 1000 ✓ · SANS CERTIGO · 580 / 1000"
    case .anim08CelebrationVictoryJump:
      return "🎉 ÉTAPE VALIDÉE · PRÉCISION 94 % · 🔥 SÉRIE 13J"
    }
  }

  public var figmaBeforeNodeId: String {
    switch self {
    case .anim01Tactile3DPress:
      return "165:471"
    case .anim02ApplePayBottomSheet:
      return "165:501"
    case .anim03Mascot34SpeechBubblePop:
      return "165:547"
    case .anim04Claude85DrawerPush:
      return "165:575"
    case .anim05NovaLiveVoicePulse:
      return "165:605"
    case .anim06PearsonBarometerFill:
      return "165:635"
    case .anim07DualCurveAndFitnessRings:
      return "165:667"
    case .anim08CelebrationVictoryJump:
      return "165:697"
    }
  }

  public var figmaAfterNodeId: String {
    switch self {
    case .anim01Tactile3DPress:
      return "165:472"
    case .anim02ApplePayBottomSheet:
      return "165:502"
    case .anim03Mascot34SpeechBubblePop:
      return "165:548"
    case .anim04Claude85DrawerPush:
      return "165:576"
    case .anim05NovaLiveVoicePulse:
      return "165:606"
    case .anim06PearsonBarometerFill:
      return "165:636"
    case .anim07DualCurveAndFitnessRings:
      return "165:668"
    case .anim08CelebrationVictoryJump:
      return "165:698"
    }
  }

  public var figmaBeforeNodeName: String {
    switch self {
    case .anim01Tactile3DPress:
      return "ANIM_01_A · État Initial (Avant Transition) — Pression Tactile 3D Duolingo (Repos 4px ➔ Pressé 1px)"
    case .anim02ApplePayBottomSheet:
      return "ANIM_02_A · État Initial (Avant Transition) — Montée Feuille Apple Pay + Voile 62 % + Blason AZ-104"
    case .anim03Mascot34SpeechBubblePop:
      return "ANIM_03_A · État Initial (Avant Transition) — Apparition Mascotte 3/4 Droite & Bulle Empilée 15px ◀"
    case .anim04Claude85DrawerPush:
      return "ANIM_04_A · État Initial (Avant Transition) — Tiroir Historique IA Push 85 % Style Claude (06B ➔ 06D)"
    case .anim05NovaLiveVoicePulse:
      return "ANIM_05_A · État Initial (Avant Transition) — Orbe Vocal Live Nova 1.0x Pulsant & Onde Sonore (06C)"
    case .anim06PearsonBarometerFill:
      return "ANIM_06_A · État Initial (Avant Transition) — Baromètre Pearson VUE Gradué (0 ➔ 785/1000) & Carrousel ●○○"
    case .anim07DualCurveAndFitnessRings:
      return "ANIM_07_A · État Initial (Avant Transition) — Double Courbe (Avec CertiGo 845 vs Sans 580) & 3 Anneaux"
    case .anim08CelebrationVictoryJump:
      return "ANIM_08_A · État Initial (Avant Transition) — Saut de Victoire Célébration Blason 1A (Écran 19 · +18px)"
    }
  }

  public var figmaAfterNodeName: String {
    switch self {
    case .anim01Tactile3DPress:
      return "ANIM_01_B · État Animé (Après Transition Spring) — Pression Tactile 3D Duolingo (Repos 4px ➔ Pressé 1px)"
    case .anim02ApplePayBottomSheet:
      return "ANIM_02_B · État Animé (Après Transition Spring) — Montée Feuille Apple Pay + Voile 62 % + Blason AZ-104"
    case .anim03Mascot34SpeechBubblePop:
      return "ANIM_03_B · État Animé (Après Transition Spring) — Apparition Mascotte 3/4 Droite & Bulle Empilée 15px ◀"
    case .anim04Claude85DrawerPush:
      return "ANIM_04_B · État Animé (Après Transition Spring) — Tiroir Historique IA Push 85 % Style Claude (06B ➔ 06D)"
    case .anim05NovaLiveVoicePulse:
      return "ANIM_05_B · État Animé (Après Transition Spring) — Orbe Vocal Live Nova 1.0x Pulsant & Onde Sonore (06C)"
    case .anim06PearsonBarometerFill:
      return "ANIM_06_B · État Animé (Après Transition Spring) — Baromètre Pearson VUE Gradué (0 ➔ 785/1000) & Carrousel ●○○"
    case .anim07DualCurveAndFitnessRings:
      return "ANIM_07_B · État Animé (Après Transition Spring) — Double Courbe (Avec CertiGo 845 vs Sans 580) & 3 Anneaux"
    case .anim08CelebrationVictoryJump:
      return "ANIM_08_B · État Animé (Après Transition Spring) — Saut de Victoire Célébration Blason 1A (Écran 19 · +18px)"
    }
  }

  public var title: String {
    switch self {
    case .anim01Tactile3DPress:
      return "Pression Tactile 3D Duolingo (Repos 4px ➔ Pressé 1px)"
    case .anim02ApplePayBottomSheet:
      return "Montée Feuille Apple Pay + Voile 62 % + Blason AZ-104"
    case .anim03Mascot34SpeechBubblePop:
      return "Apparition Mascotte 3/4 Droite & Bulle Empilée 15px ◀"
    case .anim04Claude85DrawerPush:
      return "Tiroir Historique IA Push 85 % Style Claude (06B ➔ 06D)"
    case .anim05NovaLiveVoicePulse:
      return "Orbe Vocal Live Nova 1.0x Pulsant & Onde Sonore (06C)"
    case .anim06PearsonBarometerFill:
      return "Baromètre Pearson VUE Gradué (0 ➔ 785/1000) & Carrousel ●○○"
    case .anim07DualCurveAndFitnessRings:
      return "Double Courbe (Avec CertiGo 845 vs Sans 580) & 3 Anneaux"
    case .anim08CelebrationVictoryJump:
      return "Saut de Victoire Célébration Blason 1A (Écran 19 · +18px)"
    }
  }

  public var figmaSpecSummary: String {
    switch self {
    case .anim01Tactile3DPress:
      return "CUSTOM_SPRING · mass: 1 · stiffness: 600 · damping: 28 · 80ms"
    case .anim02ApplePayBottomSheet:
      return "MOVE_IN + SMART_ANIMATE · stiffness: 340 · damping: 26 · 380ms"
    case .anim03Mascot34SpeechBubblePop:
      return "SMART_ANIMATE · scale 0.86 ➔ 1.0 · stiffness: 380 · damping: 24 · 320ms"
    case .anim04Claude85DrawerPush:
      return "PUSH RIGHT + SMART_ANIMATE · x:-334 ➔ 0 · stiffness: 360 · damping: 28 · 360ms"
    case .anim05NovaLiveVoicePulse:
      return "KEYFRAMES / SMART_ANIMATE · 3 Halos scale 1.0 ➔ 1.28 · 1200ms"
    case .anim06PearsonBarometerFill:
      return "SMART_ANIMATE · Jauge 0 ➔ 220px (Seuil 700 franchi) · stiffness: 280 · damping: 22"
    case .anim07DualCurveAndFitnessRings:
      return "SMART_ANIMATE · Tracé progressif 0% ➔ 100% · stiffness: 260 · damping: 24 · 520ms"
    case .anim08CelebrationVictoryJump:
      return "BOUNCY SPRING · y:168 ➔ 132 + Étoiles · stiffness: 280 · damping: 16 · 480ms"
    }
  }

  public var motionToken: PrismMotionToken {
    switch self {
    case .anim01Tactile3DPress:
      return .quick
    case .anim02ApplePayBottomSheet:
      return .smooth
    case .anim03Mascot34SpeechBubblePop:
      return .snappy
    case .anim04Claude85DrawerPush:
      return .smooth
    case .anim05NovaLiveVoicePulse:
      return .expressive
    case .anim06PearsonBarometerFill:
      return .smooth
    case .anim07DualCurveAndFitnessRings:
      return .smooth
    case .anim08CelebrationVictoryJump:
      return .expressive
    }
  }

  public var hapticToken: PrismHapticToken? {
    switch self {
    case .anim01Tactile3DPress:
      return .selection
    case .anim06PearsonBarometerFill:
      return .correct
    case .anim08CelebrationVictoryJump:
      return .declic
    default:
      return nil
    }
  }

  /// Accessible motion resolution strictly preserving `PrismMotion.resolve(..., reduceMotion: reduceMotion)` invariants (`opacityOnly == true`, `duration <= 0.3`, `curve == .easeOut` when `reduceMotion == true`).
  public func resolved(reduceMotion: Bool) -> PrismResolvedMotion {
    if reduceMotion {
      return PrismMotion.resolve(motionToken, reduceMotion: true)
    }
    let curve: PrismResolvedMotion.Curve = self == .anim05NovaLiveVoicePulse ? .keyframes : .spring
    return PrismResolvedMotion(
      duration: durationSeconds,
      curve: curve,
      opacityOnly: false
    )
  }
}

// MARK: - 2. Page 13 Motion Specification & Before/After Frame Descriptors

public struct CertiGoFigmaLayerTransitionSpec: Codable, Equatable, Hashable, Sendable {
  public let layerName: String
  public let beforeSummary: String
  public let afterSummary: String

  public init(layerName: String, beforeSummary: String, afterSummary: String) {
    self.layerName = layerName
    self.beforeSummary = beforeSummary
    self.afterSummary = afterSummary
  }
}

public struct CertiGoMotionPresetSpec: Identifiable, Codable, Equatable, Hashable, Sendable {
  public var id: String { preset.rawValue }
  public let preset: CertiGoAnimationPresetID
  public let mass: Double
  public let stiffness: Double
  public let damping: Double
  public let durationSeconds: Double
  public let figmaTransitionType: String
  public let figmaBeforeNodeId: String
  public let figmaAfterNodeId: String
  public let figmaBeforeNodeName: String
  public let figmaAfterNodeName: String
  public let stageLayerNames: [String]
  public let canonicalCopyText: String
  public let motionToken: PrismMotionToken

  public init(preset: CertiGoAnimationPresetID) {
    self.preset = preset
    self.mass = preset.mass
    self.stiffness = preset.stiffness
    self.damping = preset.damping
    self.durationSeconds = preset.durationSeconds
    self.figmaTransitionType = preset.figmaTransitionType
    self.figmaBeforeNodeId = preset.figmaBeforeNodeId
    self.figmaAfterNodeId = preset.figmaAfterNodeId
    self.figmaBeforeNodeName = preset.figmaBeforeNodeName
    self.figmaAfterNodeName = preset.figmaAfterNodeName
    self.stageLayerNames = preset.stageLayerNames
    self.canonicalCopyText = preset.canonicalCopyText
    self.motionToken = preset.motionToken
  }

  public func resolved(reduceMotion: Bool) -> PrismResolvedMotion {
    preset.resolved(reduceMotion: reduceMotion)
  }
}

public enum CertiGoPage13LayerMetrics {
  // ANIM_01: M_OPT_CARD, M_CTA_LIP, M_CTA_FACE (offset 6px ➔ 1px)
  public static let anim01LipOffsetBefore: CGFloat = 6
  public static let anim01LipOffsetAfter: CGFloat = 1
  public static let anim01OptionCardYBefore: CGFloat = 80
  public static let anim01OptionCardYAfter: CGFloat = 84

  // ANIM_02: M_DIM_BACKDROP (opacity 0.04 ➔ 0.58), M_APPLE_PAY_SHEET (y: 560 ➔ 140), M_CREST_HALO (100x100)
  public static let anim02BackdropOpacityBefore: Double = 0.04
  public static let anim02BackdropOpacityAfter: Double = 0.58
  public static let anim02SheetYBefore: CGFloat = 560
  public static let anim02SheetYAfter: CGFloat = 140
  public static let anim02CrestHaloSize: CGFloat = 100

  // ANIM_03: M_MASCOT_34 (64x64 ➔ 84x84), M_SPEECH_BUBBLE (190x96 ➔ 233x140)
  public static let anim03MascotSizeBefore: CGFloat = 64
  public static let anim03MascotSizeAfter: CGFloat = 84
  public static let anim03SpeechBubbleWidthBefore: CGFloat = 190
  public static let anim03SpeechBubbleHeightBefore: CGFloat = 96
  public static let anim03SpeechBubbleWidthAfter: CGFloat = 233
  public static let anim03SpeechBubbleHeightAfter: CGFloat = 140

  // ANIM_04: M_CLAUDE_DRAWER (x: -260 ➔ 0, w: 264), M_MAIN_CHAT (x: 16 ➔ 276)
  public static let anim04DrawerXBefore: CGFloat = -260
  public static let anim04DrawerXAfter: CGFloat = 0
  public static let anim04DrawerWidth: CGFloat = 264
  public static let anim04MainChatXBefore: CGFloat = 16
  public static let anim04MainChatXAfter: CGFloat = 276

  // ANIM_05: M_VOICE_HALO_OUTER (160x160 ➔ 240x240), M_VOICE_HALO_MID (128x128 ➔ 180x180), M_VOICE_CORE (100x100)
  public static let anim05OuterHaloBefore: CGFloat = 160
  public static let anim05OuterHaloAfter: CGFloat = 240
  public static let anim05MidHaloBefore: CGFloat = 128
  public static let anim05MidHaloAfter: CGFloat = 180
  public static let anim05CoreSize: CGFloat = 100

  // ANIM_06: M_BAROMETER_CARD, M_BAROMETER_TRACK (w: 289), M_BAROMETER_FILL (w: 16 ➔ 226)
  public static let anim06TrackWidth: CGFloat = 289
  public static let anim06FillWidthBefore: CGFloat = 16
  public static let anim06FillWidthAfter: CGFloat = 226
  public static let anim06PassingThreshold: Int = 700
  public static let anim06TargetScore: Int = 785
  public static let anim06MaxScore: Int = 1000

  // ANIM_07: M_DUAL_CURVE_BOX, M_CURVE_WITH_CERTIGO (w: 48 ➔ 289 · 845/1000), M_CURVE_WITHOUT_CERTIGO (w: 48 ➔ 190 · 580/1000)
  public static let anim07CurveWidthBefore: CGFloat = 48
  public static let anim07WithCertiGoWidthAfter: CGFloat = 289
  public static let anim07WithoutCertiGoWidthAfter: CGFloat = 190
  public static let anim07WithCertiGoScore: Int = 845
  public static let anim07WithoutCertiGoScore: Int = 580

  // ANIM_08: M_CELEB_MASCOT (y: 140 ➔ 64), M_CELEB_STATS (y: 310 ➔ 240)
  public static let anim08MascotYBefore: CGFloat = 140
  public static let anim08MascotYAfter: CGFloat = 64
  public static let anim08StatsYBefore: CGFloat = 310
  public static let anim08StatsYAfter: CGFloat = 240
}

public struct CertiGoPage13AnimationFrameDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
  public var id: String { frameCode }
  public let frameCode: String
  public let preset: CertiGoAnimationPresetID
  public let isAfterTransitionState: Bool
  public let nodeId: String
  public let nodeName: String
  public let figmaPageId: String
  public let canvasWidth: Int
  public let canvasHeight: Int

  public init(
    frameCode: String,
    preset: CertiGoAnimationPresetID,
    isAfterTransitionState: Bool,
    nodeId: String,
    nodeName: String,
    figmaPageId: String = CertiGoMotionSpecCatalog.figmaPageId,
    canvasWidth: Int = 393,
    canvasHeight: Int = 852
  ) {
    self.frameCode = frameCode
    self.preset = preset
    self.isAfterTransitionState = isAfterTransitionState
    self.nodeId = nodeId
    self.nodeName = nodeName
    self.figmaPageId = figmaPageId
    self.canvasWidth = canvasWidth
    self.canvasHeight = canvasHeight
  }
}

public enum CertiGoMotionSpecCatalog {
  public static let figmaFileKey: String = "ECDZfufGwX3hX40Khntnw2"
  public static let figmaPageId: String = "165:470"
  public static let figmaPageTitle: String =
    "13 · Système d'Animations, Transitions Spring & Micro-Interactions (8 Paires Avant/Après)"
  public static let expectedPresetCount: Int = 8
  public static let expectedFrameCount: Int = 16

  public static let allPresets: [CertiGoAnimationPresetID] = CertiGoAnimationPresetID.allCases

  public static let allSpecs: [CertiGoMotionPresetSpec] = CertiGoAnimationPresetID.allCases.map {
    CertiGoMotionPresetSpec(preset: $0)
  }

  public static let allPage13Frames: [CertiGoPage13AnimationFrameDescriptor] =
    CertiGoAnimationPresetID.allCases.flatMap { preset in
      [
        CertiGoPage13AnimationFrameDescriptor(
          frameCode: "\(preset.rawValue)_A",
          preset: preset,
          isAfterTransitionState: false,
          nodeId: preset.figmaBeforeNodeId,
          nodeName: preset.figmaBeforeNodeName
        ),
        CertiGoPage13AnimationFrameDescriptor(
          frameCode: "\(preset.rawValue)_B",
          preset: preset,
          isAfterTransitionState: true,
          nodeId: preset.figmaAfterNodeId,
          nodeName: preset.figmaAfterNodeName
        ),
      ]
    }

  public static func spec(for preset: CertiGoAnimationPresetID) -> CertiGoMotionPresetSpec {
    CertiGoMotionPresetSpec(preset: preset)
  }

  public static func spec(forCode code: String) -> CertiGoMotionPresetSpec? {
    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard let preset = CertiGoAnimationPresetID(rawValue: normalized) else { return nil }
    return CertiGoMotionPresetSpec(preset: preset)
  }

  public static func frame(forCode frameCode: String) -> CertiGoPage13AnimationFrameDescriptor? {
    let normalized = frameCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return allPage13Frames.first { $0.frameCode.uppercased() == normalized }
  }

  public static func frame(forNodeId nodeId: String) -> CertiGoPage13AnimationFrameDescriptor? {
    let trimmed = nodeId.trimmingCharacters(in: .whitespacesAndNewlines)
    return allPage13Frames.first { $0.nodeId == trimmed }
  }

  public static func verifyAllInvariants() -> Bool {
    guard allPresets.count == expectedPresetCount else { return false }
    guard allSpecs.count == expectedPresetCount else { return false }
    guard allPage13Frames.count == expectedFrameCount else { return false }
    guard Set(allPage13Frames.map(\.nodeId)).count == expectedFrameCount else { return false }
    guard Set(allPage13Frames.map(\.frameCode)).count == expectedFrameCount else { return false }

    for preset in allPresets {
      guard preset.mass == 1.0 else { return false }
      guard preset.stiffness > 0, preset.damping > 0 else { return false }
      guard preset.durationSeconds > 0, preset.durationSeconds <= 1.2 else { return false }
      guard !preset.figmaTransitionType.isEmpty else { return false }
      guard preset.figmaBeforeNodeName.hasPrefix("\(preset.rawValue)_A") else { return false }
      guard preset.figmaAfterNodeName.hasPrefix("\(preset.rawValue)_B") else { return false }

      let reduced = preset.resolved(reduceMotion: true)
      guard reduced.opacityOnly else { return false }
      guard reduced.duration <= 0.3 else { return false }
      guard reduced.curve == .easeOut else { return false }

      let normal = preset.resolved(reduceMotion: false)
      guard !normal.opacityOnly else { return false }
      guard normal.duration == preset.durationSeconds else { return false }
    }
    return true
  }
}

// MARK: - 3. SwiftUI Modifiers & Reusable Components for Page 13 Animations (ANIM_01 .. ANIM_08)

#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  /// `ANIM_01` — Pression tactile 3D Duolingo : compression de la lèvre 3D (`PrismSize.lipDepth` ➔ `PrismBorder.hairline`) + retour haptique `PrismHapticToken.selection`.
  public struct CertiGo3DPressButtonModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let isPressed: Bool
    public let lipColorRole: PrismColorRole
    public let cornerRadius: CGFloat
    public let hapticToken: PrismHapticToken

    public init(
      isPressed: Bool,
      lipColorRole: PrismColorRole = .accentFill,
      cornerRadius: CGFloat = PrismRadius.button,
      hapticToken: PrismHapticToken = .selection
    ) {
      self.isPressed = isPressed
      self.lipColorRole = lipColorRole
      self.cornerRadius = cornerRadius
      self.hapticToken = hapticToken
    }

    public var currentLipDepth: CGFloat {
      isPressed ? PrismBorder.hairline : PrismSize.lipDepth
    }

    public func verticalTravelOffset(reduceMotion: Bool) -> CGFloat {
      if reduceMotion {
        return .zero
      }
      return isPressed ? (PrismSize.lipDepth - PrismBorder.hairline) : .zero
    }

    public func body(content: Content) -> some View {
      let motion = PrismMotion.resolve(.quick, reduceMotion: reduceMotion)
      content
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(PrismColor.color(lipColorRole))
            .offset(y: currentLipDepth)
        )
        .offset(y: verticalTravelOffset(reduceMotion: reduceMotion))
        .opacity(reduceMotion && isPressed ? 0.88 : 1.0)
        .animation(motion.animation, value: isPressed)
        .sensoryFeedback(hapticToken.sensoryFeedback, trigger: isPressed)
    }
  }

  /// `ANIM_02` — Montée de la feuille flottante Apple Pay + voile assombri (`0.58` / `0.62`).
  public struct CertiGoBottomSheetDimOverlayModifier<SheetContent: View>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var standardDimOpacity: Double { 0.58 }
    public static var errorDimOpacity: Double { 0.62 }

    public let isPresented: Bool
    public let dimOpacity: Double
    public let onDismiss: () -> Void
    private let sheetContent: () -> SheetContent

    public init(
      isPresented: Bool,
      dimOpacity: Double = Self.errorDimOpacity,
      onDismiss: @escaping () -> Void = {},
      @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
      self.isPresented = isPresented
      self.dimOpacity = min(max(dimOpacity, Self.standardDimOpacity), Self.errorDimOpacity)
      self.onDismiss = onDismiss
      self.sheetContent = sheetContent
    }

    public func effectiveBackdropOpacity() -> Double {
      isPresented ? dimOpacity : 0.0
    }

    public func sheetVerticalOffset(reduceMotion: Bool) -> CGFloat {
      if reduceMotion || isPresented {
        return .zero
      }
      return PrismSpacing.giant
    }

    public func body(content: Content) -> some View {
      let motion = PrismMotion.resolve(.smooth, reduceMotion: reduceMotion)
      ZStack(alignment: .bottom) {
        content

        if isPresented {
          PrismColor.textPrimary.opacity(effectiveBackdropOpacity())
            .ignoresSafeArea()
            .onTapGesture {
              onDismiss()
            }

          sheetContent()
            .padding(PrismSpacing.l)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.surface)
            )
            .overlay(
              RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .strokeBorder(PrismColor.separator, lineWidth: PrismBorder.standard)
            )
            .padding(.horizontal, PrismSpacing.m)
            .padding(.bottom, PrismSpacing.s)
            .offset(y: sheetVerticalOffset(reduceMotion: reduceMotion))
            .opacity(isPresented ? 1.0 : 0.0)
        }
      }
      .animation(motion.animation, value: isPresented)
    }
  }

  /// `ANIM_03` — Apparition de la mascotte 3/4 droite et de la bulle empilée `15pt` (`scale 0.86 ➔ 1.0`).
  public struct CertiGoMascotBubbleEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var initialScale: CGFloat { 0.86 }
    public static var settledScale: CGFloat { 1.0 }
    public static var questionFontSizePoints: CGFloat { 15.0 }

    public let isVisible: Bool

    public init(isVisible: Bool = true) {
      self.isVisible = isVisible
    }

    public func currentScale(reduceMotion: Bool) -> CGFloat {
      if reduceMotion {
        return Self.settledScale
      }
      return isVisible ? Self.settledScale : Self.initialScale
    }

    public func body(content: Content) -> some View {
      let motion = PrismMotion.resolve(.snappy, reduceMotion: reduceMotion)
      content
        .scaleEffect(currentScale(reduceMotion: reduceMotion))
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(motion.animation, value: isVisible)
    }
  }

  /// `ANIM_04` — Tiroir latéral d'historique IA `85 %` (`PrismSize.drawerWidth` = `334pt`) poussant l'écran principal (`06B ➔ 06D`).
  public struct CertiGoDrawerPushContainerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var drawerCoverageRatio: Double { 0.85 }
    public static var defaultDrawerWidth: CGFloat { PrismSize.drawerWidth }

    public let isOpen: Bool
    public let drawerWidth: CGFloat

    public init(
      isOpen: Bool,
      drawerWidth: CGFloat = PrismSize.drawerWidth
    ) {
      self.isOpen = isOpen
      self.drawerWidth = drawerWidth
    }

    public func drawerHorizontalOffset(reduceMotion: Bool) -> CGFloat {
      if reduceMotion {
        return .zero
      }
      return isOpen ? .zero : -drawerWidth
    }

    public func mainContentHorizontalOffset(reduceMotion: Bool) -> CGFloat {
      if reduceMotion {
        return .zero
      }
      return isOpen ? drawerWidth : .zero
    }

    public func body(content: Content) -> some View {
      let motion = PrismMotion.resolve(.smooth, reduceMotion: reduceMotion)
      content
        .offset(x: mainContentHorizontalOffset(reduceMotion: reduceMotion))
        .opacity(reduceMotion && isOpen ? 0.92 : 1.0)
        .animation(motion.animation, value: isOpen)
    }
  }

  /// `ANIM_05` — Orbe vocal Live `Nova` `1,0×` avec 3 anneaux concentriques (`PrismSize.ringOuter`, `PrismSize.ringMiddle`, `PrismSize.ringInner`).
  public struct CertiGoNovaVoicePulseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var idleScale: CGFloat { 1.0 }
    public static var activeOuterScale: CGFloat { 1.28 }
    public static var activeMiddleScale: CGFloat { 1.16 }

    public let isPulsing: Bool
    public let voiceName: String
    public let speedBadgeText: String
    public let transcriptStatusText: String

    public init(
      isPulsing: Bool = true,
      voiceName: String = "NOVA",
      speedBadgeText: String = "1,0×",
      transcriptStatusText: String = "🎙️ Nova explique le routage VNet en direct..."
    ) {
      self.isPulsing = isPulsing
      self.voiceName = voiceName
      self.speedBadgeText = speedBadgeText
      self.transcriptStatusText = transcriptStatusText
    }

    public func outerRingScale(reduceMotion: Bool) -> CGFloat {
      if reduceMotion || !isPulsing {
        return Self.idleScale
      }
      return Self.activeOuterScale
    }

    public func middleRingScale(reduceMotion: Bool) -> CGFloat {
      if reduceMotion || !isPulsing {
        return Self.idleScale
      }
      return Self.activeMiddleScale
    }

    public var body: some View {
      let motion = PrismMotion.resolve(.expressive, reduceMotion: reduceMotion)
      VStack(spacing: PrismSpacing.m) {
        ZStack {
          Circle()
            .fill(PrismRegion.ai.color.opacity(isPulsing ? 0.16 : 0.08))
            .frame(width: PrismSize.ringOuter, height: PrismSize.ringOuter)
            .scaleEffect(outerRingScale(reduceMotion: reduceMotion))

          Circle()
            .fill(PrismColor.accent.opacity(isPulsing ? 0.24 : 0.12))
            .frame(width: PrismSize.ringMiddle, height: PrismSize.ringMiddle)
            .scaleEffect(middleRingScale(reduceMotion: reduceMotion))

          Circle()
            .fill(
              LinearGradient(
                colors: [PrismColor.accent, PrismRegion.ai.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: PrismSize.ringInner, height: PrismSize.ringInner)
            .overlay(
              VStack(spacing: PrismSpacing.xxs) {
                Text(verbatim: "✦ \(voiceName)")
                  .prismTextStyle(.caption)
                  .foregroundStyle(PrismColor.onAccent)
                Text(verbatim: speedBadgeText)
                  .prismTextStyle(.footnote)
                  .foregroundStyle(PrismColor.onAccent.opacity(0.9))
              }
            )
        }
        .animation(motion.animation, value: isPulsing)

        PrismText(
          text: transcriptStatusText,
          style: .subheadline,
          role: .textPrimary
        )
      }
      .padding(PrismSpacing.m)
      .background(
        RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
          .fill(PrismColor.surface)
      )
      .accessibilityElement(children: .combine)
    }
  }

  /// `ANIM_06` — Jauge graduée Pearson VUE (`0 ── Seuil 700 ── 785 / 1000`) avec franchissement du seuil officiel.
  public struct CertiGoAnimatedBarometerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let scaledScore: Int
    public let passingThreshold: Int
    public let maxScore: Int
    public let isAnimatedToTarget: Bool

    public init(
      scaledScore: Int = 785,
      passingThreshold: Int = 700,
      maxScore: Int = 1000,
      isAnimatedToTarget: Bool = true
    ) {
      self.maxScore = max(100, maxScore)
      self.passingThreshold = min(max(0, passingThreshold), self.maxScore)
      self.scaledScore = min(max(0, scaledScore), self.maxScore)
      self.isAnimatedToTarget = isAnimatedToTarget
    }

    public var isPassed: Bool {
      scaledScore >= passingThreshold
    }

    public var displayedScore: Int {
      isAnimatedToTarget ? scaledScore : 0
    }

    public var graduatedScaleLabel: String {
      "0 ── Seuil \(passingThreshold) ── \(scaledScore) / \(maxScore)"
    }

    public var headlineVerdictText: String {
      if !isAnimatedToTarget {
        return "0 / \(maxScore) · CALCUL EN COURS..."
      }
      return isPassed
        ? "\(scaledScore) / \(maxScore) · ADMIS ✓"
        : "\(scaledScore) / \(maxScore) · SOUS LE SEUIL \(passingThreshold)"
    }

    public var normalizedProgress: Double {
      guard isAnimatedToTarget else { return 0.0 }
      return Double(scaledScore) / Double(maxScore)
    }

    public var body: some View {
      let motion = PrismMotion.resolve(.smooth, reduceMotion: reduceMotion)
      VStack(alignment: .leading, spacing: PrismSpacing.s) {
        HStack {
          PrismText(
            text: headlineVerdictText,
            style: .headline,
            role: isPassed ? .positive : .caution
          )
          Spacer(minLength: PrismSpacing.xs)
          PrismBadge(
            configuration: PrismBadgeConfiguration(
              text: "● ○ ○",
              semantics: isPassed ? .positive : .caution
            )
          )
        }

        PrismText(
          text: graduatedScaleLabel,
          style: .codeSmall,
          role: .accent
        )

        HStack(spacing: PrismSpacing.xs) {
          PrismProgressBar(
            configuration: PrismProgressBarConfiguration(
              progress: normalizedProgress,
              colorRole: isPassed ? .positive : .caution,
              label: "Seuil officiel Pearson VUE : \(passingThreshold) / \(maxScore)"
            )
          )
          Rectangle()
            .fill(PrismColor.textPrimary)
            .frame(
              width: PrismSize.barometerThresholdWidth,
              height: PrismSize.barometerThresholdHeight
            )
        }
        .animation(motion.animation, value: isAnimatedToTarget)
        .animation(motion.animation, value: scaledScore)
      }
      .padding(PrismSpacing.m)
      .background(
        RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
          .fill(PrismColor.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
          .strokeBorder(PrismColor.separator, lineWidth: PrismBorder.regular)
      )
    }
  }

  /// `ANIM_07` — Double courbe de progression (`Avec CertiGo 845 / 1000 ✓` vs `Sans CertiGo 580 / 1000`) et 3 anneaux d'activité.
  public struct CertiGoDualCurveAndFitnessRingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let withCertiGoScore: Int
    public let withoutCertiGoScore: Int
    public let maxScore: Int
    public let isExpanded: Bool

    public init(
      withCertiGoScore: Int = 845,
      withoutCertiGoScore: Int = 580,
      maxScore: Int = 1000,
      isExpanded: Bool = true
    ) {
      self.maxScore = max(100, maxScore)
      self.withCertiGoScore = min(max(0, withCertiGoScore), self.maxScore)
      self.withoutCertiGoScore = min(max(0, withoutCertiGoScore), self.maxScore)
      self.isExpanded = isExpanded
    }

    public var withCertiGoLabel: String {
      "AVEC CERTIGO · \(withCertiGoScore) / \(maxScore) ✓"
    }

    public var withoutCertiGoLabel: String {
      "SANS CERTIGO · \(withoutCertiGoScore) / \(maxScore)"
    }

    public var body: some View {
      let motion = PrismMotion.resolve(.smooth, reduceMotion: reduceMotion)
      VStack(alignment: .leading, spacing: PrismSpacing.m) {
        HStack(spacing: PrismSpacing.m) {
          ZStack {
            Circle()
              .stroke(PrismColor.positive.opacity(0.25), lineWidth: PrismBorder.strong)
              .frame(width: PrismSize.ringOuter, height: PrismSize.ringOuter)
            Circle()
              .stroke(PrismColor.accent.opacity(0.35), lineWidth: PrismBorder.strong)
              .frame(width: PrismSize.ringMiddle, height: PrismSize.ringMiddle)
            Circle()
              .stroke(PrismRegion.ai.color.opacity(0.45), lineWidth: PrismBorder.strong)
              .frame(width: PrismSize.ringInner, height: PrismSize.ringInner)
          }

          VStack(alignment: .leading, spacing: PrismSpacing.s) {
            PrismBadge(
              configuration: PrismBadgeConfiguration(
                text: withCertiGoLabel,
                semantics: .positive
              )
            )
            PrismProgressBar(
              configuration: PrismProgressBarConfiguration(
                progress: isExpanded ? Double(withCertiGoScore) / Double(maxScore) : 0.15,
                colorRole: .positive
              )
            )
            PrismBadge(
              configuration: PrismBadgeConfiguration(
                text: withoutCertiGoLabel,
                semantics: .neutral
              )
            )
            PrismProgressBar(
              configuration: PrismProgressBarConfiguration(
                progress: isExpanded ? Double(withoutCertiGoScore) / Double(maxScore) : 0.15,
                colorRole: .textSecondary
              )
            )
          }
        }
        .animation(motion.animation, value: isExpanded)
      }
      .padding(PrismSpacing.m)
      .background(
        RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
          .fill(PrismColor.surface)
      )
    }
  }

  /// `ANIM_08` — Saut de victoire Célébration `Blason 1A` (Écran 19 · `+18pt`) respectant `Calm Mode` et `Reduce Motion`.
  public struct CertiGoCelebrationJumpModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static var celebrationJumpPoints: CGFloat { PrismSize.celebrationJumpOffset }

    public let isCelebrating: Bool
    public let celebrationLevel: PrismCelebrationLevel
    public let calmMode: Bool

    public init(
      isCelebrating: Bool = true,
      celebrationLevel: PrismCelebrationLevel = .milestone,
      calmMode: Bool = false
    ) {
      self.isCelebrating = isCelebrating
      self.celebrationLevel = celebrationLevel
      self.calmMode = calmMode
    }

    public var effectiveCelebrationLevel: PrismCelebrationLevel {
      celebrationLevel.resolved(calmMode: calmMode)
    }

    public func verticalJumpOffset(reduceMotion: Bool) -> CGFloat {
      if reduceMotion || calmMode || !isCelebrating {
        return .zero
      }
      return -Self.celebrationJumpPoints
    }

    public func body(content: Content) -> some View {
      let motion = PrismMotion.resolve(.expressive, reduceMotion: reduceMotion)
      content
        .offset(y: verticalJumpOffset(reduceMotion: reduceMotion))
        .opacity(isCelebrating ? 1.0 : 0.85)
        .animation(motion.animation, value: isCelebrating)
        .sensoryFeedback(PrismHapticToken.declic.sensoryFeedback, trigger: isCelebrating)
    }
  }

  // MARK: - 4. View Convenience Extensions & Page 13 Master Preview Screen

  extension View {
    public func certiGo3DPressButton(
      isPressed: Bool,
      lipColorRole: PrismColorRole = .accentFill,
      cornerRadius: CGFloat = PrismRadius.button,
      hapticToken: PrismHapticToken = .selection
    ) -> some View {
      modifier(
        CertiGo3DPressButtonModifier(
          isPressed: isPressed,
          lipColorRole: lipColorRole,
          cornerRadius: cornerRadius,
          hapticToken: hapticToken
        )
      )
    }

    public func certiGoBottomSheetDimOverlay<SheetContent: View>(
      isPresented: Bool,
      dimOpacity: Double = CertiGoBottomSheetDimOverlayModifier<SheetContent>.errorDimOpacity,
      onDismiss: @escaping () -> Void = {},
      @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) -> some View {
      modifier(
        CertiGoBottomSheetDimOverlayModifier(
          isPresented: isPresented,
          dimOpacity: dimOpacity,
          onDismiss: onDismiss,
          sheetContent: sheetContent
        )
      )
    }

    public func certiGoMascotBubbleEntrance(isVisible: Bool = true) -> some View {
      modifier(CertiGoMascotBubbleEntranceModifier(isVisible: isVisible))
    }

    public func certiGoDrawerPushContainer(
      isOpen: Bool,
      drawerWidth: CGFloat = PrismSize.drawerWidth
    ) -> some View {
      modifier(CertiGoDrawerPushContainerModifier(isOpen: isOpen, drawerWidth: drawerWidth))
    }

    public func certiGoCelebrationJump(
      isCelebrating: Bool = true,
      celebrationLevel: PrismCelebrationLevel = .milestone,
      calmMode: Bool = false
    ) -> some View {
      modifier(
        CertiGoCelebrationJumpModifier(
          isCelebrating: isCelebrating,
          celebrationLevel: celebrationLevel,
          calmMode: calmMode
        )
      )
    }
  }

  /// Master interactive showcase screen for Figma Pro Page 13 (`165:470`) rendering Before (`État A`) and After (`État B`) states across all 8 presets.
  public struct CertiGoPage13MotionShowcaseScreen: View {
    public let preset: CertiGoAnimationPresetID
    public let isAfterTransitionState: Bool
    public let calmMode: Bool

    public init(
      preset: CertiGoAnimationPresetID = .anim01Tactile3DPress,
      isAfterTransitionState: Bool = true,
      calmMode: Bool = false
    ) {
      self.preset = preset
      self.isAfterTransitionState = isAfterTransitionState
      self.calmMode = calmMode
    }

    public var stateBadgeText: String {
      isAfterTransitionState
        ? "\(preset.rawValue) · ÉTAT B (APRÈS SMART ANIMATE) ✓"
        : "\(preset.rawValue) · ÉTAT A (AVANT — CLIQUER POUR ANIMER)"
    }

    public var footerActionText: String {
      isAfterTransitionState
        ? "↺ CLIQUER POUR REJOUER LA TRANSITION SPRING"
        : "▶ CLIQUER POUR TESTER L'ANIMATION SMART ANIMATE"
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: PrismSpacing.m) {
        PrismCard(variant: .standard) {
          VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            PrismBadge(
              configuration: PrismBadgeConfiguration(
                text: stateBadgeText,
                semantics: isAfterTransitionState ? .positive : .accent
              )
            )
            PrismText(text: preset.title, style: .headline)
            PrismText(
              text: preset.figmaSpecSummary,
              style: .codeSmall,
              role: .textSecondary
            )
          }
        }

        stageView

        Spacer(minLength: PrismSpacing.xs)

        PrismCard(variant: .standard) {
          PrismText(
            text: footerActionText,
            style: .callout,
            role: isAfterTransitionState ? .positive : .accent
          )
        }
      }
      .padding(PrismSpacing.l)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(PrismColor.canvas)
    }

    @ViewBuilder
    private var stageView: some View {
      switch preset {
      case .anim01Tactile3DPress:
        PrismCard(variant: .standard) {
          VStack(alignment: .leading, spacing: PrismSpacing.m) {
            PrismText(text: "A · privatelink.blob.core.windows.net", style: .subheadline)
            PrismText(
              text: isAfterTransitionState
                ? "✓ BOUTON 3D ENFONCÉ (OFFSET 1PX + HAPTIQUE)"
                : "🚀 APPUYER SUR LE BOUTON 3D (OFFSET 6PX)",
              style: .callout,
              role: .onAccent
            )
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: PrismRadius.button, style: .continuous)
                .fill(PrismColor.accent)
            )
            .certiGo3DPressButton(isPressed: isAfterTransitionState)
          }
        }

      case .anim02ApplePayBottomSheet:
        PrismCard(variant: .hero) {
          VStack(spacing: PrismSpacing.s) {
            CertiGoOfficialCrestView(routeCode: "AZ-104", size: PrismSize.crestHero)
            PrismText(text: "Examen Blanc AZ-104", style: .title3)
            PrismText(
              text: "50 items · 90 min · Seuil 700 / 1000",
              style: .subheadline,
              role: .textSecondary
            )
          }
        }

      case .anim03Mascot34SpeechBubblePop:
        CertiGoSpeechBubbleHeaderView(
          region: .network,
          badgeText: "SCÉNARIO ARCHITECTURE",
          questionText: "Quelle zone DNS privée résout un Blob Storage Private Endpoint ?"
        )
        .certiGoMascotBubbleEntrance(isVisible: isAfterTransitionState)

      case .anim04Claude85DrawerPush:
        PrismCard(variant: .standard) {
          VStack(alignment: .leading, spacing: PrismSpacing.s) {
            PrismText(text: "06D · Historique IA (85%)", style: .headline)
            PrismText(
              text: "• Private Endpoint vs Service Endpoint • Rôles RBAC & PIM Just-In-Time • Architecture Claude 4 & MCP",
              style: .subheadline,
              role: .textSecondary
            )
          }
        }
        .certiGoDrawerPushContainer(isOpen: isAfterTransitionState)

      case .anim05NovaLiveVoicePulse:
        CertiGoNovaVoicePulseView(
          isPulsing: isAfterTransitionState,
          voiceName: "NOVA",
          speedBadgeText: "1,0×",
          transcriptStatusText: isAfterTransitionState
            ? "🎙️ Nova explique le routage VNet en direct..."
            : "🎙️ En écoute (1,0× · Audio arrière-plan actif)"
        )

      case .anim06PearsonBarometerFill:
        CertiGoAnimatedBarometerView(
          scaledScore: 785,
          passingThreshold: 700,
          maxScore: 1000,
          isAnimatedToTarget: isAfterTransitionState
        )

      case .anim07DualCurveAndFitnessRings:
        CertiGoDualCurveAndFitnessRingsView(
          withCertiGoScore: 845,
          withoutCertiGoScore: 580,
          maxScore: 1000,
          isExpanded: isAfterTransitionState
        )

      case .anim08CelebrationVictoryJump:
        PrismCard(variant: .hero) {
          VStack(spacing: PrismSpacing.m) {
            CertiGoMascotView(pose: .angleFrontCelebration, size: PrismSize.mascotHero)
              .certiGoCelebrationJump(
                isCelebrating: isAfterTransitionState,
                celebrationLevel: .milestone,
                calmMode: calmMode
              )
            PrismText(
              text: isAfterTransitionState
                ? "🎉 ÉTAPE VALIDÉE · PRÉCISION 94 % · 🔥 SÉRIE 13J"
                : "Validation de l'étape en cours...",
              style: .subheadline
            )
          }
        }
      }
    }
  }
#endif
