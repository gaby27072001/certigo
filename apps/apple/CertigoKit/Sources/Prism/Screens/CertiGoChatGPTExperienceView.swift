import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation

// MARK: - 1. Pure Optical & Layout Specifications for ChatGPT iOS x Duolingo Liquid Glass (`CertiGoChatGPTLiquidGlassChromeSpec`)

/// Dynamic state of the 34x34 pt right-hand circular action button inside the floating ChatGPT bottom pill.
public enum CertiGoChatGPTActionCircleState: String, Codable, Equatable, Sendable, CaseIterable {
    /// Empty text field & idle: blue circle `#007AFF` with white `waveform` icon (opens interactive voice orb).
    case voiceWaveform
    /// Non-empty text field & idle: blue circle `#007AFF` with white `arrow.up` (`15 pt .bold`).
    case sendArrowUp
    /// Response currently streaming: blue circle `#007AFF` with white square `stop.fill` (`11 pt`).
    case stopSquare

    public var sfSymbolName: String {
        switch self {
        case .voiceWaveform: return "waveform"
        case .sendArrowUp: return "arrow.up"
        case .stopSquare: return "stop.fill"
        }
    }

    public var symbolPointSize: CGFloat {
        switch self {
        case .voiceWaveform: return FigMetrics.fifteen
        case .sendArrowUp: return FigMetrics.fifteen
        case .stopSquare: return FigMetrics.eleven
        }
    }

    public var accessibilityLabelFR: String {
        switch self {
        case .voiceWaveform: return "Mode vocal interactif"
        case .sendArrowUp: return "Envoyer la question"
        case .stopSquare: return "Arrêter la génération"
        }
    }

    public static func resolve(draftText: String, isStreaming: Bool) -> CertiGoChatGPTActionCircleState {
        if isStreaming {
            return .stopSquare
        }
        let hasText = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText ? .sendArrowUp : .voiceWaveform
    }
}

/// Thumbs-up / thumbs-down evaluation state for an AI response turn.
public enum CertiGoChatGPTTurnFeedback: String, Codable, Equatable, Sendable {
    case thumbsUp
    case thumbsDown
}

/// Quick actions available from the `+` button on the left of the floating ChatGPT input bar.
public enum CertiGoChatGPTQuickAction: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case explainConcept
    case createMemoCard
    case simulateTrapQuestion
    case compareTechnologies

    public var id: String { rawValue }

    public var titleFR: String {
        switch self {
        case .explainConcept: return "Expliquer un concept"
        case .createMemoCard: return "Créer une fiche mémo"
        case .simulateTrapQuestion: return "Simuler une question piège"
        case .compareTechnologies: return "Comparer deux technologies"
        }
    }

    public var subtitleFR: String {
        switch self {
        case .explainConcept: return "Analogie claire, architecture et règles clés"
        case .createMemoCard: return "Synthèse structurée prête pour la révision"
        case .simulateTrapQuestion: return "Scénario officiel avec correction détaillée"
        case .compareTechnologies: return "Différences décisives le jour de l'examen"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .explainConcept: return "sparkles"
        case .createMemoCard: return "doc.text.fill"
        case .simulateTrapQuestion: return "bolt.shield.fill"
        case .compareTechnologies: return "arrow.left.arrow.right"
        }
    }

    public var accentHex: String {
        switch self {
        case .explainConcept: return "#007AFF"
        case .createMemoCard: return "#10A37F"
        case .simulateTrapQuestion: return "#EA580C"
        case .compareTechnologies: return "#4F46E5"
        }
    }

    public func promptForRoute(_ routeCode: String) -> String {
        switch self {
        case .explainConcept:
            return "Explique-moi le concept le plus important de la certification \(routeCode) avec une analogie simple et les étapes clés."
        case .createMemoCard:
            return "Crée une fiche mémo complète pour \(routeCode) avec les ingrédients techniques et les instructions étape par étape."
        case .simulateTrapQuestion:
            return "Simule une question piège d'examen \(routeCode) et détaille pourquoi les autres options sont fausses."
        case .compareTechnologies:
            return "Compare les deux services ou architectures les plus souvent confondus à l'examen \(routeCode)."
        }
    }
}

/// Secondary actions inside the `•••` (`ellipsis`) menu beneath each AI response.
public enum CertiGoChatGPTResponseMoreAction: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case regenerateResponse
    case deepenWithConcreteExample
    case testWithOneExamQuestion

    public var id: String { rawValue }

    public var titleFR: String {
        switch self {
        case .regenerateResponse: return "Régénérer la réponse"
        case .deepenWithConcreteExample: return "Approfondir avec un exemple concret"
        case .testWithOneExamQuestion: return "Me tester avec 1 question d'examen"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .regenerateResponse: return "arrow.clockwise"
        case .deepenWithConcreteExample: return "lightbulb.max"
        case .testWithOneExamQuestion: return "checkmark.seal.fill"
        }
    }
}

/// Pure, deterministic optical and geometric specifications for the ChatGPT iOS x Duolingo Liquid Glass experience.
public struct CertiGoChatGPTLiquidGlassChromeSpec: Equatable, Sendable {
    // 1. Canvas & Full-Bleed AI Response (never enclosed in a bubble or card)
    public static let lightCanvasHex: String = "#FFFFFF"
    public static let darkCanvasHex: String = "#000000"
    public static let responseHorizontalPadding: CGFloat = FigMetrics.twenty
    public static let isResponseEnclosedInBubbleOrCard: Bool = false

    // 2. Top Floating Bar (`ZStack` overlay with `.ultraThinMaterial` Liquid Glass)
    public static let topLeftMenuButtonDiameter: CGFloat = FigMetrics.forty
    public static let topLeftMenuTopLineWidth: CGFloat = FigMetrics.sixteen
    public static let topLeftMenuBottomLineWidth: CGFloat = FigMetrics.ten
    public static let topLeftMenuLineThickness: CGFloat = FigMetrics.two
    public static let topLeftMenuLineSpacing: CGFloat = FigMetrics.five
    public static let topFloatingShadowOpacity: Double = 0.08
    public static let topFloatingShadowRadius: CGFloat = FigMetrics.eight
    public static let topFloatingShadowY: CGFloat = FigMetrics.two

    public static let centerTrackPillHeight: CGFloat = FigMetrics.forty
    public static let centerTrackPillCornerRadius: CGFloat = FigMetrics.twenty
    public static let chatGPTBlueHex: String = "#007AFF"

    public static let topRightCapsuleHeight: CGFloat = FigMetrics.forty
    public static let topRightCapsuleCornerRadius: CGFloat = FigMetrics.twenty
    public static let topRightCapsuleIconSpacing: CGFloat = FigMetrics.sixteen
    public static let topRightCapsuleHorizontalPadding: CGFloat = FigMetrics.fourteen
    public static let topRightIconPointSize: CGFloat = FigMetrics.seventeen
    public static let topRightNewChatSymbol: String = "square.and.pencil"
    public static let topRightOptionsSymbol: String = "ellipsis"

    // 3. User Message Bubble (top-right aligned)
    public static let userBubbleMinLeadingSpacer: CGFloat = FigMetrics.sixty
    public static let userBubbleCornerRadius: CGFloat = FigMetrics.twentyTwo
    public static let userBubbleHorizontalPadding: CGFloat = FigMetrics.sixteen
    public static let userBubbleVerticalPadding: CGFloat = FigMetrics.eleven
    public static let userBubbleLightFillHex: String = "#EBF5FF"
    public static let userBubbleDarkFillHex: String = "#1E293B"
    public static let userBubbleLightTextHex: String = "#0958A5"
    public static let userBubbleDarkTextHex: String = "#93C5FD"
    public static let userBubbleFontSize: CGFloat = 16.5
    public static let userBubbleLineSpacing: CGFloat = FigMetrics.three

    // 4. Reasoning Phase ("Réflexion pendant Xs" / "Working for Xs") & Scroll-to-Bottom Button (`↓`)
    public static let reasoningFontSize: CGFloat = FigMetrics.fourteen
    public static let reasoningTextHex: String = "#8E8E93"
    public static let streamingTickMilliseconds: Int = 25
    public static let scrollToBottomButtonDiameter: CGFloat = FigMetrics.thirtySix
    public static let scrollToBottomIconName: String = "arrow.down"
    public static let scrollToBottomIconPointSize: CGFloat = FigMetrics.fourteen
    public static let scrollToBottomIconHex: String = "#0D0D0D"

    // 5. Editorial Typography (`☕ Cafe Mocha` reference screen)
    public static let h2TitleFontSize: CGFloat = FigMetrics.twenty
    public static let h2TitleBottomPadding: CGFloat = FigMetrics.six
    public static let primaryInkLightHex: String = "#0D0D0D"
    public static let primaryInkDarkHex: String = "#F9FAFB"
    public static let bodyAndMetadataFontSize: CGFloat = 16.5
    public static let metadataLineSpacing: CGFloat = FigMetrics.four
    public static let h3SectionFontSize: CGFloat = FigMetrics.eighteen
    public static let h3SectionTopPadding: CGFloat = FigMetrics.eighteen
    public static let h3SectionBottomPadding: CGFloat = FigMetrics.eight
    public static let bulletDotDiameter: CGFloat = FigMetrics.six
    public static let bulletDotTopOffset: CGFloat = FigMetrics.eight
    public static let bulletHorizontalSpacing: CGFloat = FigMetrics.twelve
    public static let bulletLineSpacing: CGFloat = FigMetrics.four
    public static let bulletItemVerticalSpacing: CGFloat = FigMetrics.eight
    public static let numberedPrefixWidth: CGFloat = FigMetrics.twentyFour
    public static let numberedStepVerticalSpacing: CGFloat = FigMetrics.ten

    // 6. Action Bar & Conversation Evaluation Card
    public static let actionBarIconSpacing: CGFloat = FigMetrics.eighteen
    public static let actionBarIconPointSize: CGFloat = FigMetrics.fifteen
    public static let actionBarIconHex: String = "#6E6E80"
    public static let actionBarSymbols: [String] = [
        "doc.on.doc",
        "speaker.wave.2",
        "hand.thumbsup",
        "hand.thumbsdown",
        "square.and.arrow.up",
        "ellipsis"
    ]
    public static let evaluationCardLightHex: String = "#F4F4F4"
    public static let evaluationCardDarkHex: String = "#1C1C1E"
    public static let evaluationCardCornerRadius: CGFloat = FigMetrics.sixteen
    public static let evaluationCardHorizontalPadding: CGFloat = FigMetrics.sixteen
    public static let evaluationCardVerticalPadding: CGFloat = FigMetrics.twelve

    // 7. Bottom Floating Pill (`Ask ChatGPT` / `Demander à CertiGo IA`)
    public static let bottomPillMinHeight: CGFloat = FigMetrics.fiftyTwo
    public static let bottomPillCornerRadius: CGFloat = FigMetrics.twentySix
    public static let bottomPillHorizontalPadding: CGFloat = FigMetrics.fourteen
    public static let bottomPillLightFillHex: String = "#FFFFFF"
    public static let bottomPillDarkFillHex: String = "#1C1C1E"
    public static let bottomPillShadowOpacity: Double = 0.08
    public static let bottomPillShadowRadius: CGFloat = FigMetrics.twelve
    public static let bottomPillShadowY: CGFloat = FigMetrics.three
    public static let bottomPlusIconSize: CGFloat = FigMetrics.twenty
    public static let bottomMicIconSize: CGFloat = FigMetrics.nineteen
    public static let bottomActionCircleDiameter: CGFloat = FigMetrics.thirtyFour

    public static func centerPillTitle(forRouteCode routeCode: String) -> String {
        "✦ CertiGo GPT • \(routeCode)"
    }

    public static func inputPlaceholder(hasExistingTurns: Bool, isStreaming: Bool) -> String {
        if isStreaming || hasExistingTurns {
            return "Poser une question de suivi · Follow up"
        }
        return "Demander à CertiGo IA"
    }
}

// MARK: - 2. Expandable Reasoning Steps (`"Réflexion pendant 2s"` / `"Working for 2s"`)

public struct CertiGoChatGPTReasoningStep: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let sfSymbolName: String
    public let title: String
    public let detail: String

    public init(id: String, sfSymbolName: String, title: String, detail: String) {
        self.id = id
        self.sfSymbolName = sfSymbolName
        self.title = title
        self.detail = detail
    }

    public static func defaultSteps(forRouteCode routeCode: String) -> [CertiGoChatGPTReasoningStep] {
        [
            CertiGoChatGPTReasoningStep(
                id: "step-official-syllabus-\(routeCode)",
                sfSymbolName: "folder",
                title: "Analyse du référentiel officiel \(routeCode) ›",
                detail: "Vérification des domaines pondérés, des limites de service et de l'architecture cible."
            ),
            CertiGoChatGPTReasoningStep(
                id: "step-exam-traps-\(routeCode)",
                sfSymbolName: "book.closed",
                title: "Synthèse des points clés et pièges d'examen ›",
                detail: "Extraction des règles éliminatoires et structuration étape par étape."
            ),
            CertiGoChatGPTReasoningStep(
                id: "step-duolingo-pedagogy-\(routeCode)",
                sfSymbolName: "sparkles",
                title: "Mise en forme éditoriale claire ›",
                detail: "Hiérarchie H2/H3, ingrédients clés et instructions numérotées directement applicables."
            )
        ]
    }
}

// MARK: - 3. Editorial Rich Response Parser (`CertiGoChatGPTRichDocument`)

/// Key-value metadata pair displayed right below the H2 emoji title (`Makes: 1 serving` / `Certification: AZ-900`).
public struct CertiGoChatGPTMetadataLine: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "\(key):\(value)" }
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Bullet item with optional bold lead-in or highlighted terms.
public struct CertiGoChatGPTBulletItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let boldPrefix: String?
    public let bodyText: String

    public init(id: String, boldPrefix: String? = nil, bodyText: String) {
        self.id = id
        self.boldPrefix = boldPrefix
        self.bodyText = bodyText
    }

    public var fullPlainText: String {
        if let boldPrefix, !boldPrefix.isEmpty {
            return "\(boldPrefix) \(bodyText)".trimmingCharacters(in: .whitespaces)
        }
        return bodyText
    }
}

/// Numbered instruction step (`1. Make the chocolate base: Add chocolate syrup...`).
public struct CertiGoChatGPTNumberedStep: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "step-\(number)" }
    public let number: Int
    public let boldLeadInWithColon: String
    public let explanationText: String

    public init(number: Int, boldLeadInWithColon: String, explanationText: String) {
        self.number = number
        self.boldLeadInWithColon = boldLeadInWithColon
        self.explanationText = explanationText
    }

    public var fullPlainText: String {
        if explanationText.isEmpty {
            return "\(number). \(boldLeadInWithColon)"
        }
        return "\(number). \(boldLeadInWithColon) \(explanationText)"
    }
}

/// Structured editorial document reproducing the exact hierarchy of ChatGPT iOS (`☕ Cafe Mocha` reference screen).
public struct CertiGoChatGPTRichDocument: Equatable, Sendable {
    public let emojiAndH2Title: String
    public let metadataLines: [CertiGoChatGPTMetadataLine]
    public let ingredientsHeading: String
    public let bulletItems: [CertiGoChatGPTBulletItem]
    public let instructionsHeading: String
    public let numberedSteps: [CertiGoChatGPTNumberedStep]
    public let closingCallout: String?

    public init(
        emojiAndH2Title: String,
        metadataLines: [CertiGoChatGPTMetadataLine],
        ingredientsHeading: String = "Points clés à retenir",
        bulletItems: [CertiGoChatGPTBulletItem],
        instructionsHeading: String = "Méthode étape par étape",
        numberedSteps: [CertiGoChatGPTNumberedStep],
        closingCallout: String? = nil
    ) {
        self.emojiAndH2Title = emojiAndH2Title
        self.metadataLines = metadataLines
        self.ingredientsHeading = ingredientsHeading
        self.bulletItems = bulletItems
        self.instructionsHeading = instructionsHeading
        self.numberedSteps = numberedSteps
        self.closingCallout = closingCallout
    }

    /// Flattened word list used by the 25ms progressive token streamer.
    public var allWords: [String] {
        fullPlainText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    public var fullPlainText: String {
        var lines: [String] = [emojiAndH2Title]
        for meta in metadataLines {
            lines.append("\(meta.key): \(meta.value)")
        }
        if !bulletItems.isEmpty {
            lines.append(ingredientsHeading)
            for b in bulletItems {
                lines.append("• \(b.fullPlainText)")
            }
        }
        if !numberedSteps.isEmpty {
            lines.append(instructionsHeading)
            for s in numberedSteps {
                lines.append(s.fullPlainText)
            }
        }
        if let closingCallout, !closingCallout.isEmpty {
            lines.append(closingCallout)
        }
        return lines.joined(separator: "\n")
    }
}

public enum CertiGoChatGPTRichResponseParser {
    /// Returns the appropriate leading emoji for a certification track or prompt topic.
    public static func leadingEmoji(forRouteCode routeCode: String, prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("mocha") || lower.contains("café") || lower.contains("cafe") {
            return "☕"
        }
        if lower.contains("sécurité") || lower.contains("verrou") || lower.contains("rbac") || lower.contains("iam") {
            return "🛡️"
        }
        if lower.contains("réseau") || lower.contains("vnet") || lower.contains("dns") || lower.contains("vpc") {
            return "🌐"
        }
        if lower.contains("cli") || lower.contains("code") || lower.contains("bicep") || lower.contains("terraform") {
            return "⚡"
        }
        if routeCode.hasPrefix("AI-") || routeCode.contains("OPENAI") || routeCode.contains("ANTHROPIC") || routeCode.contains("COPILOT") {
            return "✦"
        }
        if routeCode.contains("HARVEY") {
            return "⚖️"
        }
        if routeCode.contains("CKA") || routeCode.contains("CKAD") || routeCode.contains("CKS") {
            return "☸️"
        }
        return "☁️"
    }

    /// Builds a structured `CertiGoChatGPTRichDocument` from a `CertiGoChatTurn` and active certification route code.
    public static func parse(turn: CertiGoChatTurn, routeCode: String) -> CertiGoChatGPTRichDocument {
        let cleanHeadline = CertiGoNativeAppState.sanitizeAIMarkdown(turn.aiHeadline)
        let emoji = leadingEmoji(forRouteCode: routeCode, prompt: turn.userPrompt + " " + cleanHeadline)

        // Derive a crisp H2 title
        let rawH2: String = {
            let firstLine = cleanHeadline.components(separatedBy: "\n").first ?? cleanHeadline
            let trimmed = firstLine
                .replacingOccurrences(of: "Voici l'analyse architecturale CertiGo IA pour ", with: "")
                .replacingOccurrences(of: "« ", with: "")
                .replacingOccurrences(of: " »", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " :."))
            if trimmed.isEmpty {
                return "Synthèse Architecturale (\(routeCode))"
            }
            if trimmed.count > 68 {
                let words = trimmed.split(separator: " ").prefix(9).joined(separator: " ")
                return words
            }
            return trimmed
        }()

        let h2WithEmoji: String = {
            if let firstScalar = rawH2.unicodeScalars.first,
               firstScalar.properties.isEmojiPresentation || firstScalar.value > 0x2600 {
                return rawH2
            }
            return "\(emoji) \(rawH2)"
        }()

        let domainLabel = domainName(forRouteCode: routeCode, prompt: turn.userPrompt)
        let metadataLines: [CertiGoChatGPTMetadataLine] = [
            CertiGoChatGPTMetadataLine(key: "Certification", value: "\(routeCode) • \(domainLabel)"),
            CertiGoChatGPTMetadataLine(key: "Temps de révision", value: "2 minutes • Format Examen Officiel")
        ]

        // Collect candidate bullets and numbered instructions
        var rawBullets: [String] = []
        let headlineLines = cleanHeadline.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        if headlineLines.count > 1 {
            rawBullets.append(contentsOf: headlineLines.dropFirst())
        }
        for candidate in [turn.aiBullet1, turn.aiBullet2] + turn.extraPoints + [turn.examKeyRule1, turn.examKeyRule2] {
            let sanitized = CertiGoNativeAppState.sanitizeAIMarkdown(candidate)
            for line in sanitized.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    rawBullets.append(trimmed)
                }
            }
        }

        // Partition into conceptual bullet items ("Points clés à maîtriser") and actionable numbered steps ("Instructions & Réflexes d'examen")
        var bulletItems: [CertiGoChatGPTBulletItem] = []
        var numberedSteps: [CertiGoChatGPTNumberedStep] = []

        for (index, rawLine) in rawBullets.enumerated() {
            let stripped = stripLeadingMarkers(from: rawLine)
            guard !stripped.isEmpty else { continue }

            let (leadIn, remainder) = splitLeadInAndExplanation(stripped)
            if index < 3 && rawBullets.count >= 4 {
                if let leadIn {
                    bulletItems.append(
                        CertiGoChatGPTBulletItem(
                            id: "bullet-\(index)",
                            boldPrefix: "\(leadIn) :",
                            bodyText: remainder
                        )
                    )
                } else {
                    bulletItems.append(
                        CertiGoChatGPTBulletItem(
                            id: "bullet-\(index)",
                            boldPrefix: nil,
                            bodyText: stripped
                        )
                    )
                }
            } else {
                let stepNum = numberedSteps.count + 1
                if let leadIn {
                    numberedSteps.append(
                        CertiGoChatGPTNumberedStep(
                            number: stepNum,
                            boldLeadInWithColon: "\(leadIn) :",
                            explanationText: remainder
                        )
                    )
                } else {
                    let defaultLead = defaultStepLeadIn(forStep: stepNum)
                    numberedSteps.append(
                        CertiGoChatGPTNumberedStep(
                            number: stepNum,
                            boldLeadInWithColon: "\(defaultLead) :",
                            explanationText: stripped
                        )
                    )
                }
            }
        }

        // Ensure both sections always have rich, high-signal items matching the Cafe Mocha editorial structure
        if bulletItems.isEmpty {
            bulletItems = [
                CertiGoChatGPTBulletItem(
                    id: "bullet-fallback-1",
                    boldPrefix: "Principe fondamental :",
                    bodyText: cleanHeadline.isEmpty
                        ? "Appliquer le moindre privilège et l'isolation réseau dès la conception (\(routeCode))."
                        : cleanHeadline
                ),
                CertiGoChatGPTBulletItem(
                    id: "bullet-fallback-2",
                    boldPrefix: "Périmètre d'application :",
                    bodyText: "Priorité aux contrôles déclaratifs (Policy, RBAC/IAM, Private Link) sur les interventions manuelles."
                ),
                CertiGoChatGPTBulletItem(
                    id: "bullet-fallback-3",
                    boldPrefix: "Critère de décision :",
                    bodyText: "Toujours vérifier le SLA composite, le chiffrement de bout en bout et la gouvernance multi-environnements."
                )
            ]
        }

        if numberedSteps.isEmpty {
            numberedSteps = [
                CertiGoChatGPTNumberedStep(
                    number: 1,
                    boldLeadInWithColon: "Identifier la contrainte clé de l'énoncé :",
                    explanationText: "Repère immédiatement si l'exigence porte sur l'identité (RBAC/IAM), l'isolation privée (Private Endpoint) ou la continuité d'activité."
                ),
                CertiGoChatGPTNumberedStep(
                    number: 2,
                    boldLeadInWithColon: "Éliminer les distracteurs classiques :",
                    explanationText: "Écarte toute option qui expose une IP publique ou accorde un rôle Owner/Admin complet sans justification."
                ),
                CertiGoChatGPTNumberedStep(
                    number: 3,
                    boldLeadInWithColon: "Valider la règle d'or \(routeCode) :",
                    explanationText: "Un garde-fou explicite (Deny Assignment, Azure Policy ou verrou CanNotDelete) prime toujours sur une permission héritée."
                )
            ]
        }

        let cleanClosing = CertiGoNativeAppState.sanitizeAIMarkdown(turn.closingTip)
        return CertiGoChatGPTRichDocument(
            emojiAndH2Title: h2WithEmoji,
            metadataLines: metadataLines,
            ingredientsHeading: "Points clés à maîtriser",
            bulletItems: bulletItems,
            instructionsHeading: "Instructions & réflexes d'examen",
            numberedSteps: numberedSteps,
            closingCallout: cleanClosing.isEmpty ? nil : cleanClosing
        )
    }

    public static func stripLeadingMarkers(from line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("•") || result.hasPrefix("-") || result.hasPrefix("*") {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        // Strip leading "1. ", "2. ", etc.
        if let dotIndex = result.firstIndex(of: "."),
           result.distance(from: result.startIndex, to: dotIndex) <= 2,
           result[result.startIndex..<dotIndex].allSatisfy(\.isNumber) {
            let afterDot = result.index(after: dotIndex)
            result = String(result[afterDot...]).trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    public static func splitLeadInAndExplanation(_ text: String) -> (leadIn: String?, explanation: String) {
        guard let colonIndex = text.firstIndex(of: ":") else {
            return (nil, text)
        }
        let distance = text.distance(from: text.startIndex, to: colonIndex)
        guard distance >= 3 && distance <= 58 else {
            return (nil, text)
        }
        let lead = String(text[text.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let afterColon = text.index(after: colonIndex)
        let rest = String(text[afterColon...]).trimmingCharacters(in: .whitespaces)
        guard !lead.isEmpty && !rest.isEmpty else {
            return (nil, text)
        }
        return (lead, rest)
    }

    private static func defaultStepLeadIn(forStep number: Int) -> String {
        switch number {
        case 1: return "Analyser le besoin architectural"
        case 2: return "Appliquer la configuration recommandée"
        case 3: return "Vérifier le piège d'examen"
        default: return "Étape \(number) de validation"
        }
    }

    private static func domainName(forRouteCode routeCode: String, prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("rbac") || lower.contains("policy") || lower.contains("entra") || lower.contains("iam") {
            return "Identité & Gouvernance"
        }
        if lower.contains("vnet") || lower.contains("dns") || lower.contains("endpoint") || lower.contains("gateway") {
            return "Architecture Réseau & Isolation"
        }
        if lower.contains("lock") || lower.contains("verrou") || lower.contains("key vault") {
            return "Sécurité & Protection des ressources"
        }
        return "Architecture & Bonnes Pratiques"
    }
}

// MARK: - 4. Word-by-Word Token Streaming Engine (`CertiGoChatGPTTokenStreamer`)

/// Deterministic state machine for progressive word-by-word token streaming at 25ms cadence with trailing word fade-in.
public struct CertiGoChatGPTTokenStreamer: Equatable, Sendable {
    public static let tickIntervalMilliseconds: Int = 25
    public static let wordsPerTick: Int = 3

    public let turnId: String
    public let tokens: [String]
    public private(set) var visibleTokenCount: Int
    public private(set) var isStreaming: Bool
    public private(set) var wasStoppedByUser: Bool
    public private(set) var reasoningElapsedSeconds: Int

    public init(
        turnId: String,
        fullText: String,
        startImmediatelyCompleted: Bool = false,
        reasoningElapsedSeconds: Int = 2
    ) {
        self.turnId = turnId
        let splitTokens = fullText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        self.tokens = splitTokens
        if startImmediatelyCompleted || splitTokens.isEmpty {
            self.visibleTokenCount = splitTokens.count
            self.isStreaming = false
        } else {
            self.visibleTokenCount = min(Self.wordsPerTick, splitTokens.count)
            self.isStreaming = self.visibleTokenCount < splitTokens.count
        }
        self.wasStoppedByUser = false
        self.reasoningElapsedSeconds = max(1, reasoningElapsedSeconds)
    }

    public var totalTokenCount: Int {
        tokens.count
    }

    /// Fraction in `0.0 ... 1.0` of words revealed so far.
    public var progressFraction: Double {
        guard !tokens.isEmpty else { return 1.0 }
        return min(1.0, max(0.0, Double(visibleTokenCount) / Double(tokens.count)))
    }

    /// Advances the visible token cursor by `wordsPerTick` (called every 25ms).
    public mutating func advanceTick(wordsCount: Int = CertiGoChatGPTTokenStreamer.wordsPerTick) {
        guard isStreaming, !wasStoppedByUser else { return }
        let step = max(1, wordsCount)
        visibleTokenCount = min(tokens.count, visibleTokenCount + step)
        if visibleTokenCount >= tokens.count {
            isStreaming = false
        }
    }

    /// Immediately halts token generation when the user presses the `#007AFF` `stop.fill` square button.
    public mutating func stopByUser() {
        guard isStreaming else { return }
        isStreaming = false
        wasStoppedByUser = true
    }

    /// Completes the full response immediately.
    public mutating func completeAll() {
        visibleTokenCount = tokens.count
        isStreaming = false
    }

    /// Returns the opacity (`0.0 ... 1.0`) for a given 0-based section or item index during streaming,
    /// creating the smooth ChatGPT iOS trailing fade-in effect on the newest words/lines.
    public func itemOpacity(itemOrderIndex: Int, totalItems: Int) -> Double {
        if !isStreaming && !wasStoppedByUser {
            return 1.0
        }
        guard totalItems > 0 else { return 1.0 }
        let revealPosition = progressFraction * Double(totalItems)
        let delta = revealPosition - Double(itemOrderIndex)
        if delta >= 1.0 {
            return 1.0
        } else if delta <= 0.0 {
            return wasStoppedByUser ? 0.0 : 0.12
        } else {
            return max(0.18, min(1.0, delta))
        }
    }

    /// Truncates a string to the currently streamed word budget if streaming was stopped mid-sentence.
    public func streamedSubstring(of text: String, wordBudgetOffset: inout Int) -> String {
        if !isStreaming && !wasStoppedByUser {
            return text
        }
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !words.isEmpty else { return "" }
        let remaining = visibleTokenCount - wordBudgetOffset
        wordBudgetOffset += words.count
        if remaining <= 0 {
            return ""
        }
        if remaining >= words.count {
            return text
        }
        return words.prefix(remaining).joined(separator: " ")
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - 5. ChatGPT iOS x Duolingo Liquid Glass SwiftUI Experience (`CertiGoChatGPTExperienceView`)

public struct CertiGoChatGPTExperienceView: View {
    @Binding public var appState: CertiGoNativeAppState
    public var isInputFocused: FocusState<Bool>.Binding
    public var reduceMotion: Bool
    public var onTriggerLiveAIRequest: () -> Void
    public var onDismissKeyboard: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var streamProgressByTurnId: [String: CertiGoChatGPTTokenStreamer] = [:]
    @State private var activeStreamingTurnId: String? = nil
    @State private var isScrolledAwayFromBottom: Bool = false
    @State private var showCertificationPickerSheet: Bool = false
    @State private var lastPedagogicalToast: String? = nil

    public init(
        appState: Binding<CertiGoNativeAppState>,
        isInputFocused: FocusState<Bool>.Binding,
        reduceMotion: Bool,
        onTriggerLiveAIRequest: @escaping () -> Void,
        onDismissKeyboard: @escaping () -> Void
    ) {
        self._appState = appState
        self.isInputFocused = isInputFocused
        self.reduceMotion = reduceMotion
        self.onTriggerLiveAIRequest = onTriggerLiveAIRequest
        self.onDismissKeyboard = onDismissKeyboard
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var canvasColor: Color {
        PrismColor.figmaHex(
            isDark
                ? CertiGoChatGPTLiquidGlassChromeSpec.darkCanvasHex
                : CertiGoChatGPTLiquidGlassChromeSpec.lightCanvasHex
        )
    }

    private var primaryInkColor: Color {
        PrismColor.figmaHex(
            isDark
                ? CertiGoChatGPTLiquidGlassChromeSpec.primaryInkDarkHex
                : CertiGoChatGPTLiquidGlassChromeSpec.primaryInkLightHex
        )
    }

    private var isAnyTurnCurrentlyStreaming: Bool {
        if let activeId = activeStreamingTurnId,
           let streamer = streamProgressByTurnId[activeId],
           streamer.isStreaming {
            return true
        }
        return appState.chatTurns.last?.isStreamingOrLoading == true
    }

    public var body: some View {
        GeometryReader { geo in
            let safeGeoWidth = geo.size.width.isFinite
                ? max(FigMetrics.twoHundredEighty, geo.size.width)
                : PrismSize.drawerWidth
            let drawerWidth = min(safeGeoWidth * 0.85, PrismSize.drawerWidth)

            ZStack(alignment: .leading) {
                if appState.isShowingVoiceLive06C {
                    chatGPTCloudyBlueVoiceOrbView
                        .transition(.opacity)
                } else {
                    // Main ZStack: Pure #FFFFFF / #000000 canvas + ScrollView underneath + Floating Liquid Glass Top & Bottom Chrome
                    ZStack {
                        canvasColor
                            .ignoresSafeArea()

                        ScrollViewReader { scrollProxy in
                            ZStack(alignment: .bottom) {
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(alignment: .leading, spacing: FigMetrics.twentyFour) {
                                        // Top clearance so content starts below the floating Liquid Glass top bar and scrolls underneath it
                                        Color.clear
                                            .frame(height: FigMetrics.sixty)
                                            .id("chatgpt-scroll-top-anchor")

                                        if appState.isTemporaryAIChatEnabled {
                                            temporaryChatBannerView
                                                .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.responseHorizontalPadding)
                                        }

                                        if let toast = lastPedagogicalToast {
                                            duolingoPedagogicalToastView(toast)
                                                .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.responseHorizontalPadding)
                                        }

                                        if appState.chatTurns.isEmpty {
                                            chatGPTWelcomeCanvasContent
                                        } else {
                                            chatGPTConversationStreamContent(scrollProxy: scrollProxy)
                                        }

                                        // Bottom anchor for instant scroll-to-bottom (`↓`)
                                        Color.clear
                                            .frame(
                                                height: isInputFocused.wrappedValue
                                                    ? FigMetrics.ninetySix
                                                    : FigMetrics.oneHundredSixty
                                            )
                                            .id("chatgpt-scroll-bottom-anchor")
                                    }
                                }
                                .ignoresSafeArea(edges: .bottom)
                                .scrollDismissesKeyboard(.interactively)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: FigMetrics.twelve)
                                        .onChanged { value in
                                            if value.translation.height > FigMetrics.sixteen {
                                                isScrolledAwayFromBottom = true
                                            } else if value.translation.height < -FigMetrics.twentyFour {
                                                isScrolledAwayFromBottom = false
                                            }
                                        }
                                )
                                .onTapGesture {
                                    if isInputFocused.wrappedValue {
                                        onDismissKeyboard()
                                    }
                                }

                                // Floating Bottom Overlay: Scroll-to-Bottom (`↓`) Circle + Floating `Ask ChatGPT` Liquid Glass Pill
                                VStack(spacing: FigMetrics.ten) {
                                    if !appState.chatTurns.isEmpty && (isScrolledAwayFromBottom || isAnyTurnCurrentlyStreaming) {
                                        floatingScrollToBottomButton(scrollProxy: scrollProxy)
                                            .transition(.scale.combined(with: .opacity))
                                    }

                                    floatingBottomAskPillBar(scrollProxy: scrollProxy)
                                }
                                .padding(.horizontal, FigMetrics.sixteen)
                                .padding(
                                    .bottom,
                                    isInputFocused.wrappedValue ? FigMetrics.eight : FigMetrics.eightyEight
                                )
                            }
                            .onChange(of: appState.chatTurns.count) { _, _ in
                                if let latest = appState.chatTurns.last {
                                    startOrRefreshStreaming(for: latest)
                                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                        scrollProxy.scrollTo("chatgpt-scroll-bottom-anchor", anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: appState.chatTurns.last?.aiHeadline) { _, _ in
                                if let latest = appState.chatTurns.last {
                                    startOrRefreshStreaming(for: latest)
                                }
                            }
                        }

                        // Floating Top Bar in ZStack(alignment: .top) with Apple Liquid Glass (`.ultraThinMaterial`)
                        VStack(spacing: FigMetrics.zero) {
                            floatingTopChatGPTBar
                                .padding(.horizontal, FigMetrics.sixteen)
                                .padding(.top, FigMetrics.six)
                            Spacer(minLength: FigMetrics.zero)
                        }
                    }
                    .frame(width: safeGeoWidth)
                    .disabled(appState.isAIDrawerOpen06D)

                    // Backdrop dimmer when History Drawer (`06D`) is open
                    if appState.isAIDrawerOpen06D {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea(.all)
                            .onTapGesture {
                                withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                                    appState.isAIDrawerOpen06D = false
                                }
                            }
                            .transition(.opacity)
                            .zIndex(10)
                    }

                    // Side History & Track Drawer (`06D`)
                    if appState.isAIDrawerOpen06D {
                        chatGPTHistoryDrawerView(width: drawerWidth)
                            .frame(width: drawerWidth)
                            .transition(.move(edge: .leading))
                            .zIndex(11)
                    }
                }
            }
            .onReceive(
                Timer.publish(every: 0.025, on: .main, in: .common).autoconnect()
            ) { _ in
                tickActiveStreamerIfNeeded()
            }
            .sheet(isPresented: $appState.isShowingAIQuickActionsSheet) {
                quickActionsBottomSheetView
                    .presentationDetents([.height(FigMetrics.threeHundredForty), .medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCertificationPickerSheet) {
                certificationPickerSheetView
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 5A. Top Floating Liquid Glass Bar (`=` 2-line menu, `✦ CertiGo GPT • [Code]` pill, `square.and.pencil` + `•••` pill)

    private var floatingTopChatGPTBar: some View {
        HStack(spacing: FigMetrics.eight) {
            // 1. Left Floating Button (40x40 pt Liquid Glass circle with asymmetric 2-line ChatGPT menu icon)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                    CertiGoHapticsEngine.shared.playOptionSelection()
                    onDismissKeyboard()
                    appState.isAIDrawerOpen06D.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuLineSpacing) {
                    Capsule(style: .continuous)
                        .fill(primaryInkColor)
                        .frame(
                            width: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuTopLineWidth,
                            height: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuLineThickness
                        )
                    Capsule(style: .continuous)
                        .fill(primaryInkColor)
                        .frame(
                            width: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuBottomLineWidth,
                            height: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuLineThickness
                        )
                }
                .frame(
                    width: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuButtonDiameter,
                    height: CertiGoChatGPTLiquidGlassChromeSpec.topLeftMenuButtonDiameter
                )
                .background(liquidGlassCircleSurface)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Historique et options")
            .accessibilityIdentifier("hub-ia-hamburger-drawer-button")

            Spacer(minLength: FigMetrics.four)

            // 2. Center Floating Pill (`✦ CertiGo GPT • [Code Certification]`) with blue star `#007AFF`
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                showCertificationPickerSheet = true
            } label: {
                HStack(spacing: FigMetrics.six) {
                    Image(systemName: "sparkles")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))

                    Text(
                        verbatim: CertiGoChatGPTLiquidGlassChromeSpec.centerPillTitle(
                            forRouteCode: appState.activeRouteCode
                        )
                    )
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                    .foregroundStyle(primaryInkColor)
                    .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                }
                .padding(.horizontal, FigMetrics.fourteen)
                .frame(height: CertiGoChatGPTLiquidGlassChromeSpec.centerTrackPillHeight)
                .background(liquidGlassCapsuleSurface)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hub-ia-center-certification-pill")

            Spacer(minLength: FigMetrics.four)

            // 3. Right Floating Capsule (`height: 40 pt`, `cornerRadius: 20 pt`) with `square.and.pencil` & `•••` (`ellipsis`)
            HStack(spacing: CertiGoChatGPTLiquidGlassChromeSpec.topRightCapsuleIconSpacing) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        CertiGoHapticsEngine.shared.playButtonPress()
                        activeStreamingTurnId = nil
                        streamProgressByTurnId.removeAll()
                        appState.chatTurns.removeAll()
                    }
                } label: {
                    Image(systemName: CertiGoChatGPTLiquidGlassChromeSpec.topRightNewChatSymbol)
                        .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.topRightIconPointSize, style: "Medium"))
                        .foregroundStyle(primaryInkColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nouvelle discussion")
                .accessibilityIdentifier("hub-ia-new-thread-button")

                Menu {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.toggleTemporaryAIChat()
                        }
                    } label: {
                        Label(
                            appState.isTemporaryAIChatEnabled
                                ? "Désactiver la discussion éphémère"
                                : "Discussion éphémère (Temporary chat)",
                            systemImage: appState.isTemporaryAIChatEnabled ? "eye.slash.fill" : "eye.slash"
                        )
                    }

                    Button {
                        showCertificationPickerSheet = true
                    } label: {
                        Label("Changer de certification (\(appState.activeRouteCode))", systemImage: "award")
                    }

                    Button {
                        appState.showSavedAIMemosSheet = true
                    } label: {
                        Label("Fiches mémos épinglées (\(appState.savedAIMemos.count))", systemImage: "pin")
                    }

                    if !appState.chatTurns.isEmpty {
                        ShareLink(
                            item: formattedConversationTranscriptForSharing
                        ) {
                            Label("Partager la conversation", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                activeStreamingTurnId = nil
                                streamProgressByTurnId.removeAll()
                                appState.chatTurns.removeAll()
                            }
                        } label: {
                            Label("Effacer l'échange", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: CertiGoChatGPTLiquidGlassChromeSpec.topRightOptionsSymbol)
                        .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.topRightIconPointSize, style: "Medium"))
                        .foregroundStyle(primaryInkColor)
                }
                .accessibilityLabel("Options de la conversation")
                .accessibilityIdentifier("hub-ia-top-options-ellipsis-button")
            }
            .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.topRightCapsuleHorizontalPadding)
            .frame(height: CertiGoChatGPTLiquidGlassChromeSpec.topRightCapsuleHeight)
            .background(liquidGlassCapsuleSurface)
        }
    }

    // MARK: - 5B. Welcome State on Pure Canvas (with Duolingo Pedagogical Clarity & Liquid Glass Prompts)

    private var chatGPTWelcomeCanvasContent: some View {
        let suggestions = CertiGoMultilingualEngine.localizedAICoachSuggestions(
            routeCode: appState.activeRouteCode,
            lang: appState.settingsLanguageIndex
        )
        let trackMeta = CertiGoDedicatedTrackQuestionBank.brandMetadata(forRouteCode: appState.activeRouteCode)

        return VStack(spacing: FigMetrics.twentyFour) {
            if let activeError = appState.activeDiagnosticError {
                CertiGoDiagnosticErrorCardView(
                    error: activeError,
                    isCodeCopied: appState.isErrorCodeCopied,
                    onCopyCode: {
                        appState.isErrorCodeCopied = true
                        UIPasteboard.general.string = activeError.code
                    },
                    onOpenRegistry: {
                        appState.showErrorRegistrySheet = true
                    },
                    onDismiss: {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.activeDiagnosticError = nil
                        }
                    }
                )
            }

            VStack(spacing: FigMetrics.twelve) {
                // Subtle Duolingo x Liquid Glass Emblem
                ZStack {
                    Circle()
                        .fill(PrismColor.figmaHex("#EBF5FF"))
                        .frame(width: FigMetrics.sixtyFour, height: FigMetrics.sixtyFour)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex).opacity(0.28),
                                    lineWidth: FigMetrics.onePointFive
                                )
                        )

                    Image(systemName: "sparkles")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentySix, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                }
                .padding(.top, FigMetrics.sixteen)

                Text(verbatim: "Que révise-t-on sur \(appState.activeRouteCode) ?")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                    .foregroundStyle(primaryInkColor)
                    .multilineTextAlignment(.center)

                Text(
                    verbatim: "\(trackMeta.displayName) • Réponses structurées étape par étape et simulations d'examen."
                )
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, FigMetrics.sixteen)
            }
            .frame(maxWidth: .infinity)

            // 4 Quick-Start Pedagogical Prompts
            VStack(spacing: FigMetrics.ten) {
                ForEach(suggestions, id: \.key) { item in
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.openAITopic(item.key)
                            if let latest = appState.chatTurns.last {
                                startOrRefreshStreaming(for: latest)
                            }
                            onTriggerLiveAIRequest()
                        }
                    } label: {
                        HStack(spacing: FigMetrics.twelve) {
                            Text(verbatim: item.icon)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Regular"))
                                .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                                .background(
                                    Circle()
                                        .fill(PrismColor.figmaHex("#EBF5FF"))
                                )

                            VStack(alignment: .leading, spacing: FigMetrics.two) {
                                Text(verbatim: item.title)
                                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Semi Bold"))
                                    .foregroundStyle(primaryInkColor)
                                    .multilineTextAlignment(.leading)

                                Text(verbatim: item.subtitle)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                                    .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: FigMetrics.eight)

                            Image(systemName: "arrow.up.right")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                        }
                        .padding(.horizontal, FigMetrics.sixteen)
                        .padding(.vertical, FigMetrics.twelve)
                        .background(
                            RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                                .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F9FAFB"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                                .strokeBorder(
                                    isDark ? Color.white.opacity(0.10) : PrismColor.figmaHex("#E5E7EB"),
                                    lineWidth: PrismBorder.thin
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hub-ia-suggestion-\(item.key)")
                }
            }
        }
        .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.responseHorizontalPadding)
    }

    // MARK: - 5C. Multi-Turn ChatGPT Conversation Stream (User Bubble + Reasoning + Full-Bleed Editorial Response)

    private func chatGPTConversationStreamContent(scrollProxy: ScrollViewProxy) -> some View {
        LazyVStack(alignment: .leading, spacing: FigMetrics.twentyEight) {
            ForEach(Array(appState.chatTurns.enumerated()), id: \.element.id) { idx, turn in
                let richDoc = CertiGoChatGPTRichResponseParser.parse(
                    turn: turn,
                    routeCode: appState.activeRouteCode
                )
                let streamer = streamerForTurn(turn, document: richDoc)

                VStack(alignment: .leading, spacing: FigMetrics.eighteen) {
                    // 1. User Message Bubble (top-right aligned, #EBF5FF background, #0958A5 text, 22pt radius)
                    HStack(spacing: FigMetrics.zero) {
                        Spacer(minLength: CertiGoChatGPTLiquidGlassChromeSpec.userBubbleMinLeadingSpacer)

                        Text(verbatim: turn.userPrompt)
                            .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.userBubbleFontSize, style: "Regular"))
                            .foregroundStyle(
                                PrismColor.figmaHex(
                                    isDark
                                        ? CertiGoChatGPTLiquidGlassChromeSpec.userBubbleDarkTextHex
                                        : CertiGoChatGPTLiquidGlassChromeSpec.userBubbleLightTextHex
                                )
                            )
                            .lineSpacing(CertiGoChatGPTLiquidGlassChromeSpec.userBubbleLineSpacing)
                            .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.userBubbleHorizontalPadding)
                            .padding(.vertical, CertiGoChatGPTLiquidGlassChromeSpec.userBubbleVerticalPadding)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: CertiGoChatGPTLiquidGlassChromeSpec.userBubbleCornerRadius,
                                    style: .continuous
                                )
                                .fill(
                                    PrismColor.figmaHex(
                                        isDark
                                            ? CertiGoChatGPTLiquidGlassChromeSpec.userBubbleDarkFillHex
                                            : CertiGoChatGPTLiquidGlassChromeSpec.userBubbleLightFillHex
                                    )
                                )
                            )
                            .accessibilityIdentifier("chatgpt-user-bubble-\(turn.id)")
                    }

                    // 2. Compact Reasoning Phase ("Réflexion pendant 2s · Working for 2s" + expandable steps)
                    reasoningHeaderAndStepsView(for: turn, streamer: streamer)

                    // 3. Full-Bleed Editorial Response directly on the canvas (NO bubble, NO card border)
                    CertiGoChatGPTRichResponseView(
                        document: richDoc,
                        streamer: streamer,
                        isDark: isDark
                    )
                    .accessibilityIdentifier("chatgpt-rich-response-\(turn.id)")

                    // 4. Icon Action Bar beneath the AI response (Copier, Écouter, 👍, 👎, Partager, •••)
                    if !streamer.isStreaming {
                        responseActionBarView(for: turn, at: idx, richDoc: richDoc)

                        // 5. Conversation Evaluation Card ("Comment trouvez-vous cette explication ?") on latest turn
                        if idx == appState.chatTurns.count - 1 {
                            conversationEvaluationCardView(for: turn)
                        }

                        // 6. Follow-up suggestion chips
                        if !turn.followUpSuggestions.isEmpty {
                            followUpSuggestionsStrip(for: turn)
                        }
                    }
                }
                .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.responseHorizontalPadding)
                .onAppear {
                    startOrRefreshStreaming(for: turn)
                }
            }
        }
    }

    // MARK: - 5D. Compact Reasoning Phase (`"Réflexion pendant 2s"` / `"Working for 2s"`)

    private func reasoningHeaderAndStepsView(
        for turn: CertiGoChatTurn,
        streamer: CertiGoChatGPTTokenStreamer
    ) -> some View {
        let isExpanded = appState.expandedReasoningTurnIds.contains(turn.id) || turn.isStreamingOrLoading
        let steps = CertiGoChatGPTReasoningStep.defaultSteps(forRouteCode: appState.activeRouteCode)

        return VStack(alignment: .leading, spacing: FigMetrics.eight) {
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                    if appState.expandedReasoningTurnIds.contains(turn.id) {
                        appState.expandedReasoningTurnIds.remove(turn.id)
                    } else {
                        appState.expandedReasoningTurnIds.insert(turn.id)
                    }
                }
            } label: {
                HStack(spacing: FigMetrics.six) {
                    Text(
                        verbatim: turn.isStreamingOrLoading || streamer.isStreaming
                            ? "Réflexion en cours · Working for \(streamer.reasoningElapsedSeconds)s"
                            : "Réflexion pendant \(streamer.reasoningElapsedSeconds)s"
                    )
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.reasoningFontSize, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.reasoningTextHex))

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.reasoningTextHex))

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chatgpt-reasoning-toggle-\(turn.id)")

            if isExpanded {
                VStack(alignment: .leading, spacing: FigMetrics.six) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: FigMetrics.eight) {
                            Image(systemName: step.sfSymbolName)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                                .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.reasoningTextHex))
                                .frame(width: FigMetrics.sixteen, alignment: .center)
                                .padding(.top, FigMetrics.two)

                            VStack(alignment: .leading, spacing: FigMetrics.two) {
                                Text(verbatim: step.title)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                                    .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.reasoningTextHex))
                                Text(verbatim: step.detail)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                    .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.reasoningTextHex).opacity(0.85))
                            }
                        }
                    }
                }
                .padding(.vertical, FigMetrics.four)
                .transition(.opacity)
            }

            Rectangle()
                .fill(isDark ? Color.white.opacity(0.10) : PrismColor.figmaHex("#E5E5EA"))
                .frame(height: PrismBorder.hairline)
        }
    }

    // MARK: - 5E. Icon Action Bar & Evaluation Card (`#F4F4F4` / `#1C1C1E`)

    private func responseActionBarView(
        for turn: CertiGoChatTurn,
        at idx: Int,
        richDoc: CertiGoChatGPTRichDocument
    ) -> some View {
        let currentFeedback = appState.chatTurnFeedbackById[turn.id]
        let isSpeakingThisTurn = appState.speakingChatTurnId == turn.id
        let iconColor = PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconHex)

        return HStack(spacing: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconSpacing) {
            // 1. Copier (`doc.on.doc` -> `checkmark`)
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                if appState.chatTurns.indices.contains(idx) {
                    appState.chatTurns[idx].isCopied = true
                }
                UIPasteboard.general.string = richDoc.fullPlainText
                showPedagogicalToast("✓ Explication copiée dans le presse-papiers")
            } label: {
                Image(systemName: turn.isCopied ? "checkmark" : "doc.on.doc")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(turn.isCopied ? PrismColor.figmaHex("#10A37F") : iconColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copier la réponse")
            .accessibilityIdentifier("chatgpt-action-copy-\(turn.id)")

            // 2. Écouter à voix haute (`speaker.wave.2` neural voice toggle)
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                if appState.speakingChatTurnId == turn.id {
                    appState.speakingChatTurnId = nil
                } else {
                    appState.speakingChatTurnId = turn.id
                    showPedagogicalToast("🔊 Lecture vocale neurale Nova activée")
                }
            } label: {
                Image(systemName: isSpeakingThisTurn ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(
                        isSpeakingThisTurn
                            ? PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex)
                            : iconColor
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Écouter à voix haute")
            .accessibilityIdentifier("chatgpt-action-speak-\(turn.id)")

            // 3. Évaluer positivement (`hand.thumbsup`)
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                appState.chatTurnFeedbackById[turn.id] = .thumbsUp
                showPedagogicalToast("👍 Merci ! Explication enregistrée dans tes préférences")
            } label: {
                Image(systemName: currentFeedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(
                        currentFeedback == .thumbsUp
                            ? PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex)
                            : iconColor
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Utile")
            .accessibilityIdentifier("chatgpt-action-thumbsup-\(turn.id)")

            // 4. Évaluer négativement (`hand.thumbsdown`)
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                appState.chatTurnFeedbackById[turn.id] = .thumbsDown
                showPedagogicalToast("Nous allons simplifier et illustrer davantage cette notion")
            } label: {
                Image(systemName: currentFeedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(currentFeedback == .thumbsDown ? PrismColor.figmaHex("#EA580C") : iconColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("À améliorer")
            .accessibilityIdentifier("chatgpt-action-thumbsdown-\(turn.id)")

            // 5. Partager (`square.and.arrow.up` / `ShareLink`)
            ShareLink(item: richDoc.fullPlainText) {
                Image(systemName: "square.and.arrow.up")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(iconColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Partager la réponse")
            .accessibilityIdentifier("chatgpt-action-share-\(turn.id)")

            // 6. Plus (`•••` `ellipsis`: Régénérer, Approfondir avec un exemple concret, Me tester avec 1 question d'examen)
            Menu {
                Button {
                    appState.saveChatTurnToMemo(at: idx)
                    showPedagogicalToast("📌 Ajouté à tes fiches mémos")
                } label: {
                    Label(
                        turn.isSavedToMemo ? "Épinglé dans tes mémos" : "Épingler en fiche mémo",
                        systemImage: turn.isSavedToMemo ? "pin.fill" : "pin"
                    )
                }

                ForEach(CertiGoChatGPTResponseMoreAction.allCases) { moreAction in
                    Button {
                        handleResponseMoreAction(moreAction, for: turn)
                    } label: {
                        Label(moreAction.titleFR, systemImage: moreAction.sfSymbolName)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.actionBarIconPointSize, style: "Medium"))
                    .foregroundStyle(iconColor)
            }
            .accessibilityLabel("Plus d'actions sur cette réponse")
            .accessibilityIdentifier("chatgpt-action-more-\(turn.id)")

            Spacer()
        }
        .padding(.top, FigMetrics.four)
    }

    private func conversationEvaluationCardView(for turn: CertiGoChatTurn) -> some View {
        let currentFeedback = appState.chatTurnFeedbackById[turn.id]

        return HStack(spacing: FigMetrics.twelve) {
            Text(verbatim: "Comment trouvez-vous cette explication ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Medium"))
                .foregroundStyle(primaryInkColor)

            Spacer(minLength: FigMetrics.eight)

            HStack(spacing: FigMetrics.ten) {
                Button {
                    CertiGoHapticsEngine.shared.playOptionSelection()
                    appState.chatTurnFeedbackById[turn.id] = .thumbsDown
                    showPedagogicalToast("Merci pour ton retour, nous adaptons le niveau d'explication.")
                } label: {
                    Text(verbatim: "👎")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Regular"))
                        .frame(width: FigMetrics.thirtyFour, height: FigMetrics.thirtyFour)
                        .background(
                            Circle()
                                .fill(
                                    currentFeedback == .thumbsDown
                                        ? PrismColor.figmaHex("#FEE2E2")
                                        : (isDark ? Color.white.opacity(0.08) : Color.white)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chatgpt-eval-card-thumbsdown-\(turn.id)")

                Button {
                    CertiGoHapticsEngine.shared.playOptionSelection()
                    appState.chatTurnFeedbackById[turn.id] = .thumbsUp
                    showPedagogicalToast("🎉 +5 XP de révision active !")
                } label: {
                    Text(verbatim: "👍")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Regular"))
                        .frame(width: FigMetrics.thirtyFour, height: FigMetrics.thirtyFour)
                        .background(
                            Circle()
                                .fill(
                                    currentFeedback == .thumbsUp
                                        ? PrismColor.figmaHex("#DCFCE7")
                                        : (isDark ? Color.white.opacity(0.08) : Color.white)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chatgpt-eval-card-thumbsup-\(turn.id)")
            }
        }
        .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.evaluationCardHorizontalPadding)
        .padding(.vertical, CertiGoChatGPTLiquidGlassChromeSpec.evaluationCardVerticalPadding)
        .background(
            RoundedRectangle(
                cornerRadius: CertiGoChatGPTLiquidGlassChromeSpec.evaluationCardCornerRadius,
                style: .continuous
            )
            .fill(
                PrismColor.figmaHex(
                    isDark
                        ? CertiGoChatGPTLiquidGlassChromeSpec.evaluationCardDarkHex
                        : CertiGoChatGPTLiquidGlassChromeSpec.evaluationCardLightHex
                )
            )
        )
        .accessibilityIdentifier("chatgpt-evaluation-card-\(turn.id)")
    }

    private func followUpSuggestionsStrip(for turn: CertiGoChatTurn) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FigMetrics.eight) {
                ForEach(turn.followUpSuggestions, id: \.self) { suggestion in
                    Button {
                        submitPrompt(suggestion)
                    } label: {
                        HStack(spacing: FigMetrics.six) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                            Text(verbatim: suggestion)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                                .foregroundStyle(primaryInkColor)
                        }
                        .padding(.horizontal, FigMetrics.twelve)
                        .padding(.vertical, FigMetrics.eight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5F. Floating Scroll-to-Bottom Button (`↓`, 36x36 pt Liquid Glass Circle)

    private func floatingScrollToBottomButton(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            CertiGoHapticsEngine.shared.playOptionSelection()
            isScrolledAwayFromBottom = false
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                scrollProxy.scrollTo("chatgpt-scroll-bottom-anchor", anchor: .bottom)
            }
        } label: {
            Image(systemName: CertiGoChatGPTLiquidGlassChromeSpec.scrollToBottomIconName)
                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.scrollToBottomIconPointSize, style: "Semi Bold"))
                .foregroundStyle(
                    isDark
                        ? Color.white
                        : PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.scrollToBottomIconHex)
                )
                .frame(
                    width: CertiGoChatGPTLiquidGlassChromeSpec.scrollToBottomButtonDiameter,
                    height: CertiGoChatGPTLiquidGlassChromeSpec.scrollToBottomButtonDiameter
                )
                .background(liquidGlassCircleSurface)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Descendre en bas de la réponse")
        .accessibilityIdentifier("chatgpt-scroll-to-bottom-button")
    }

    // MARK: - 5G. Floating Bottom Pill Input Bar (`Ask ChatGPT` / `Demander à CertiGo IA`)

    private func floatingBottomAskPillBar(scrollProxy: ScrollViewProxy) -> some View {
        let circleState = CertiGoChatGPTActionCircleState.resolve(
            draftText: appState.aiDraftMessage,
            isStreaming: isAnyTurnCurrentlyStreaming
        )
        let placeholderText = CertiGoChatGPTLiquidGlassChromeSpec.inputPlaceholder(
            hasExistingTurns: !appState.chatTurns.isEmpty,
            isStreaming: isAnyTurnCurrentlyStreaming
        )

        return HStack(spacing: FigMetrics.ten) {
            // 1. Left `+` Button (`20 pt .regular`) opening quick actions sheet
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                onDismissKeyboard()
                appState.isShowingAIQuickActionsSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bottomPlusIconSize, style: "Regular"))
                    .foregroundStyle(primaryInkColor)
                    .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Actions rapides")
            .accessibilityIdentifier("chatgpt-bottom-plus-button")

            // 2. Center TextField (`16.5 pt`)
            TextField(
                text: $appState.aiDraftMessage,
                prompt: Text(verbatim: placeholderText)
                    .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
            ) {
                Text(verbatim: placeholderText)
            }
            .focused(isInputFocused)
            .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
            .foregroundStyle(primaryInkColor)
            .submitLabel(.send)
            .onSubmit {
                let text = appState.aiDraftMessage
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                submitPrompt(text)
            }
            .accessibilityIdentifier("hub-ia-textfield")

            // 3. Mic Button (`mic`, `19 pt`) for voice dictation
            Button {
                CertiGoHapticsEngine.shared.playOptionSelection()
                if appState.aiDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.aiDraftMessage = "Explique le concept clé de \(appState.activeRouteCode) étape par étape"
                } else {
                    onDismissKeyboard()
                }
            } label: {
                Image(systemName: "mic")
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bottomMicIconSize, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                    .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dictée vocale")
            .accessibilityIdentifier("chatgpt-bottom-mic-button")

            // 4. Right ChatGPT Blue Circle Button (`34x34 pt`, `#007AFF`) with 3 dynamic states
            Button {
                switch circleState {
                case .stopSquare:
                    CertiGoHapticsEngine.shared.playButtonPress()
                    stopCurrentStreamingImmediately()
                case .sendArrowUp:
                    let text = appState.aiDraftMessage
                    submitPrompt(text)
                case .voiceWaveform:
                    withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
                        onDismissKeyboard()
                        if !appState.isLiveAIModelConnected {
                            appState.triggerDiagnosticError(.voiceLiveNotConnected1002)
                        }
                        appState.isShowingVoiceLive06C = true
                    }
                }
            } label: {
                Image(systemName: circleState.sfSymbolName)
                    .font(
                        PrismTypography.figmaFont(
                            size: circleState.symbolPointSize,
                            style: circleState == .sendArrowUp ? "Bold" : "Semi Bold"
                        )
                    )
                    .foregroundStyle(Color.white)
                    .frame(
                        width: CertiGoChatGPTLiquidGlassChromeSpec.bottomActionCircleDiameter,
                        height: CertiGoChatGPTLiquidGlassChromeSpec.bottomActionCircleDiameter
                    )
                    .background(
                        Circle()
                            .fill(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(circleState.accessibilityLabelFR)
            .accessibilityIdentifier(
                circleState == .voiceWaveform ? "hub-ia-voice-live-button" : "hub-ia-send-button"
            )
        }
        .padding(.horizontal, CertiGoChatGPTLiquidGlassChromeSpec.bottomPillHorizontalPadding)
        .frame(minHeight: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillMinHeight)
        .background(liquidGlassBottomPillSurface)
    }

    // MARK: - 5H. Cloudy Blue ChatGPT Interactive Voice Orb (`06C`)

    private var chatGPTCloudyBlueVoiceOrbView: some View {
        let transcripts: [(speaker: String, line: String)] = [
            (
                "✦ CERTIGO GPT VOIX • \(appState.activeRouteCode)",
                "« Pose-moi une question à l'oral sur \(appState.activeRouteCode) : je te réponds comme en entretien d'architecture. »"
            ),
            (
                "🎙️ TOI (\(appState.firstNameText.uppercased()))",
                "« Quelle est la différence décisive entre Private Endpoint et Service Endpoint à l'examen ? »"
            ),
            (
                "✦ CERTIGO GPT VOIX • RÉPONSE",
                "« Private Endpoint attribue une IP privée 10.x dans ton VNet accessible depuis On-Premises, tandis que Service Endpoint conserve l'IP publique du service PaaS. »"
            )
        ]
        let currentTranscript = transcripts[appState.voiceLiveTranscriptIndex % transcripts.count]

        return ZStack {
            canvasColor
                .ignoresSafeArea()

            VStack(spacing: FigMetrics.twentyFour) {
                HStack {
                    HStack(spacing: FigMetrics.six) {
                        Circle()
                            .fill(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                            .frame(width: FigMetrics.eight, height: FigMetrics.eight)
                        Text(verbatim: "CertiGo GPT Voice • \(appState.activeRouteCode)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                    }
                    Spacer()
                }
                .padding(.horizontal, FigMetrics.twenty)
                .padding(.top, FigMetrics.twelve)

                Spacer()

                // Iconic ChatGPT iOS Cloudy Sky-Blue Orb
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
                        appState.voiceLiveTranscriptIndex += 1
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        PrismColor.figmaHex("#BAE6FD"),
                                        PrismColor.figmaHex("#38BDF8"),
                                        PrismColor.figmaHex("#007AFF"),
                                        PrismColor.figmaHex("#1D4ED8")
                                    ],
                                    center: .topLeading,
                                    startRadius: FigMetrics.sixteen,
                                    endRadius: FigMetrics.twoHundred
                                )
                            )
                            .frame(width: FigMetrics.twoHundredTwenty, height: FigMetrics.twoHundredTwenty)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.68),
                                                Color.white.opacity(0.15),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blur(radius: FigMetrics.twelve)
                                    .padding(FigMetrics.sixteen)
                            )
                            .scaleEffect(appState.isVoiceLiveListening ? 1.04 : 0.94)
                            .shadow(
                                color: PrismColor.figmaHex("#007AFF").opacity(0.28),
                                radius: FigMetrics.twentyFour,
                                x: FigMetrics.zero,
                                y: FigMetrics.ten
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chatgpt-voice-cloudy-orb")

                VStack(spacing: FigMetrics.eight) {
                    Text(verbatim: currentTranscript.speaker)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                    Text(verbatim: currentTranscript.line)
                        .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Medium"))
                        .foregroundStyle(primaryInkColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(FigMetrics.four)
                        .padding(.horizontal, FigMetrics.twentyFour)
                }

                Spacer()

                // Bottom ChatGPT Voice Controls: `mic.slash` mute circle & black `✕` close circle
                HStack(spacing: FigMetrics.fortyEight) {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
                            appState.isVoiceLiveListening.toggle()
                        }
                    } label: {
                        Image(systemName: appState.isVoiceLiveListening ? "mic.fill" : "mic.slash.fill")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Semi Bold"))
                            .foregroundStyle(appState.isVoiceLiveListening ? primaryInkColor : PrismColor.figmaHex("#EF4444"))
                            .frame(width: FigMetrics.sixtyFour, height: FigMetrics.sixtyFour)
                            .background(
                                Circle()
                                    .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.isVoiceLiveListening ? "Couper le micro" : "Réactiver le micro")
                    .accessibilityIdentifier("chatgpt-voice-mute-button")

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.isShowingVoiceLive06C = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                            .foregroundStyle(Color.white)
                            .frame(width: FigMetrics.sixtyFour, height: FigMetrics.sixtyFour)
                            .background(
                                Circle()
                                    .fill(PrismColor.figmaHex("#0D0D0D"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer le mode vocal")
                    .accessibilityIdentifier("chatgpt-voice-close-button")
                }
                .padding(.bottom, FigMetrics.oneHundredFour)
            }
        }
    }

    // MARK: - 5I. Liquid Glass Surface Helpers (`.ultraThinMaterial` + Specular Rim + Soft Shadow)

    private var liquidGlassCircleSurface: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(isDark ? Color.black.opacity(0.45) : Color.white.opacity(0.84))
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.28 : 0.95),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PrismBorder.thin
                )
        }
        .shadow(
            color: Color.black.opacity(CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowOpacity),
            radius: CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowRadius,
            x: FigMetrics.zero,
            y: CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowY
        )
    }

    private var liquidGlassCapsuleSurface: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
            Capsule(style: .continuous)
                .fill(isDark ? Color.black.opacity(0.45) : Color.white.opacity(0.84))
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.28 : 0.95),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PrismBorder.thin
                )
        }
        .shadow(
            color: Color.black.opacity(CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowOpacity),
            radius: CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowRadius,
            x: FigMetrics.zero,
            y: CertiGoChatGPTLiquidGlassChromeSpec.topFloatingShadowY
        )
    }

    private var liquidGlassBottomPillSurface: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillCornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)

            RoundedRectangle(
                cornerRadius: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillCornerRadius,
                style: .continuous
            )
            .fill(
                PrismColor.figmaHex(
                    isDark
                        ? CertiGoChatGPTLiquidGlassChromeSpec.bottomPillDarkFillHex
                        : CertiGoChatGPTLiquidGlassChromeSpec.bottomPillLightFillHex
                )
                .opacity(isDark ? 0.82 : 0.88)
            )

            RoundedRectangle(
                cornerRadius: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDark ? 0.22 : 0.95),
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: PrismBorder.thin
            )
        }
        .shadow(
            color: Color.black.opacity(CertiGoChatGPTLiquidGlassChromeSpec.bottomPillShadowOpacity),
            radius: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillShadowRadius,
            x: FigMetrics.zero,
            y: CertiGoChatGPTLiquidGlassChromeSpec.bottomPillShadowY
        )
    }

    // MARK: - 5J. Side History Drawer, Quick Actions (`+`), Certification Selector & Streaming Helpers

    private var temporaryChatBannerView: some View {
        HStack(spacing: FigMetrics.eight) {
            Image(systemName: "eye.slash.fill")
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
            Text(verbatim: "Discussion éphémère active • Non enregistrée dans l'historique")
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
            Spacer()
        }
        .padding(.horizontal, FigMetrics.twelve)
        .padding(.vertical, FigMetrics.eight)
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.twelve, style: .continuous)
                .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
        )
    }

    private func duolingoPedagogicalToastView(_ text: String) -> some View {
        HStack(spacing: FigMetrics.eight) {
            Text(verbatim: text)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0958A5"))
            Spacer()
        }
        .padding(.horizontal, FigMetrics.fourteen)
        .padding(.vertical, FigMetrics.eight)
        .background(
            Capsule(style: .continuous)
                .fill(PrismColor.figmaHex("#EBF5FF"))
        )
    }

    private var quickActionsBottomSheetView: some View {
        VStack(alignment: .leading, spacing: FigMetrics.sixteen) {
            HStack {
                Text(verbatim: "Actions rapides • \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                    .foregroundStyle(primaryInkColor)
                Spacer()
                Button {
                    appState.isShowingAIQuickActionsSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Regular"))
                        .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                }
                .buttonStyle(.plain)
            }

            ForEach(CertiGoChatGPTQuickAction.allCases) { action in
                Button {
                    appState.isShowingAIQuickActionsSheet = false
                    submitPrompt(action.promptForRoute(appState.activeRouteCode))
                } label: {
                    HStack(spacing: FigMetrics.fourteen) {
                        Image(systemName: action.sfSymbolName)
                            .font(PrismTypography.figmaFont(size: FigMetrics.seventeen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex(action.accentHex))
                            .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                            .background(
                                Circle()
                                    .fill(PrismColor.figmaHex(action.accentHex).opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: FigMetrics.two) {
                            Text(verbatim: action.titleFR)
                                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Semi Bold"))
                                .foregroundStyle(primaryInkColor)
                            Text(verbatim: action.subtitleFR)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                        }

                        Spacer()
                    }
                    .padding(.vertical, FigMetrics.six)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chatgpt-quick-action-\(action.rawValue)")
            }

            Spacer(minLength: FigMetrics.zero)
        }
        .padding(FigMetrics.twenty)
    }

    private var certificationPickerSheetView: some View {
        let allItems = CertiGoNativeRichCatalog.allOnboardingCatalogItems

        return NavigationStack {
            List(allItems) { item in
                Button {
                    CertiGoHapticsEngine.shared.playOptionSelection()
                    appState.selectRoute(item.code)
                    showCertificationPickerSheet = false
                } label: {
                    HStack(spacing: FigMetrics.twelve) {
                        VStack(alignment: .leading, spacing: FigMetrics.two) {
                            Text(verbatim: "\(item.code) • \(item.title)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fifteen, style: "Semi Bold"))
                                .foregroundStyle(primaryInkColor)
                            Text(verbatim: item.subtitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                        }
                        Spacer()
                        if item.code == appState.activeRouteCode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                        }
                    }
                }
            }
            .navigationTitle("Certification cible (33)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func chatGPTHistoryDrawerView(width: CGFloat) -> some View {
        let pinned = appState.filteredAIThreads.filter(\.isPinned)
        let recent = appState.filteredAIThreads.filter { !$0.isPinned }

        return VStack(alignment: .leading, spacing: FigMetrics.fourteen) {
            HStack {
                Text(verbatim: "CertiGo GPT")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                    .foregroundStyle(primaryInkColor)
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                        appState.isAIDrawerOpen06D = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#6E6E80"))
                        .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                }
                .buttonStyle(.plain)
            }

            // Search bar
            HStack(spacing: FigMetrics.eight) {
                Image(systemName: "magnifyingglass")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                TextField(
                    text: $appState.aiDrawerSearchQuery,
                    prompt: Text(verbatim: "Rechercher une discussion...")
                ) {
                    Text(verbatim: "Rechercher une discussion...")
                }
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                .foregroundStyle(primaryInkColor)
                .accessibilityIdentifier("ai-drawer-search-textfield")
            }
            .padding(.horizontal, FigMetrics.twelve)
            .frame(height: FigMetrics.thirtyEight)
            .background(
                RoundedRectangle(cornerRadius: FigMetrics.ten, style: .continuous)
                    .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
            )

            // Temporary Chat & Certification quick toggles
            HStack(spacing: FigMetrics.eight) {
                Button {
                    appState.toggleTemporaryAIChat()
                } label: {
                    HStack(spacing: FigMetrics.six) {
                        Image(systemName: appState.isTemporaryAIChatEnabled ? "eye.slash.fill" : "eye.slash")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                        Text(verbatim: "Éphémère")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                    }
                    .foregroundStyle(
                        appState.isTemporaryAIChatEnabled
                            ? Color.white
                            : primaryInkColor
                    )
                    .padding(.horizontal, FigMetrics.ten)
                    .padding(.vertical, FigMetrics.six)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                appState.isTemporaryAIChatEnabled
                                    ? PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex)
                                    : (isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
                            )
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.isAIDrawerOpen06D = false
                    showCertificationPickerSheet = true
                } label: {
                    HStack(spacing: FigMetrics.six) {
                        Image(systemName: "sparkles")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex(CertiGoChatGPTLiquidGlassChromeSpec.chatGPTBlueHex))
                        Text(verbatim: appState.activeRouteCode)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(primaryInkColor)
                    }
                    .padding(.horizontal, FigMetrics.ten)
                    .padding(.vertical, FigMetrics.six)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F4F4F4"))
                    )
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: FigMetrics.eight) {
                    if appState.filteredAIThreads.isEmpty {
                        CertiGoEmptyStateCardView(
                            mascotPose: .specialistAICoach,
                            title: "💬 Aucune discussion IA pour l'instant",
                            subtitle: "Pose une question pour démarrer ton historique personnalisé."
                        )
                    } else {
                        HStack {
                            Text(verbatim: "RÉCENTES (\(appState.filteredAIThreads.count))")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                            Spacer()
                            Button {
                                withAnimation {
                                    appState.clearAllAIThreads()
                                }
                            } label: {
                                Text(verbatim: "Tout effacer")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#EF4444"))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ai-drawer-clear-all-threads")
                        }

                        ForEach(pinned + recent) { thread in
                            HStack(spacing: FigMetrics.eight) {
                                Button {
                                    withAnimation {
                                        appState.openAITopic(thread.topicKey, customUserQuestion: thread.title)
                                        if let latest = appState.chatTurns.last {
                                            startOrRefreshStreaming(for: latest)
                                        }
                                        onTriggerLiveAIRequest()
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: FigMetrics.two) {
                                        Text(verbatim: thread.title)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Medium"))
                                            .foregroundStyle(primaryInkColor)
                                            .lineLimit(1)
                                        Text(verbatim: "\(thread.routeBadge) • \(thread.subtitle)")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                            .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    withAnimation {
                                        appState.deleteAIThread(id: thread.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                        .foregroundStyle(PrismColor.figmaHex("#8E8E93"))
                                        .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyEight)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("ai-drawer-delete-thread-\(thread.id)")
                            }
                            .padding(.horizontal, FigMetrics.ten)
                            .padding(.vertical, FigMetrics.eight)
                            .background(
                                RoundedRectangle(cornerRadius: FigMetrics.ten, style: .continuous)
                                    .fill(isDark ? PrismColor.figmaHex("#1C1C1E") : PrismColor.figmaHex("#F9FAFB"))
                            )
                        }
                    }
                }
                .padding(.bottom, FigMetrics.bottomBarTotalClearance)
            }
        }
        .padding(FigMetrics.sixteen)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(canvasColor.ignoresSafeArea(.all, edges: .vertical))
        .shadow(color: Color.black.opacity(0.14), radius: FigMetrics.twenty, x: FigMetrics.eight, y: FigMetrics.zero)
    }

    private var formattedConversationTranscriptForSharing: String {
        appState.chatTurns.map { turn in
            let doc = CertiGoChatGPTRichResponseParser.parse(turn: turn, routeCode: appState.activeRouteCode)
            return "Question : \(turn.userPrompt)\n\n\(doc.fullPlainText)"
        }.joined(separator: "\n\n---\n\n")
    }

    private func submitPrompt(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
            appState.sendAIMessage(trimmed)
            onDismissKeyboard()
            if let latest = appState.chatTurns.last {
                startOrRefreshStreaming(for: latest)
            }
            onTriggerLiveAIRequest()
        }
    }

    private func handleResponseMoreAction(_ action: CertiGoChatGPTResponseMoreAction, for turn: CertiGoChatTurn) {
        switch action {
        case .regenerateResponse:
            let doc = CertiGoChatGPTRichResponseParser.parse(turn: turn, routeCode: appState.activeRouteCode)
            streamProgressByTurnId[turn.id] = CertiGoChatGPTTokenStreamer(
                turnId: turn.id,
                fullText: doc.fullPlainText,
                startImmediatelyCompleted: false
            )
            activeStreamingTurnId = turn.id
        case .deepenWithConcreteExample:
            submitPrompt("Donne-moi un exemple concret d'architecture en production sur : \(turn.userPrompt)")
        case .testWithOneExamQuestion:
            submitPrompt("Teste-moi avec 1 question d'examen officielle (\(appState.activeRouteCode)) sur : \(turn.userPrompt)")
        }
    }

    private func showPedagogicalToast(_ message: String) {
        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
            lastPedagogicalToast = message
        }
    }

    private func streamerForTurn(
        _ turn: CertiGoChatTurn,
        document: CertiGoChatGPTRichDocument
    ) -> CertiGoChatGPTTokenStreamer {
        if let existing = streamProgressByTurnId[turn.id] {
            return existing
        }
        return CertiGoChatGPTTokenStreamer(
            turnId: turn.id,
            fullText: document.fullPlainText,
            startImmediatelyCompleted: !turn.isStreamingOrLoading && !reduceMotion
        )
    }

    private func startOrRefreshStreaming(for turn: CertiGoChatTurn) {
        let doc = CertiGoChatGPTRichResponseParser.parse(turn: turn, routeCode: appState.activeRouteCode)
        if reduceMotion {
            streamProgressByTurnId[turn.id] = CertiGoChatGPTTokenStreamer(
                turnId: turn.id,
                fullText: doc.fullPlainText,
                startImmediatelyCompleted: true
            )
            activeStreamingTurnId = nil
            return
        }
        streamProgressByTurnId[turn.id] = CertiGoChatGPTTokenStreamer(
            turnId: turn.id,
            fullText: doc.fullPlainText,
            startImmediatelyCompleted: false
        )
        activeStreamingTurnId = turn.id
    }

    private func tickActiveStreamerIfNeeded() {
        guard let activeId = activeStreamingTurnId,
              var streamer = streamProgressByTurnId[activeId]
        else { return }

        guard streamer.isStreaming else {
            activeStreamingTurnId = nil
            return
        }
        streamer.advanceTick()
        streamProgressByTurnId[activeId] = streamer
        if !streamer.isStreaming {
            activeStreamingTurnId = nil
            if let idx = appState.chatTurns.firstIndex(where: { $0.id == activeId }) {
                appState.chatTurns[idx].isStreamingOrLoading = false
            }
        }
    }

    private func stopCurrentStreamingImmediately() {
        if let activeId = activeStreamingTurnId,
           var streamer = streamProgressByTurnId[activeId] {
            streamer.stopByUser()
            streamProgressByTurnId[activeId] = streamer
            appState.stoppedStreamingTurnIds.insert(activeId)
            activeStreamingTurnId = nil
        }
        if !appState.chatTurns.isEmpty {
            let lastIdx = appState.chatTurns.count - 1
            appState.chatTurns[lastIdx].isStreamingOrLoading = false
        }
    }
}

// MARK: - 6. Dedicated Editorial & Typographic Renderer (`CertiGoChatGPTRichResponseView`)

/// Pixel-exact reproduction of ChatGPT iOS response typography (`☕ Cafe Mocha` reference screen):
/// - H2 Title with Emoji (`20 pt .bold`, `#0D0D0D`, `padding(.bottom, 6)`)
/// - Key: Value Metadata lines (`16.5 pt .bold` key + `16.5 pt .regular` value, `spacing: 4 pt`)
/// - H3 Section Subheadings (`18 pt .bold`, `#0D0D0D`, `padding(.top, 18)`, `padding(.bottom, 8)`)
/// - Bullet list (`•` solid 6x6 pt black circle at `y: 8 pt`, `12 pt` horizontal spacing, `16.5 pt .regular` with bold terms, `lineSpacing: 4 pt`, `spacing: 8 pt`)
/// - Numbered list (`1.` `16.5 pt .regular` width `24 pt` + bold lead-in with colon `16.5 pt .bold` + explanation `16.5 pt .regular`, `lineSpacing: 4 pt`, `spacing: 10 pt`)
public struct CertiGoChatGPTRichResponseView: View {
    public let document: CertiGoChatGPTRichDocument
    public let streamer: CertiGoChatGPTTokenStreamer
    public let isDark: Bool

    public init(
        document: CertiGoChatGPTRichDocument,
        streamer: CertiGoChatGPTTokenStreamer,
        isDark: Bool = false
    ) {
        self.document = document
        self.streamer = streamer
        self.isDark = isDark
    }

    private var inkColor: Color {
        PrismColor.figmaHex(
            isDark
                ? CertiGoChatGPTLiquidGlassChromeSpec.primaryInkDarkHex
                : CertiGoChatGPTLiquidGlassChromeSpec.primaryInkLightHex
        )
    }

    public var body: some View {
        let totalBlocks = 2 + document.bulletItems.count + document.numberedSteps.count

        VStack(alignment: .leading, spacing: FigMetrics.zero) {
            // 1. Main Title with Emoji (H2): 20 pt .bold, #0D0D0D, padding(.bottom, 6)
            Text(verbatim: document.emojiAndH2Title)
                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.h2TitleFontSize, style: "Bold"))
                .foregroundStyle(inkColor)
                .padding(.bottom, CertiGoChatGPTLiquidGlassChromeSpec.h2TitleBottomPadding)
                .opacity(streamer.itemOpacity(itemOrderIndex: 0, totalItems: totalBlocks))

            // 2. Header Key-Value Metadata Lines (Key: Value, 16.5 pt .bold + 16.5 pt .regular, spacing: 4 pt)
            VStack(alignment: .leading, spacing: CertiGoChatGPTLiquidGlassChromeSpec.metadataLineSpacing) {
                ForEach(document.metadataLines) { meta in
                    (
                        Text(verbatim: "\(meta.key): ")
                            .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Bold"))
                        + Text(verbatim: meta.value)
                            .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
                    )
                    .foregroundStyle(inkColor)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(streamer.itemOpacity(itemOrderIndex: 1, totalItems: totalBlocks))

            // 3. Section Subheading H3 #1 ("Points clés à maîtriser" - like "Ingredients" on the reference screen)
            if !document.bulletItems.isEmpty {
                Text(verbatim: document.ingredientsHeading)
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.h3SectionFontSize, style: "Bold"))
                    .foregroundStyle(inkColor)
                    .padding(.top, CertiGoChatGPTLiquidGlassChromeSpec.h3SectionTopPadding)
                    .padding(.bottom, CertiGoChatGPTLiquidGlassChromeSpec.h3SectionBottomPadding)
                    .opacity(streamer.itemOpacity(itemOrderIndex: 1, totalItems: totalBlocks))

                // 4. Bullet List (`•` 6x6 pt solid black circle at y: 8 pt, 12 pt spacing, 16.5 pt .regular)
                VStack(alignment: .leading, spacing: CertiGoChatGPTLiquidGlassChromeSpec.bulletItemVerticalSpacing) {
                    ForEach(Array(document.bulletItems.enumerated()), id: \.element.id) { bIdx, bullet in
                        HStack(alignment: .top, spacing: CertiGoChatGPTLiquidGlassChromeSpec.bulletHorizontalSpacing) {
                            Circle()
                                .fill(inkColor)
                                .frame(
                                    width: CertiGoChatGPTLiquidGlassChromeSpec.bulletDotDiameter,
                                    height: CertiGoChatGPTLiquidGlassChromeSpec.bulletDotDiameter
                                )
                                .padding(.top, CertiGoChatGPTLiquidGlassChromeSpec.bulletDotTopOffset)

                            bulletFormattedText(bullet)
                                .foregroundStyle(inkColor)
                                .lineSpacing(CertiGoChatGPTLiquidGlassChromeSpec.bulletLineSpacing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(streamer.itemOpacity(itemOrderIndex: 2 + bIdx, totalItems: totalBlocks))
                    }
                }
            }

            // 5. Section Subheading H3 #2 ("Instructions & réflexes d'examen" - like "Instructions" on the reference screen)
            if !document.numberedSteps.isEmpty {
                Text(verbatim: document.instructionsHeading)
                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.h3SectionFontSize, style: "Bold"))
                    .foregroundStyle(inkColor)
                    .padding(.top, CertiGoChatGPTLiquidGlassChromeSpec.h3SectionTopPadding)
                    .padding(.bottom, CertiGoChatGPTLiquidGlassChromeSpec.h3SectionBottomPadding)
                    .opacity(
                        streamer.itemOpacity(
                            itemOrderIndex: 2 + document.bulletItems.count,
                            totalItems: totalBlocks
                        )
                    )

                // 6. Numbered List (`1.`, `2.`, `3.` width 24 pt + bold lead-in followed by colon + 16.5 pt .regular explanation)
                VStack(alignment: .leading, spacing: CertiGoChatGPTLiquidGlassChromeSpec.numberedStepVerticalSpacing) {
                    ForEach(Array(document.numberedSteps.enumerated()), id: \.element.id) { sIdx, step in
                        HStack(alignment: .top, spacing: FigMetrics.zero) {
                            Text(verbatim: "\(step.number).")
                                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
                                .foregroundStyle(inkColor)
                                .frame(
                                    width: CertiGoChatGPTLiquidGlassChromeSpec.numberedPrefixWidth,
                                    alignment: .leading
                                )

                            (
                                Text(verbatim: "\(step.boldLeadInWithColon) ")
                                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Bold"))
                                + Text(verbatim: step.explanationText)
                                    .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
                            )
                            .foregroundStyle(inkColor)
                            .lineSpacing(CertiGoChatGPTLiquidGlassChromeSpec.bulletLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(
                            streamer.itemOpacity(
                                itemOrderIndex: 2 + document.bulletItems.count + sIdx,
                                totalItems: totalBlocks
                            )
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletFormattedText(_ bullet: CertiGoChatGPTBulletItem) -> Text {
        if let boldPrefix = bullet.boldPrefix, !boldPrefix.isEmpty {
            return Text(verbatim: "\(boldPrefix) ")
                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Bold"))
                + Text(verbatim: bullet.bodyText)
                .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
        }
        return Text(verbatim: bullet.bodyText)
            .font(PrismTypography.figmaFont(size: CertiGoChatGPTLiquidGlassChromeSpec.bodyAndMetadataFontSize, style: "Regular"))
    }
}
#endif
