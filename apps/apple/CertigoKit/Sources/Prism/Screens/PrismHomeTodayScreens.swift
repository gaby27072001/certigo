import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Today Screen Model (S-10, §7, §14, §15 NS-2, §29)

public struct TodaySessionAtomSummary: Codable, Equatable, Hashable, Sendable {
    public let dueRecallsCount: Int
    public let newConceptsCount: Int
    public let recommendedConceptTitle: String
    public let recommendedProduct: BrandProductID

    public init(
        dueRecallsCount: Int,
        newConceptsCount: Int,
        recommendedConceptTitle: String,
        recommendedProduct: BrandProductID = .microsoftAzure
    ) {
        self.dueRecallsCount = max(0, dueRecallsCount)
        self.newConceptsCount = max(0, newConceptsCount)
        self.recommendedConceptTitle = recommendedConceptTitle
        self.recommendedProduct = recommendedProduct
    }

    public var compositionSummaryText: String {
        "\(dueRecallsCount) rappels · \(newConceptsCount) nouveau concept"
    }
}

public struct TodayDailySituationSummary: Codable, Equatable, Hashable, Sendable {
    public let situationId: String
    public let title: String
    public let product: BrandProductID
    public let isCompletedToday: Bool

    public init(
        situationId: String,
        title: String,
        product: BrandProductID,
        isCompletedToday: Bool = false
    ) {
        self.situationId = situationId
        self.title = title
        self.product = product
        self.isCompletedToday = isCompletedToday
    }
}

public enum TodayScreenState: Equatable, Sendable {
    case loading(elapsedSeconds: Double)
    case empty(PrismEmptyStateModel)
    case error(PrismErrorStateModel)
    case content
}

public struct TodayScreenModel: Equatable, Sendable {
    public let state: TodayScreenState
    public let suggestedLength: PrismSessionLength
    public var selectedLength: PrismSessionLength
    public let composition: TodaySessionAtomSummary
    public let activeRouteCode: String?
    public let activeRouteTitle: String?
    public let dailySituation: TodayDailySituationSummary
    public let rhythm: PrismRhythmWeekModel
    public let memoryAnchoredCount: Int
    public let memoryDueSoonCount: Int
    public let interruptedSession: InterruptedSessionAccessory?
    public let offlineBanner: PrismOfflineBannerModel?
    public let isGuestMode: Bool
    public let isWelcomeBackState: Bool
    public let tomorrowPreviewText: String

    public init(
        state: TodayScreenState = .content,
        suggestedLength: PrismSessionLength = .standard,
        selectedLength: PrismSessionLength? = nil,
        composition: TodaySessionAtomSummary,
        activeRouteCode: String? = "AZ-900",
        activeRouteTitle: String? = "Microsoft Azure Fundamentals",
        dailySituation: TodayDailySituationSummary,
        rhythm: PrismRhythmWeekModel,
        memoryAnchoredCount: Int = 12,
        memoryDueSoonCount: Int = 4,
        interruptedSession: InterruptedSessionAccessory? = nil,
        offlineBanner: PrismOfflineBannerModel? = nil,
        isGuestMode: Bool = false,
        isWelcomeBackState: Bool = false,
        tomorrowPreviewText: String = "Demain : 4 rappels planifiés pour consolider ton ancrage."
    ) {
        self.state = state
        self.suggestedLength = suggestedLength
        self.selectedLength = selectedLength ?? suggestedLength
        self.composition = composition
        self.activeRouteCode = activeRouteCode
        self.activeRouteTitle = activeRouteTitle
        self.dailySituation = dailySituation
        self.rhythm = rhythm
        self.memoryAnchoredCount = max(0, memoryAnchoredCount)
        self.memoryDueSoonCount = max(0, memoryDueSoonCount)
        self.interruptedSession = interruptedSession
        self.offlineBanner = offlineBanner
        self.isGuestMode = isGuestMode
        self.isWelcomeBackState = isWelcomeBackState
        self.tomorrowPreviewText = tomorrowPreviewText
    }

    /// §7 & §15 NS-2: Single primary action on Today ("Reprendre la séance" or "Commencer la séance").
    public var primaryActionTitle: String {
        if interruptedSession != nil {
            return "Reprendre la séance"
        }
        return "Commencer la séance"
    }

    public var activeRouteProductID: BrandProductID {
        BrandRegistry.productID(forTrackCode: activeRouteCode ?? "AZ-900")
    }

    /// §15 NS-2: VoiceOver summary per card so the learner hears the complete session context at once.
    public var sessionCardVoiceOverSummary: String {
        "\(primaryActionTitle), durée \(selectedLength.defaultMinutes) minutes, \(composition.compositionSummaryText), sujet \(composition.recommendedConceptTitle)"
    }
}

// MARK: - 2. Catalog Explorer Model (S-46, §14, §22A.5)

public struct CatalogRouteItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let officialTitle: String
    public let region: PrismRegion
    public let product: BrandProductID
    public let availablePracticeCount: Int
    public let isConfirmedActiveGoal: Bool

    public init(
        id: String,
        code: String,
        officialTitle: String,
        region: PrismRegion,
        product: BrandProductID? = nil,
        availablePracticeCount: Int = 12,
        isConfirmedActiveGoal: Bool = false
    ) {
        self.id = id
        self.code = code
        self.officialTitle = officialTitle
        self.region = region
        self.product = product ?? BrandRegistry.productID(forTrackCode: code)
        self.availablePracticeCount = max(0, availablePracticeCount)
        self.isConfirmedActiveGoal = isConfirmedActiveGoal
    }
}

public struct CatalogExplorerModel: Equatable, Sendable {
    public let routes: [CatalogRouteItem]
    public var selectedRegion: PrismRegion?
    public var searchQuery: String
    public var onlyWithAvailableExercises: Bool

    public init(
        routes: [CatalogRouteItem],
        selectedRegion: PrismRegion? = nil,
        searchQuery: String = "",
        onlyWithAvailableExercises: Bool = false
    ) {
        self.routes = routes
        self.selectedRegion = selectedRegion
        self.searchQuery = searchQuery
        self.onlyWithAvailableExercises = onlyWithAvailableExercises
    }

    public var filteredRoutes: [CatalogRouteItem] {
        routes.filter { item in
            if let selectedRegion, item.region != selectedRegion {
                return false
            }
            if onlyWithAvailableExercises && item.availablePracticeCount == 0 {
                return false
            }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return true }
            return item.code.lowercased().contains(trimmed)
                || item.officialTitle.lowercased().contains(trimmed)
        }
    }
}

// MARK: - 3. Ensemble Minimal Model (S-60, §10, §15 NS-12)

public struct EnsembleMinimalModel: Codable, Equatable, Hashable, Sendable {
    public let isProfilePrivateByDefault: Bool
    public let areLeaguesOptedInByDefault: Bool
    public let pseudonym: String
    public let squadGoal: PrismSquadGoalModel?
    public let friendsCount: Int

    public init(
        isProfilePrivateByDefault: Bool = true,
        areLeaguesOptedInByDefault: Bool = false,
        pseudonym: String = "Apprenant",
        squadGoal: PrismSquadGoalModel? = nil,
        friendsCount: Int = 0
    ) {
        self.isProfilePrivateByDefault = isProfilePrivateByDefault
        self.areLeaguesOptedInByDefault = areLeaguesOptedInByDefault
        self.pseudonym = pseudonym
        self.squadGoal = squadGoal
        self.friendsCount = max(0, friendsCount)
    }
}

// MARK: - 4. Profile Skeleton Model (S-70, S-74…S-84, §14)

public struct ProfileSkeletonModel: Codable, Equatable, Hashable, Sendable {
    public let displayName: String
    public let activeRouteCode: String?
    public let passport: PrismPassportSummary
    public let dailyStreakDays: Int?
    public let calmModeEnabled: Bool
    public let hapticsEnabled: Bool
    public let soundsEnabled: Bool
    public let cloudAIEnabled: Bool

    public init(
        displayName: String,
        activeRouteCode: String? = "AZ-900",
        passport: PrismPassportSummary,
        dailyStreakDays: Int? = 5,
        calmModeEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        soundsEnabled: Bool = true,
        cloudAIEnabled: Bool = false
    ) {
        self.displayName = displayName
        self.activeRouteCode = activeRouteCode
        self.passport = passport
        self.dailyStreakDays = dailyStreakDays
        self.calmModeEnabled = calmModeEnabled
        self.hapticsEnabled = hapticsEnabled
        self.soundsEnabled = soundsEnabled
        self.cloudAIEnabled = cloudAIEnabled
    }
}

// MARK: - 5. SwiftUI Screens (Apple platforms)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct TodayRootScreen: View {
    @Binding public var model: TodayScreenModel
    public let flags: FeatureFlags
    public let onStartSession: (PrismSessionLength, String?) -> Void
    public let onOpenDailySituation: () -> Void
    public let onOpenMemoryDetail: () -> Void
    public let onOpenRouteObjective: (String) -> Void
    public let onOpenCatalogExplorer: () -> Void
    public let onRetry: () -> Void
    @State private var showUnitGuideSheet = false

    public init(
        model: Binding<TodayScreenModel>,
        flags: FeatureFlags = FeatureFlags(),
        onStartSession: @escaping (PrismSessionLength, String?) -> Void = { _, _ in },
        onOpenDailySituation: @escaping () -> Void = {},
        onOpenMemoryDetail: @escaping () -> Void = {},
        onOpenRouteObjective: @escaping (String) -> Void = { _ in },
        onOpenCatalogExplorer: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {}
    ) {
        self._model = model
        self.flags = flags
        self.onStartSession = onStartSession
        self.onOpenDailySituation = onOpenDailySituation
        self.onOpenMemoryDetail = onOpenMemoryDetail
        self.onOpenRouteObjective = onOpenRouteObjective
        self.onOpenCatalogExplorer = onOpenCatalogExplorer
        self.onRetry = onRetry
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                if let offlineBanner = model.offlineBanner {
                    PrismOfflineBanner(model: offlineBanner)
                }

                switch model.state {
                case .loading(let elapsed):
                    PrismSkeleton(
                        model: PrismSkeletonModel(
                            rows: 4,
                            learningTip: "Une révision espacée de 72 h double l'ancrage à long terme.",
                            elapsedSeconds: elapsed
                        )
                    )
                case .empty(let emptyModel):
                    PrismEmptyState(model: emptyModel, onAction: onOpenCatalogExplorer)
                case .error(let errorModel):
                    PrismErrorState(model: errorModel, onRetry: onRetry)
                case .content:
                    duolingoPathContent
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.s)
            .padding(.bottom, PrismSpacing.giant)
        }
        .background(PrismColor.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showUnitGuideSheet) {
            PrismUnitGuideSheetView(
                routeCode: model.activeRouteCode ?? "AZ-104",
                unitTitle: unitBannerTitle
            )
        }
    }

    private var unitBannerSupertitle: String {
        switch model.activeRouteCode ?? "AZ-104" {
        case "AI-102": return "UNITÉ 2 · AGENTS & RAG VECTORIEL"
        case "AZ-305": return "UNITÉ 4 · HAUTE DISPONIBILITÉ"
        case "SAA-C03": return "UNITÉ 1 · VPC & RÉSEAU AWS"
        case "GH-300": return "UNITÉ 2 · INGÉNIERIE DE CONTEXTE"
        case "CKA": return "UNITÉ 1 · CONTROL PLANE KUBERNETES"
        default: return "UNITÉ 3 · RÉSEAUX HYBRIDES"
        }
    }

    private var unitBannerTitle: String {
        switch model.activeRouteCode ?? "AZ-104" {
        case "AI-102": return "Foundry Agent Service & AI Search"
        case "AZ-305": return "Architecture Multi-Régions & DR"
        case "SAA-C03": return "VPC Endpoints & AWS PrivateLink"
        case "GH-300": return "Instructions, Agents & Sécurité"
        case "CKA": return "RBAC, NetworkPolicies & CoreDNS"
        default: return "Isolation VNet & DNS privé"
        }
    }

    private var pathSteps: [PrismPathStepSpec] {
        switch model.activeRouteCode ?? "AZ-104" {
        case "AI-102":
            return [
                .init(id: "s1", title: "Déploiement Modèles", subtitle: nil, state: .done, symbol: "checkmark", alignment: .centerRight),
                .init(id: "s2", title: "Indexation AI Search", subtitle: nil, state: .done, symbol: "shield.fill", alignment: .leadingRight),
                .init(id: "s3", title: "Orchestration Agents", subtitle: "Étape 3 sur 5", state: .active, symbol: "sparkles", alignment: .trailingLeft),
                .init(id: "s4", title: "Guardrails & Sécurité", subtitle: nil, state: .locked, symbol: "lock.fill", alignment: .farTrailingLeft),
                .init(id: "s5", title: "Coffre de l'Unité 2", subtitle: "Défi synthèse", state: .chest, symbol: "shippingbox.fill", alignment: .leadingRight)
            ]
        case "SAA-C03":
            return [
                .init(id: "s1", title: "Subnets & NACL", subtitle: nil, state: .done, symbol: "checkmark", alignment: .centerRight),
                .init(id: "s2", title: "VPC Peering", subtitle: nil, state: .done, symbol: "shield.fill", alignment: .leadingRight),
                .init(id: "s3", title: "AWS PrivateLink", subtitle: "Étape 3 sur 5", state: .active, symbol: "point.3.connected.trianglepath.dotted", alignment: .trailingLeft),
                .init(id: "s4", title: "Transit Gateway", subtitle: nil, state: .locked, symbol: "lock.fill", alignment: .farTrailingLeft),
                .init(id: "s5", title: "Coffre de l'Unité 1", subtitle: "Défi synthèse", state: .chest, symbol: "shippingbox.fill", alignment: .leadingRight)
            ]
        default:
            return [
                .init(id: "s1", title: "Sous-réseaux & NSG", subtitle: nil, state: .done, symbol: "checkmark", alignment: .centerRight),
                .init(id: "s2", title: "Peering VNet", subtitle: nil, state: .done, symbol: "shield.fill", alignment: .leadingRight),
                .init(id: "s3", title: "Private Endpoint & DNS", subtitle: "Étape 3 sur 5", state: .active, symbol: "point.3.connected.trianglepath.dotted", alignment: .trailingLeft),
                .init(id: "s4", title: "Pare-feu Azure & UDR", subtitle: nil, state: .locked, symbol: "lock.fill", alignment: .farTrailingLeft),
                .init(id: "s5", title: "Coffre de l'Unité 3", subtitle: "Situation du jour", state: .chest, symbol: "shippingbox.fill", alignment: .leadingRight)
            ]
        }
    }

    @ViewBuilder
    private var duolingoPathContent: some View {
        // 1. Unit Header Banner (Duolingo Style + Guide Button, zero duration selector!)
        HStack(alignment: .center, spacing: PrismSpacing.m) {
            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                Text(verbatim: unitBannerSupertitle)
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.onAccent.opacity(0.85))
                Text(verbatim: unitBannerTitle)
                    .prismTextStyle(.title3)
                    .foregroundStyle(PrismColor.onAccent)
                Text(verbatim: "5 étapes · Objectif examen : 25–30 %")
                    .prismTextStyle(.footnote)
                    .foregroundStyle(PrismColor.onAccent.opacity(0.9))
            }
            Spacer(minLength: PrismSpacing.xs)
            Button {
                showUnitGuideSheet = true
            } label: {
                HStack(spacing: PrismSpacing.xs) {
                    Image(systemName: "book.closed.fill")
                        .prismTextStyle(.subheadline)
                    Text(verbatim: "Guide")
                        .prismTextStyle(.subheadline)
                }
                .foregroundStyle(PrismColor.onAccent)
                .padding(.horizontal, PrismSpacing.m)
                .padding(.vertical, PrismSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                        .fill(PrismColor.onAccent.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                        .strokeBorder(PrismColor.onAccent.opacity(0.45), lineWidth: PrismBorder.standard)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("unit-guide-button")
        }
        .padding(PrismSpacing.l)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: PrismRadius.unitBanner, style: .continuous)
                    .fill(PrismRegion.network.color)
                    .offset(y: PrismSize.lipDepth)
                RoundedRectangle(cornerRadius: PrismRadius.unitBanner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PrismColor.accent, PrismRegion.network.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )

        // 2. Winding S-Curve Stepping-Stone Path (No session duration picker!)
        PrismDuolingoWindingPathView(
            steps: pathSteps,
            onTapStep: { step in
                switch step.state {
                case .done, .active:
                    onStartSession(.standard, model.interruptedSession?.sessionId)
                case .chest:
                    onOpenDailySituation()
                case .locked:
                    break
                }
            }
        )
        .padding(.top, PrismSpacing.s)
    }
}

public struct PrismPathStepSpec: Identifiable, Equatable, Sendable {
    public enum StepState: String, Equatable, Sendable {
        case done, active, locked, chest
    }
    public enum RowAlignment: String, Equatable, Sendable {
        case centerRight, leadingRight, trailingLeft, farTrailingLeft
    }
    public let id: String
    public let title: String
    public let subtitle: String?
    public let state: StepState
    public let symbol: String
    public let alignment: RowAlignment
}

private struct PrismDuolingoWindingPathView: View {
    let steps: [PrismPathStepSpec]
    let onTapStep: (PrismPathStepSpec) -> Void

    var body: some View {
        ZStack {
            // Smooth S-Curve Track behind the stepping stones
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let p1 = CGPoint(x: w * 0.46, y: h * 0.08)
                let p2 = CGPoint(x: w * 0.25, y: h * 0.27)
                let p3 = CGPoint(x: w * 0.62, y: h * 0.52)
                let p4 = CGPoint(x: w * 0.72, y: h * 0.75)
                let p5 = CGPoint(x: w * 0.34, y: h * 0.93)

                var donePath = Path()
                donePath.move(to: p1)
                donePath.addCurve(
                    to: p2,
                    control1: CGPoint(x: w * 0.46, y: h * 0.18),
                    control2: CGPoint(x: w * 0.25, y: h * 0.18)
                )
                donePath.addCurve(
                    to: p3,
                    control1: CGPoint(x: w * 0.25, y: h * 0.39),
                    control2: CGPoint(x: w * 0.62, y: h * 0.39)
                )
                context.stroke(
                    donePath,
                    with: .color(PrismColor.positive),
                    style: StrokeStyle(lineWidth: PrismSize.pathTrackStroke, lineCap: .round)
                )

                var lockedPath = Path()
                lockedPath.move(to: p3)
                lockedPath.addCurve(
                    to: p4,
                    control1: CGPoint(x: w * 0.62, y: h * 0.64),
                    control2: CGPoint(x: w * 0.72, y: h * 0.64)
                )
                lockedPath.addCurve(
                    to: p5,
                    control1: CGPoint(x: w * 0.72, y: h * 0.84),
                    control2: CGPoint(x: w * 0.34, y: h * 0.84)
                )
                context.stroke(
                    lockedPath,
                    with: .color(PrismColor.separator),
                    style: StrokeStyle(
                        lineWidth: PrismSize.pathTrackStroke,
                        lineCap: .round,
                        dash: [PrismSpacing.xxs, PrismSpacing.l]
                    )
                )
            }

            VStack(spacing: PrismSpacing.xxl) {
                ForEach(steps) { step in
                    stepRow(for: step)
                }
            }
            .padding(.vertical, PrismSpacing.s)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func stepRow(for step: PrismPathStepSpec) -> some View {
        switch step.alignment {
        case .centerRight:
            HStack(spacing: PrismSpacing.m) {
                Spacer(minLength: PrismSpacing.xxl)
                nodeButton(for: step)
                stepLabelPill(for: step)
                Spacer(minLength: PrismSpacing.xs)
            }
        case .leadingRight:
            HStack(spacing: PrismSpacing.m) {
                nodeButton(for: step)
                    .padding(.leading, PrismSpacing.xl)
                stepLabelPill(for: step)
                Spacer(minLength: PrismSpacing.xs)
            }
        case .trailingLeft:
            VStack(spacing: PrismSpacing.xs) {
                // Floating "COMMENCER" callout pill above the active stepping stone
                Button {
                    onTapStep(step)
                } label: {
                    Text(verbatim: "COMMENCER")
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.accent)
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, PrismSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                                .strokeBorder(PrismColor.accent, lineWidth: PrismBorder.strong)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today-primary-session-cta")

                HStack(spacing: PrismSpacing.m) {
                    Spacer(minLength: PrismSpacing.xs)
                    stepLabelPill(for: step)
                    nodeButton(for: step)
                        .padding(.trailing, PrismSpacing.xl)
                }
            }
        case .farTrailingLeft:
            HStack(spacing: PrismSpacing.m) {
                Spacer(minLength: PrismSpacing.s)
                stepLabelPill(for: step)
                nodeButton(for: step)
                    .padding(.trailing, PrismSpacing.m)
            }
        }
    }

    @ViewBuilder
    private func nodeButton(for step: PrismPathStepSpec) -> some View {
        let isActive = step.state == .active
        let nodeDim = isActive ? PrismSize.pathNodeActive : PrismSize.pathNode

        Button {
            onTapStep(step)
        } label: {
            ZStack {
                if isActive {
                    Circle()
                        .fill(PrismColor.accent.opacity(0.14))
                        .frame(width: PrismSize.pathNodeRing, height: PrismSize.pathNodeRing)
                        .overlay(
                            Circle()
                                .strokeBorder(PrismColor.accent, lineWidth: PrismBorder.strong)
                        )
                }

                // 3D Bottom Lip
                Circle()
                    .fill(lipColor(for: step.state))
                    .frame(width: nodeDim, height: nodeDim)
                    .offset(y: PrismSize.lipDepth)

                // Main Circular Stepping-Stone Face with Cut-Out Icon (no white box!)
                Circle()
                    .fill(faceColor(for: step.state))
                    .frame(width: nodeDim, height: nodeDim)
                    .overlay(
                        Image(systemName: step.symbol)
                            .prismTextStyle(isActive ? .title2 : .title3)
                            .foregroundStyle(
                                step.state == .locked ? PrismColor.textSecondary : PrismColor.onAccent
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(step.state == .locked)
    }

    @ViewBuilder
    private func stepLabelPill(for step: PrismPathStepSpec) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
            Text(verbatim: step.title)
                .prismTextStyle(.subheadline)
                .foregroundStyle(
                    step.state == .locked ? PrismColor.textSecondary : PrismColor.textPrimary
                )
            if let subtitle = step.subtitle {
                Text(verbatim: subtitle)
                    .prismTextStyle(.caption)
                    .foregroundStyle(
                        step.state == .chest ? PrismColor.caution : PrismColor.accent
                    )
            }
        }
        .padding(.horizontal, PrismSpacing.m)
        .padding(.vertical, PrismSpacing.s)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                    .fill(PrismColor.separator.opacity(0.45))
                    .offset(y: PrismSpacing.xxs)
                RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                    .fill(PrismColor.surface)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                .strokeBorder(
                    step.state == .active ? PrismColor.accent : PrismColor.separator,
                    lineWidth: step.state == .active ? PrismBorder.strong : PrismBorder.regular
                )
        )
    }

    private func faceColor(for state: PrismPathStepSpec.StepState) -> Color {
        switch state {
        case .done: return PrismColor.positive
        case .active: return PrismColor.accent
        case .chest: return PrismColor.caution
        case .locked: return PrismColor.surfaceRaised
        }
    }

    private func lipColor(for state: PrismPathStepSpec.StepState) -> Color {
        switch state {
        case .done: return PrismColor.positive.opacity(0.72)
        case .active: return PrismRegion.network.color
        case .chest: return PrismColor.caution.opacity(0.75)
        case .locked: return PrismColor.separator
        }
    }
}

public struct PrismUnitGuideSheetView: View {
    public let routeCode: String
    public let unitTitle: String
    @Environment(\.dismiss) private var dismiss

    public init(routeCode: String, unitTitle: String) {
        self.routeCode = routeCode
        self.unitTitle = unitTitle
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    PrismCard(variant: .hero) {
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: "GUIDE D'UNITÉ · \(routeCode)",
                                    semantics: .accent
                                )
                            )
                            PrismText(text: unitTitle, style: .title2)
                            PrismText(
                                text: "Schéma d'architecture, commandes CLI et pièges classiques de l'examen.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                        }
                    }

                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(text: "1. SCHÉMA D'ARCHITECTURE À RETENIR", style: .caption, role: .accent)
                            PrismText(
                                text: "VM (10.0.0.4) ──► Private Endpoint (10.2.0.5) ──► Stockage Blob",
                                style: .headline
                            )
                            PrismText(
                                text: "• Le trafic reste 100 % sur le backbone Microsoft Azure.\n• La zone privatelink.blob.core.windows.net DOIT être liée au VNet via un Virtual Network Link.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                        }
                    }

                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(text: "2. COMMANDES AZURE CLI INDISPENSABLES", style: .caption, role: .accent)
                            PrismText(
                                text: "az network private-dns zone create -g rg-prod -n privatelink.blob.core.windows.net\naz network private-dns link vnet create -g rg-prod -z privatelink.blob... -v vnet-hub -e false",
                                style: .codeSmall
                            )
                        }
                    }

                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(text: "3. PIÈGE CLASSIQUE À L'EXAMEN", style: .caption, role: .caution)
                            PrismText(
                                text: "• Service Endpoint : garde l'IP publique du service PaaS.\n• Private Endpoint : attribue une IP privée de ton sous-réseau.\n• L'auto-registration DNS (-e true) ne sert que pour les VM, pas pour les Private Endpoints PaaS.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                        }
                    }
                }
                .padding(PrismSpacing.l)
            }
            .background(PrismColor.canvas)
            .navigationTitle(Text(verbatim: "Guide de l'unité"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "Fermer")
                    }
                }
            }
        }
    }
}
// MARK: - Catalog Explorer Screen (S-46, §14, §22A.5)

public struct CatalogExplorerScreen: View {
    @Binding public var model: CatalogExplorerModel
    public let flags: FeatureFlags
    public let onSelectGoal: (CatalogRouteItem) -> Void

    public init(
        model: Binding<CatalogExplorerModel>,
        flags: FeatureFlags = FeatureFlags(),
        onSelectGoal: @escaping (CatalogRouteItem) -> Void = { _ in }
    ) {
        self._model = model
        self.flags = flags
        self.onSelectGoal = onSelectGoal
    }

    public init(
        model: Binding<CatalogExplorerModel>,
        flags: FeatureFlags = FeatureFlags(),
        onSelectRoute: @escaping (CatalogRouteItem) -> Void
    ) {
        self.init(model: model, flags: flags, onSelectGoal: onSelectRoute)
    }

    public var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PrismSpacing.s) {
                        PrismChip(
                            configuration: PrismChipConfiguration(
                                title: "Toutes les régions",
                                isSelected: model.selectedRegion == nil
                            )
                        ) {
                            model.selectedRegion = nil
                        }
                        ForEach(PrismRegion.allCases, id: \.rawValue) { region in
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: region.displayName,
                                    isSelected: model.selectedRegion == region
                                )
                            ) {
                                model.selectedRegion = region
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(model.filteredRoutes) { route in
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        BrandLabel(
                            product: route.product,
                            context: .learningContent,
                            examCode: route.code,
                            size: .medium,
                            flags: flags
                        )
                        PrismText(text: route.officialTitle, style: .body)
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            RegionChip(region: route.region)
                            if route.isConfirmedActiveGoal {
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Objectif actif confirmé",
                                        semantics: .positive
                                    )
                                )
                            } else {
                                Button {
                                    onSelectGoal(route)
                                } label: {
                                    Text(verbatim: "Choisir comme objectif actif")
                                }
                                .buttonStyle(PrismButtonStyle(variant: .tertiary))
                            }
                        }
                    }
                    .padding(.vertical, PrismSpacing.xs)
                }
            } header: {
                Text(verbatim: "Routes de certification (\(model.filteredRoutes.count))")
            }
        }
        .searchable(text: $model.searchQuery)
        .navigationTitle(Text(verbatim: "Explorer"))
    }
}

// MARK: - Atlas List Minimal Screen (S-40 Phase 3, §14, §15 NS-8)

public struct AtlasListMinimalScreen: View {
    public let nodes: [PrismAtlasNode]
    @State private var selectedRegion: PrismRegion?
    @State private var selectedState: PrismMasteryState?
    public let onOpenCatalogExplorer: () -> Void
    public let onSelectConcept: (PrismAtlasNode) -> Void

    public init(
        nodes: [PrismAtlasNode],
        onOpenCatalogExplorer: @escaping () -> Void = {},
        onSelectConcept: @escaping (PrismAtlasNode) -> Void = { _ in }
    ) {
        self.nodes = nodes
        self.onOpenCatalogExplorer = onOpenCatalogExplorer
        self.onSelectConcept = onSelectConcept
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Catalogue des certifications (Explorer)",
                            subtitle: "Parcourir les routes et choisir ton objectif actif",
                            showsChevron: true
                        ),
                        action: onOpenCatalogExplorer
                    )
                }

                AtlasList(
                    nodes: nodes,
                    selectedRegion: selectedRegion,
                    selectedState: selectedState,
                    onSelectNode: onSelectConcept
                )
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Atlas"))
    }
}

// MARK: - Ensemble Minimal Screen (S-60 Phase 3, §10, §15 NS-12)

public struct EnsembleMinimalScreen: View {
    public let model: EnsembleMinimalModel
    public let onOpenSquadSheet: () -> Void
    public let onOpenInviteSheet: () -> Void

    public init(
        model: EnsembleMinimalModel = EnsembleMinimalModel(),
        onOpenSquadSheet: @escaping () -> Void = {},
        onOpenInviteSheet: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onOpenSquadSheet = onOpenSquadSheet
        self.onOpenInviteSheet = onOpenInviteSheet
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: model.isProfilePrivateByDefault ? "Privé par défaut" : "Partagé",
                                semantics: .positive
                            )
                        )
                        PrismText(text: "Pseudonyme : \(model.pseudonym)", style: .headline)
                        PrismText(
                            text: "Aucune donnée ni échec n'est visible par autrui sans ton choix explicite.",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }

                if let squad = model.squadGoal {
                    SquadGoalView(model: squad)
                } else {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(text: "Squad coopérative (3 à 8 apprenants)", style: .headline)
                            PrismText(
                                text: "Progressez ensemble sur un objectif hebdomadaire commun, sans classement anxiogène.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                            Button {
                                onOpenSquadSheet()
                            } label: {
                                Text(verbatim: "Créer ou rejoindre une Squad")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Ensemble"))
    }
}

// MARK: - Profile Skeleton Screen (S-70, S-74…S-84 Phase 3, §14)

public struct ProfileSkeletonScreen: View {
    public let model: ProfileSkeletonModel
    public let flags: FeatureFlags
    public let onNavigate: (AppRoute) -> Void

    public init(
        model: ProfileSkeletonModel,
        flags: FeatureFlags = FeatureFlags(),
        onNavigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        self.model = model
        self.flags = flags
        self.onNavigate = onNavigate
    }

    public var body: some View {
        List {
            Section {
                PassportCard(summary: model.passport)
                if flags.isEnabled(.dailyStreakOptIn), let streak = model.dailyStreakDays {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Série quotidienne : \(streak) jours",
                            subtitle: "Option activée (DR-005)"
                        )
                    )
                }
            } header: {
                Text(verbatim: model.displayName)
            }

            Section {
                Button {
                    onNavigate(.settingsRhythmAndReminders)
                } label: {
                    Text(verbatim: "Rythme & rappels")
                }
                Button {
                    onNavigate(.settingsLanguage)
                } label: {
                    Text(verbatim: "Langue d'interface (8 langues)")
                }
                Button {
                    onNavigate(.settingsAccessibilityAndCalmMode)
                } label: {
                    Text(verbatim: "Lecture, accessibilité & Mode Calme")
                }
                Button {
                    onNavigate(.settingsPrivacyAndVisibility)
                } label: {
                    Text(verbatim: "Confidentialité & visibilité")
                }
                Button {
                    onNavigate(.settingsBrandNotices)
                } label: {
                    Text(verbatim: "Marques et mentions légales")
                }
                Button {
                    onNavigate(.settingsAccountDeletion)
                } label: {
                    Text(verbatim: "Suppression du compte")
                        .foregroundStyle(PrismColor.negative)
                }
            } header: {
                Text(verbatim: "Réglages")
            }
        }
        .navigationTitle(Text(verbatim: "Profil"))
    }
}
#endif
