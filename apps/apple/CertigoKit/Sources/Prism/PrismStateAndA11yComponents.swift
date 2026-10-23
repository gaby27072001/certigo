import Foundation

// MARK: - 1. Empty State Model (§6.4, §19, §29)

public struct PrismEmptyStateModel: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case standard
        case unsupportedFormat(formatName: String)
    }

    public let id: String
    public let kind: Kind
    public let symbolName: String
    public let title: String
    public let valueProposition: String
    public let actionTitle: String
    public let region: PrismRegion?

    public init(
        id: String = "prism.empty.standard",
        kind: Kind = .standard,
        symbolName: String = "sparkles.rectangle.stack",
        title: String,
        valueProposition: String,
        actionTitle: String,
        region: PrismRegion? = nil
    ) {
        self.id = id
        self.kind = kind
        self.symbolName = symbolName
        self.title = title
        self.valueProposition = valueProposition
        self.actionTitle = actionTitle
        self.region = region
    }

    public var isCompact: Bool {
        if case .unsupportedFormat = kind {
            return true
        }
        return false
    }

    public static func unsupportedFormat(
        formatName: String,
        actionTitle: String = "Passer",
        region: PrismRegion? = nil
    ) -> PrismEmptyStateModel {
        let trimmed = formatName.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = trimmed.isEmpty
            ? "Tu peux continuer ta séance sans perdre ta progression."
            : "Le format « \(trimmed) » est en cours d'intégration."
        return PrismEmptyStateModel(
            id: "prism.empty.unsupported.\(trimmed.lowercased())",
            kind: .unsupportedFormat(formatName: trimmed),
            symbolName: "rectangle.dashed.badge.record",
            title: "Ce format arrive bientôt",
            valueProposition: detail,
            actionTitle: actionTitle,
            region: region
        )
    }
}

// MARK: - 2. Error State Model (§19, §29)

public struct PrismErrorStateModel: Equatable, Sendable, Identifiable {
    public static let mandatoryReassurance = "Tes réponses sont en sécurité"

    public let id: String
    public let symbolName: String
    public let title: String
    public let explanation: String
    public let reassuranceMessage: String
    public let retryActionTitle: String
    public let technicalCode: String?
    public let isTechnicalCodeHiddenByDefault: Bool

    public init(
        id: String = "prism.error.default",
        symbolName: String = "icloud.slash",
        title: String = "Synchronisation momentanément indisponible",
        explanation: String = "La connexion au service a pris plus de temps que prévu.",
        reassuranceMessage: String = PrismErrorStateModel.mandatoryReassurance,
        retryActionTitle: String = "Réessayer",
        technicalCode: String? = nil,
        isTechnicalCodeHiddenByDefault: Bool = true
    ) {
        self.id = id
        self.symbolName = symbolName
        self.title = title
        self.explanation = explanation
        self.reassuranceMessage = reassuranceMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? PrismErrorStateModel.mandatoryReassurance
            : reassuranceMessage
        self.retryActionTitle = retryActionTitle
        self.technicalCode = technicalCode
        self.isTechnicalCodeHiddenByDefault = isTechnicalCodeHiddenByDefault
    }

    public var hasTechnicalCode: Bool {
        guard let technicalCode else { return false }
        return !technicalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 3. Offline Banner Model (§19, §29)

public struct PrismOfflineBannerModel: Equatable, Sendable, Identifiable {
    public let id: String
    public let cachedPlayableSessionsCount: Int
    public let queuedSubmissionsCount: Int
    public let isSyncing: Bool

    public init(
        id: String = "prism.offline.banner",
        cachedPlayableSessionsCount: Int,
        queuedSubmissionsCount: Int,
        isSyncing: Bool = false
    ) {
        self.id = id
        self.cachedPlayableSessionsCount = max(0, cachedPlayableSessionsCount)
        self.queuedSubmissionsCount = max(0, queuedSubmissionsCount)
        self.isSyncing = isSyncing
    }

    public var headline: String {
        if isSyncing {
            return "Synchronisation idempotente en cours"
        }
        return "Mode hors ligne actif"
    }

    public var availabilitySummary: String {
        let sessionWord = cachedPlayableSessionsCount == 1 ? "séance en cache jouable" : "séances en cache jouables"
        if queuedSubmissionsCount == 0 {
            return "\(cachedPlayableSessionsCount) \(sessionWord) disponible immédiatement."
        }
        let responseWord = queuedSubmissionsCount == 1 ? "réponse en file prête" : "réponses en file prêtes"
        return "\(cachedPlayableSessionsCount) \(sessionWord) · \(queuedSubmissionsCount) \(responseWord) pour synchronisation idempotente."
    }
}

// MARK: - 4. Skeleton Model (§19, §29)

public struct PrismSkeletonModel: Equatable, Sendable, Identifiable {
    public let id: String
    public let rows: Int
    public let learningTip: String?
    public let elapsedSeconds: Double

    public init(
        id: String = "prism.skeleton",
        rows: Int = 3,
        learningTip: String? = nil,
        elapsedSeconds: Double = 0
    ) {
        self.id = id
        self.rows = max(1, rows)
        self.learningTip = learningTip
        self.elapsedSeconds = max(0, elapsedSeconds)
    }

    public var allowsFullScreenSpinner: Bool {
        false
    }

    public var shouldDisplayLearningTip: Bool {
        guard elapsedSeconds > 1.0, let learningTip else { return false }
        return !learningTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 5. Toast Model (§19, §29)

public struct PrismToastModel: Equatable, Sendable, Identifiable {
    public let id: String
    public let symbolName: String
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let region: PrismRegion?
    public let isDismissibleInOneTap: Bool

    public init(
        id: String = "prism.toast",
        symbolName: String = "person.crop.circle.badge.checkmark",
        title: String,
        message: String,
        actionTitle: String? = nil,
        region: PrismRegion? = nil,
        isDismissibleInOneTap: Bool = true
    ) {
        self.id = id
        self.symbolName = symbolName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.region = region
        self.isDismissibleInOneTap = isDismissibleInOneTap
    }

    public static func guestSaveInvitation(
        region: PrismRegion = .azure
    ) -> PrismToastModel {
        PrismToastModel(
            id: "prism.toast.guest.save",
            symbolName: "icloud.and.arrow.up",
            title: "Mode Invité",
            message: "Sauvegarde ta maîtrise pour la retrouver sur tous tes appareils.",
            actionTitle: "Sauvegarder",
            region: region,
            isDismissibleInOneTap: true
        )
    }
}

// MARK: - 6. Celebration Configuration (§9, §19, §25, §26, §28)

public struct PrismCelebrationConfig: Equatable, Sendable, Identifiable {
    public let id: String
    public let requestedLevel: PrismCelebrationLevel
    public let calmMode: Bool
    public let reduceMotion: Bool
    public let isMuted: Bool
    public let region: PrismRegion
    public let title: String
    public let subtitle: String?
    public let isDismissibleInOneTap: Bool

    public init(
        id: String = "prism.celebration",
        level: PrismCelebrationLevel,
        calmMode: Bool = false,
        reduceMotion: Bool = false,
        isMuted: Bool = false,
        region: PrismRegion = .azure,
        title: String,
        subtitle: String? = nil,
        isDismissibleInOneTap: Bool = true
    ) {
        self.id = id
        self.requestedLevel = level
        self.calmMode = calmMode
        self.reduceMotion = reduceMotion
        self.isMuted = isMuted
        self.region = region
        self.title = title
        self.subtitle = subtitle
        self.isDismissibleInOneTap = isDismissibleInOneTap
    }

    public var resolvedLevel: PrismCelebrationLevel {
        requestedLevel.resolved(calmMode: calmMode)
    }

    public var shouldPlaySound: Bool {
        !isMuted && resolvedLevel.rawValue >= PrismCelebrationLevel.pulse.rawValue
    }

    public var motionSpec: PrismMotionSpec {
        PrismMotion.resolve(.expressive, reduceMotion: reduceMotion)
    }

    public var voiceOverAnnouncement: PrismAccessibilityAnnouncement {
        let combined = if let subtitle, !subtitle.isEmpty {
            "\(title). \(subtitle)"
        } else {
            title
        }
        return PrismAccessibilityAnnouncement(
            id: "celebration.\(id)",
            kind: .celebration,
            message: combined,
            announceOnce: true
        )
    }
}

// MARK: - 7. Share Card Payload & Spoiler-Free Validation (§15 NS-7, §19, §22A.7)

public struct PrismShareCardPayload: Equatable, Sendable, Identifiable {
    public static let forbiddenThirdPartyBrands: [String] = [
        "microsoft", "amazon", "aws", "google", "gcp", "cisco", "comptia", "oracle", "ibm", "hashicorp", "red hat"
    ]

    public static let forbiddenSpoilerMarkers: [String] = [
        "bonne réponse",
        "réponse correcte",
        "correct answer",
        "question :",
        "question:",
        "énoncé",
        "explication détaillée",
        "choix a",
        "choix b",
        "choix c",
        "choix d"
    ]

    public let id: String
    public let title: String
    public let region: PrismRegion
    public let synthesis: String
    public let milestoneBadge: String
    public let streakDays: Int?
    public let questionStemCandidate: String?
    public let correctAnswerCandidate: String?
    public let thirdPartyBrandIconName: String?

    public init(
        id: String = "prism.share.card",
        title: String,
        region: PrismRegion,
        synthesis: String,
        milestoneBadge: String = "Rituel accompli",
        streakDays: Int? = nil,
        questionStemCandidate: String? = nil,
        correctAnswerCandidate: String? = nil,
        thirdPartyBrandIconName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.region = region
        self.synthesis = synthesis
        self.milestoneBadge = milestoneBadge
        self.streakDays = streakDays
        self.questionStemCandidate = questionStemCandidate
        self.correctAnswerCandidate = correctAnswerCandidate
        self.thirdPartyBrandIconName = thirdPartyBrandIconName
    }

    public var spoilerViolations: [String] {
        var violations: [String] = []
        if let questionStemCandidate, !questionStemCandidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            violations.append("questionStemPresent")
        }
        if let correctAnswerCandidate, !correctAnswerCandidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            violations.append("correctAnswerPresent")
        }
        if let thirdPartyBrandIconName, !thirdPartyBrandIconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            violations.append("thirdPartyBrandIconPresent")
        }

        let combinedLowercased = "\(title) \(synthesis) \(milestoneBadge)".lowercased()
        for marker in Self.forbiddenSpoilerMarkers where combinedLowercased.contains(marker) {
            violations.append("spoilerMarker:\(marker)")
        }
        for brand in Self.forbiddenThirdPartyBrands where combinedLowercased.contains(brand) {
            violations.append("thirdPartyBrand:\(brand)")
        }
        if synthesis.contains("?") {
            violations.append("questionMarkInSynthesis")
        }
        return violations
    }

    public var isSpoilerFree: Bool {
        spoilerViolations.isEmpty
    }

    public var sanitizedSynthesis: String {
        isSpoilerFree ? synthesis : "Jalon de maîtrise validé sur la région \(region.displayName)."
    }
}

// MARK: - 8. Adaptive Stack Policy (§19, §28)

public enum PrismAdaptiveAxis: String, Equatable, Sendable {
    case horizontal
    case vertical
}

public enum PrismAdaptiveStackPolicy: Sendable {
    public static func resolvedAxis(isAccessibilityCategory: Bool) -> PrismAdaptiveAxis {
        isAccessibilityCategory ? .vertical : .horizontal
    }
}

// MARK: - 9. Accessibility Rotor Entry (§19, §28)

public struct PrismAccessibilityRotorEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let lineNumber: Int?
    public let region: PrismRegion?
    public let detail: String?

    public init(
        id: String,
        label: String,
        lineNumber: Int? = nil,
        region: PrismRegion? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.label = label
        self.lineNumber = lineNumber
        self.region = region
        self.detail = detail
    }

    public var spokenSummary: String {
        var components: [String] = []
        if let lineNumber {
            components.append("Ligne \(lineNumber)")
        }
        if let region {
            components.append(region.displayName)
        }
        components.append(label)
        if let detail, !detail.isEmpty {
            components.append(detail)
        }
        return components.joined(separator: ", ")
    }
}

// MARK: - 10. Accessibility Actions & Structured Announcements (§19, §28)

public struct PrismAccessibilityCustomActionModel: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct PrismAccessibilityAction: Sendable, Identifiable {
    public let model: PrismAccessibilityCustomActionModel
    public let handler: @Sendable () -> Bool

    public var id: String { model.id }
    public var name: String { model.name }

    public init(
        id: String,
        name: String,
        handler: @escaping @Sendable () -> Bool
    ) {
        self.model = PrismAccessibilityCustomActionModel(id: id, name: name)
        self.handler = handler
    }
}

public struct PrismAccessibilityAnnouncement: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable {
        case correct
        case incorrect
        case celebration
        case status

        public var prefixLabel: String {
            switch self {
            case .correct:
                return "Réponse exacte"
            case .incorrect:
                return "Point à consolider"
            case .celebration:
                return "Jalon atteint"
            case .status:
                return "Information"
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let message: String
    public let announceOnce: Bool

    public init(
        id: String,
        kind: Kind,
        message: String,
        announceOnce: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.announceOnce = announceOnce
    }

    public var formattedSpeech: String {
        "\(kind.prefixLabel) : \(message)"
    }
}

public struct PrismAnnouncementLedger: Equatable, Sendable {
    private(set) public var deliveredIDs: Set<String> = []

    public init() {}

    public mutating func shouldDeliver(_ announcement: PrismAccessibilityAnnouncement) -> Bool {
        if !announcement.announceOnce {
            return true
        }
        if deliveredIDs.contains(announcement.id) {
            return false
        }
        deliveredIDs.insert(announcement.id)
        return true
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - 1. PrismEmptyState View (§6.4, §19, §29)

public struct PrismEmptyState: View {
    private let model: PrismEmptyStateModel
    private let onAction: () -> Void

    public init(
        model: PrismEmptyStateModel,
        onAction: @escaping () -> Void
    ) {
        self.model = model
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            if model.isCompact {
                compactBody
            } else {
                standardBody
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.id)
    }

    private var accentColor: Color {
        model.region?.color ?? PrismColor.brandPrimary
    }

    private var standardBody: some View {
        ContentUnavailableView {
            Label {
                Text(verbatim: model.title)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.inkPrimary)
            } icon: {
                Image(systemName: model.symbolName)
                    .foregroundStyle(accentColor)
            }
        } description: {
            Text(verbatim: model.valueProposition)
                .prismTextStyle(.body)
                .foregroundStyle(PrismColor.inkSecondary)
        } actions: {
            Button(action: onAction) {
                Text(verbatim: model.actionTitle)
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.surfacePrimary)
                    .padding(.horizontal, PrismSpacing.lg)
                    .padding(.vertical, PrismSpacing.sm)
                    .frame(minHeight: PrismSize.minTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.button, style: .continuous)
                            .fill(accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(PrismSpacing.lg)
    }

    private var compactBody: some View {
        PrismAdaptiveStack(spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: model.symbolName)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: model.title)
                        .prismTextStyle(.headline)
                        .foregroundStyle(PrismColor.inkPrimary)

                    Text(verbatim: model.valueProposition)
                        .prismTextStyle(.footnote)
                        .foregroundStyle(PrismColor.inkSecondary)
                }
            }

            Spacer(minLength: PrismSpacing.xs)

            Button(action: onAction) {
                Text(verbatim: model.actionTitle)
                    .prismTextStyle(.callout)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, PrismSpacing.md)
                    .padding(.vertical, PrismSpacing.xs)
                    .frame(minHeight: PrismSize.minTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.button, style: .continuous)
                            .strokeBorder(accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
                .fill(PrismColor.surfaceElevated)
        )
    }
}

// MARK: - 2. PrismErrorState View (§19, §29)

public struct PrismErrorState: View {
    private let model: PrismErrorStateModel
    private let onRetry: () -> Void
    @State private var isTechnicalCodeVisible: Bool
    @State private var didCopyTechnicalCode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        model: PrismErrorStateModel,
        onRetry: @escaping () -> Void
    ) {
        self.model = model
        self.onRetry = onRetry
        self._isTechnicalCodeVisible = State(initialValue: !model.isTechnicalCodeHiddenByDefault)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: model.symbolName)
                    .foregroundStyle(PrismColor.feedbackWarning)
                    .accessibilityHidden(true)

                Text(verbatim: model.title)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.inkPrimary)
            }

            Text(verbatim: model.explanation)
                .prismTextStyle(.body)
                .foregroundStyle(PrismColor.inkSecondary)

            HStack(spacing: PrismSpacing.xs) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(PrismColor.feedbackSuccess)
                    .accessibilityHidden(true)

                Text(verbatim: model.reassuranceMessage)
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.inkPrimary)
            }
            .padding(PrismSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                    .fill(PrismColor.surfaceSecondary)
            )

            PrismAdaptiveStack(spacing: PrismSpacing.sm) {
                Button(action: onRetry) {
                    Text(verbatim: model.retryActionTitle)
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.surfacePrimary)
                        .padding(.horizontal, PrismSpacing.lg)
                        .padding(.vertical, PrismSpacing.sm)
                        .frame(minHeight: PrismSize.minTapTarget)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.button, style: .continuous)
                                .fill(PrismColor.brandPrimary)
                        )
                }
                .buttonStyle(.plain)

                if let technicalCode = model.technicalCode, model.hasTechnicalCode {
                    Button {
                        withAnimation(PrismMotion.resolve(.standard, reduceMotion: reduceMotion).animation) {
                            isTechnicalCodeVisible.toggle()
                        }
                    } label: {
                        let toggleLabel = isTechnicalCodeVisible ? "Masquer le code technique" : "Afficher le code technique"
                        Text(verbatim: toggleLabel)
                            .prismTextStyle(.footnote)
                            .foregroundStyle(PrismColor.inkSecondary)
                            .padding(.horizontal, PrismSpacing.sm)
                            .padding(.vertical, PrismSpacing.xs)
                            .frame(minHeight: PrismSize.minTapTarget)
                    }
                    .buttonStyle(.plain)

                    if isTechnicalCodeVisible {
                        HStack(spacing: PrismSpacing.xs) {
                            Text(verbatim: technicalCode)
                                .prismTextStyle(.monoCode)
                                .foregroundStyle(PrismColor.inkSecondary)

                            Button {
                                UIPasteboard.general.string = technicalCode
                                didCopyTechnicalCode = true
                            } label: {
                                let copyLabel = didCopyTechnicalCode ? "Copié" : "Copier"
                                Text(verbatim: copyLabel)
                                    .prismTextStyle(.caption)
                                    .foregroundStyle(PrismColor.brandPrimary)
                                    .padding(.horizontal, PrismSpacing.xs)
                                    .padding(.vertical, PrismSpacing.xxs)
                                    .frame(minHeight: PrismSize.minTapTarget)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, PrismSpacing.sm)
                        .padding(.vertical, PrismSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                                .fill(PrismColor.surfaceSecondary)
                        )
                    }
                }
            }
        }
        .padding(PrismSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
                .fill(PrismColor.surfaceElevated)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.id)
    }
}

// MARK: - 3. PrismOfflineBanner View (§19, §29)

public struct PrismOfflineBanner: View {
    private let model: PrismOfflineBannerModel

    public init(model: PrismOfflineBannerModel) {
        self.model = model
    }

    public var body: some View {
        PrismAdaptiveStack(spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: model.isSyncing ? "arrow.triangle.2.circlepath.icloud" : "wifi.slash")
                    .foregroundStyle(PrismColor.feedbackInfo)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: model.headline)
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.inkPrimary)

                    Text(verbatim: model.availabilitySummary)
                        .prismTextStyle(.footnote)
                        .foregroundStyle(PrismColor.inkSecondary)
                }
            }
        }
        .padding(PrismSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
                .fill(PrismColor.surfaceSecondary)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(model.id)
    }
}

// MARK: - 4. PrismSkeleton View (§19, §29)

public struct PrismSkeleton: View {
    private let model: PrismSkeletonModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    public init(model: PrismSkeletonModel) {
        self.model = model
    }

    public init(
        rows: Int = 3,
        learningTip: String? = nil,
        elapsedSeconds: Double = 0
    ) {
        self.model = PrismSkeletonModel(
            rows: rows,
            learningTip: learningTip,
            elapsedSeconds: elapsedSeconds
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            ForEach(0..<model.rows, id: \.self) { index in
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                        .fill(PrismColor.surfaceSecondary)
                        .frame(height: PrismSize.progressBarHeight)

                    RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                        .fill(PrismColor.surfaceSecondary)
                        .frame(height: PrismSize.minTapTarget)
                }
                .opacity(isPulsing && !reduceMotion ? 0.55 : 0.9)
                .accessibilityHidden(index > 0)
            }

            if model.shouldDisplayLearningTip, let tip = model.learningTip {
                HStack(spacing: PrismSpacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(PrismColor.brandPrimary)
                        .accessibilityHidden(true)

                    Text(verbatim: tip)
                        .prismTextStyle(.footnote)
                        .foregroundStyle(PrismColor.inkSecondary)
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                        .fill(PrismColor.surfaceElevated)
                )
            }
        }
        .padding(PrismSpacing.md)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(PrismMotion.resolve(.standard, reduceMotion: reduceMotion).animation) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.shouldDisplayLearningTip ? (model.learningTip ?? "Chargement de la séance") : "Chargement de la séance"))
        .accessibilityIdentifier(model.id)
    }
}

// MARK: - 5. PrismToast View (§19, §29)

public struct PrismToast: View {
    private let model: PrismToastModel
    private let onAction: (() -> Void)?
    private let onDismiss: () -> Void

    public init(
        model: PrismToastModel,
        onAction: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    private var accentColor: Color {
        model.region?.color ?? PrismColor.brandPrimary
    }

    public var body: some View {
        PrismAdaptiveStack(spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: model.symbolName)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: model.title)
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.inkPrimary)

                    Text(verbatim: model.message)
                        .prismTextStyle(.footnote)
                        .foregroundStyle(PrismColor.inkSecondary)
                }
            }

            Spacer(minLength: PrismSpacing.xs)

            HStack(spacing: PrismSpacing.xs) {
                if let actionTitle = model.actionTitle, let onAction {
                    Button(action: onAction) {
                        Text(verbatim: actionTitle)
                            .prismTextStyle(.footnote)
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, PrismSpacing.sm)
                            .padding(.vertical, PrismSpacing.xs)
                            .frame(minHeight: PrismSize.minTapTarget)
                    }
                    .buttonStyle(.plain)
                }

                if model.isDismissibleInOneTap {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundStyle(PrismColor.inkSecondary)
                            .padding(PrismSpacing.xs)
                            .frame(minWidth: PrismSize.minTapTarget, minHeight: PrismSize.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "Fermer la notification"))
                }
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.card, style: .continuous)
                .fill(PrismColor.surfaceElevated)
        )
        .gesture(
            DragGesture()
                .onEnded { _ in
                    if model.isDismissibleInOneTap {
                        onDismiss()
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(verbatim: "Fermer")) {
            onDismiss()
        }
        .accessibilityIdentifier(model.id)
    }
}

// MARK: - 6. PrismCelebration View (§9, §19, §25, §26, §28)

public struct PrismCelebration: View {
    private let config: PrismCelebrationConfig
    private let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var environmentReduceMotion
    @State private var isAppearing = false
    @State private var didAnnounceVoiceOver = false

    public init(
        config: PrismCelebrationConfig,
        onDismiss: @escaping () -> Void
    ) {
        self.config = config
        self.onDismiss = onDismiss
    }

    private var effectiveReduceMotion: Bool {
        config.reduceMotion || environmentReduceMotion
    }

    private var resolvedLevel: PrismCelebrationLevel {
        config.resolvedLevel
    }

    private var levelSymbolName: String {
        switch resolvedLevel {
        case .tick:
            return "checkmark.circle.fill"
        case .pulse:
            return "wave.3.Forward.circle.fill"
        case .refraction:
            return "sparkles"
        case .milestone:
            return "seal.fill"
        }
    }

    public var body: some View {
        Button(action: onDismiss) {
            VStack(alignment: .center, spacing: PrismSpacing.md) {
                HStack(spacing: PrismSpacing.xs) {
                    Image(systemName: levelSymbolName)
                        .foregroundStyle(config.region.color)
                        .accessibilityHidden(true)

                    Text(verbatim: config.region.displayName)
                        .prismTextStyle(.caption)
                        .foregroundStyle(config.region.color)

                    if config.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .foregroundStyle(PrismColor.inkSecondary)
                            .accessibilityLabel(Text(verbatim: "Mode silencieux"))
                    }
                }

                Text(verbatim: config.title)
                    .prismTextStyle(.title2)
                    .foregroundStyle(PrismColor.inkPrimary)
                    .multilineTextAlignment(.center)

                if let subtitle = config.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .prismTextStyle(.body)
                        .foregroundStyle(PrismColor.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                Text(verbatim: "Toucher pour continuer")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.inkSecondary)
            }
            .padding(PrismSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.heroCard, style: .continuous)
                    .fill(PrismColor.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.heroCard, style: .continuous)
                            .strokeBorder(config.region.color)
                    )
            )
            .opacity(isAppearing ? 1.0 : 0.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            let motion = PrismMotion.resolve(.expressive, reduceMotion: effectiveReduceMotion)
            withAnimation(motion.animation) {
                isAppearing = true
            }
            if !didAnnounceVoiceOver {
                didAnnounceVoiceOver = true
                UIAccessibility.post(
                    notification: .announcement,
                    argument: config.voiceOverAnnouncement.formattedSpeech
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: config.voiceOverAnnouncement.formattedSpeech))
        .accessibilityHint(Text(verbatim: "Touchez deux fois pour fermer la célébration"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(config.id)
    }
}

// MARK: - 7. PrismShareCardView & ShareCardRenderer (§15 NS-7, §19, §22A.7)

public struct PrismShareCardView: View {
    private let payload: PrismShareCardPayload

    public init(payload: PrismShareCardPayload) {
        self.payload = payload
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                PrismCrestView(region: payload.region)

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: payload.region.displayName)
                        .prismTextStyle(.caption)
                        .foregroundStyle(payload.region.color)

                    Text(verbatim: payload.milestoneBadge)
                        .prismTextStyle(.footnote)
                        .foregroundStyle(PrismColor.inkSecondary)
                }

                Spacer(minLength: PrismSpacing.xs)

                if let streakDays = payload.streakDays, streakDays > 0 {
                    Text(verbatim: "\(streakDays) j")
                        .prismTextStyle(.callout)
                        .foregroundStyle(payload.region.color)
                        .padding(.horizontal, PrismSpacing.sm)
                        .padding(.vertical, PrismSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.chip, style: .continuous)
                                .fill(PrismColor.surfaceSecondary)
                        )
                }
            }

            Text(verbatim: payload.title)
                .prismTextStyle(.title3)
                .foregroundStyle(PrismColor.inkPrimary)

            Text(verbatim: payload.sanitizedSynthesis)
                .prismTextStyle(.body)
                .foregroundStyle(PrismColor.inkSecondary)

            HStack(spacing: PrismSpacing.xs) {
                Image(systemName: "LOCK.shield".lowercased())
                    .foregroundStyle(PrismColor.feedbackSuccess)
                    .accessibilityHidden(true)

                Text(verbatim: "Synthèse Certigo Prism · garantie sans spoiler")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.inkSecondary)
            }
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.heroCard, style: .continuous)
                .fill(PrismColor.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.heroCard, style: .continuous)
                        .strokeBorder(payload.region.color)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(payload.id)
    }
}

public enum ShareCardRenderer {
    @MainActor
    public static func renderImage(
        payload: PrismShareCardPayload,
        configuration: PrismSnapshotConfiguration = .iPhoneLightStandard
    ) -> UIImage? {
        guard payload.isSpoilerFree else {
            return nil
        }
        let view = PrismShareCardView(payload: payload)
        let renderer = ImageRenderer(
            content: view
                .environment(\.colorScheme, configuration.isDarkMode ? .dark : .light)
        )
        renderer.scale = configuration.scale
        return renderer.uiImage
    }
}

// MARK: - 8. PrismAdaptiveStack (§19, §28)

public struct PrismAdaptiveStack<Content: View>: View {
    private let horizontalAlignment: HorizontalAlignment
    private let verticalAlignment: VerticalAlignment
    private let spacing: CGFloat
    private let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        horizontalAlignment: HorizontalAlignment = .leading,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat = PrismSpacing.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content()
    }

    public var resolvedAxis: PrismAdaptiveAxis {
        PrismAdaptiveStackPolicy.resolvedAxis(isAccessibilityCategory: dynamicTypeSize.isAccessibilitySize)
    }

    public var body: some View {
        let layout = resolvedAxis == .vertical
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout {
            content
        }
    }
}

// MARK: - 9. Rotor & Accessibility View Modifiers (§19, §28)

private struct PrismLineRotorModifier: ViewModifier {
    let title: String
    let entries: [PrismAccessibilityRotorEntry]
    let onSelect: ((PrismAccessibilityRotorEntry) -> Void)?

    func body(content: Content) -> some View {
        content.accessibilityRotor(Text(verbatim: title)) {
            ForEach(entries) { entry in
                AccessibilityRotorEntry(Text(verbatim: entry.spokenSummary), id: entry.id) {
                    onSelect?(entry)
                }
            }
        }
    }
}

private struct PrismAccessibilityActionsModifier: ViewModifier {
    let actions: [PrismAccessibilityAction]

    func body(content: Content) -> some View {
        actions.reduce(AnyView(content)) { currentView, action in
            AnyView(
                currentView.accessibilityAction(named: Text(verbatim: action.name)) {
                    _ = action.handler()
                }
            )
        }
    }
}

private struct PrismAccessibilityAnnouncementModifier: ViewModifier {
    let announcement: PrismAccessibilityAnnouncement?
    @State private var ledger = PrismAnnouncementLedger()

    func body(content: Content) -> some View {
        content
            .onAppear {
                postIfNeeded(announcement)
            }
            .onChange(of: announcement) { _, newValue in
                postIfNeeded(newValue)
            }
    }

    private func postIfNeeded(_ candidate: PrismAccessibilityAnnouncement?) {
        guard let candidate else { return }
        if ledger.shouldDeliver(candidate) {
            UIAccessibility.post(
                notification: .announcement,
                argument: candidate.formattedSpeech
            )
        }
    }
}

public extension View {
    func prismLineRotor(
        title: String = "Lignes et concepts",
        entries: [PrismAccessibilityRotorEntry],
        onSelect: ((PrismAccessibilityRotorEntry) -> Void)? = nil
    ) -> some View {
        modifier(
            PrismLineRotorModifier(
                title: title,
                entries: entries,
                onSelect: onSelect
            )
        )
    }

    func prismAccessibilityActions(
        _ actions: [PrismAccessibilityAction]
    ) -> some View {
        modifier(PrismAccessibilityActionsModifier(actions: actions))
    }

    func prismAccessibilityAnnouncement(
        _ announcement: PrismAccessibilityAnnouncement?
    ) -> some View {
        modifier(PrismAccessibilityAnnouncementModifier(announcement: announcement))
    }
}

// MARK: - 11. Previews (Nominal, Vide, Chargement, Erreur, AX3, Sombre)

#Preview("Nominal — Celebration, ShareCard & Toast") {
    ScrollView {
        VStack(spacing: PrismSpacing.lg) {
            PrismOfflineBanner(
                model: PrismOfflineBannerModel(
                    cachedPlayableSessionsCount: 3,
                    queuedSubmissionsCount: 2
                )
            )

            PrismToast(
                model: .guestSaveInvitation(region: .azure),
                onAction: {},
                onDismiss: {}
            )

            PrismCelebration(
                config: PrismCelebrationConfig(
                    level: .refraction,
                    calmMode: false,
                    region: .security,
                    title: "Maîtrise Identité validée",
                    subtitle: "Région Sécurité consolidée sans indice."
                ),
                onDismiss: {}
            )

            PrismShareCardView(
                payload: PrismShareCardPayload(
                    title: "Cap Architecture Cloud franchi",
                    region: .azure,
                    synthesis: "Progression régulière sur les fondations réseau et résilience.",
                    milestoneBadge: "Palier Prism",
                    streakDays: 7
                )
            )
        }
        .padding(PrismSpacing.lg)
    }
    .background(PrismColor.surfacePrimary)
}

#Preview("Vide — Standard & Format non pris en charge") {
    VStack(spacing: PrismSpacing.lg) {
        PrismEmptyState(
            model: PrismEmptyStateModel(
                title: "Aucune révision en attente",
                valueProposition: "Lance un rituel court pour ancrer tes acquis du jour.",
                actionTitle: "Démarrer un rituel",
                region: .ai
            ),
            onAction: {}
        )

        PrismEmptyState(
            model: .unsupportedFormat(formatName: "Lab interactif 3D", region: .networking),
            onAction: {}
        )
    }
    .padding(PrismSpacing.lg)
    .background(PrismColor.surfacePrimary)
}

#Preview("Chargement — Squelette avec astuce") {
    PrismSkeleton(
        rows: 3,
        learningTip: "Astuce : privilégie le moindre privilège sur chaque rôle d'identité.",
        elapsedSeconds: 1.8
    )
    .padding(PrismSpacing.lg)
    .background(PrismColor.surfacePrimary)
}

#Preview("Erreur — Rassurante avec code technique") {
    PrismErrorState(
        model: PrismErrorStateModel(
            technicalCode: "SYNC-HTTP-503-RETRYABLE"
        ),
        onRetry: {}
    )
    .padding(PrismSpacing.lg)
    .background(PrismColor.surfacePrimary)
}

#Preview("Accessibilité AX3 — AdaptiveStack & Rotor") {
    VStack(spacing: PrismSpacing.lg) {
        PrismEmptyState(
            model: .unsupportedFormat(formatName: "Schéma topologique", region: .data),
            onAction: {}
        )
        PrismErrorState(
            model: PrismErrorStateModel(technicalCode: "ERR-AX3-408"),
            onRetry: {}
        )
    }
    .padding(PrismSpacing.lg)
    .background(PrismColor.surfacePrimary)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Sombre — Mode Calme & Hors ligne") {
    VStack(spacing: PrismSpacing.lg) {
        PrismOfflineBanner(
            model: PrismOfflineBannerModel(
                cachedPlayableSessionsCount: 2,
                queuedSubmissionsCount: 4
            )
        )
        PrismCelebration(
            config: PrismCelebrationConfig(
                level: .milestone,
                calmMode: true,
                isMuted: true,
                region: .devOps,
                title: "Rituel complété en Mode Calme",
                subtitle: "Plafonné automatiquement au niveau Pulse."
            ),
            onDismiss: {}
        )
    }
    .padding(PrismSpacing.lg)
    .background(PrismColor.surfacePrimary)
    .preferredColorScheme(.dark)
}
#endif
