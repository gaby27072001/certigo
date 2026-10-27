import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Official CertiGo Mascot Library (Page 08 Figma Pro — 24 Validated Poses)

public enum CertiGoMascotPose: String, CaseIterable, Codable, Hashable, Sendable {
    // Planche 1 : 6 Angles de Vue (Turnaround)
    case angle34RightQuiz = "Mascots/mascot-angle-01-34-right"
    case angle34LeftPath = "Mascots/mascot-angle-02-34-left"
    case angleFrontCelebration = "Mascots/mascot-angle-03-front"
    case angleSprintRight = "Mascots/mascot-angle-04-sprint"
    case angleLookupPodium = "Mascots/mascot-angle-05-lookup"
    case angleThinking34 = "Mascots/mascot-angle-06-thinking"

    // Planche 2 : 6 Postures & Gestes
    case posePresenter = "Mascots/mascot-pose-01-presenter"
    case poseVictoryJump = "Mascots/mascot-pose-02-victory-jump"
    case poseCrossedArms = "Mascots/mascot-pose-03-crossed-arms"
    case poseReaderMemo = "Mascots/mascot-pose-04-reader-memo"
    case poseCLICoder = "Mascots/mascot-pose-05-cli-coder"
    case poseAnalyst = "Mascots/mascot-pose-06-analyst"

    // Planche 3 : 6 Expressions Émotionnelles
    case emotionStarryEyes = "Mascots/mascot-emotion-01-starry-eyes"
    case emotionOnFire = "Mascots/mascot-emotion-02-on-fire"
    case emotionAhaIdea = "Mascots/mascot-emotion-03-aha-idea"
    case emotionOopsCaring = "Mascots/mascot-emotion-04-oops-caring"
    case emotionBossCrown = "Mascots/mascot-emotion-05-boss-crown"
    case emotionDetermined = "Mascots/mascot-emotion-06-determined"

    // Planche 4 : 6 Spécialistes de Domaine en Posture 3/4 Droite (Quiz)
    case specialistCloudAzure = "Mascots/mascot-spec-01-cloud-azure"
    case specialistSecurityEntra = "Mascots/mascot-spec-02-security-entra"
    case specialistNetworkVNet = "Mascots/mascot-spec-03-network-vnet"
    case specialistCLIContainers = "Mascots/mascot-spec-04-cli-containers"
    case specialistDataSQL = "Mascots/mascot-spec-05-data-sql"
    case specialistAICoach = "Mascots/mascot-spec-06-ai-coach"

    public static func specialist(for region: PrismRegion) -> Self {
        switch region {
        case .cloud: return .specialistCloudAzure
        case .security: return .specialistSecurityEntra
        case .network: return .specialistNetworkVNet
        case .devops, .code, .systems: return .specialistCLIContainers
        case .data: return .specialistDataSQL
        case .ai: return .specialistAICoach
        }
    }

    public var displayName: String {
        switch self {
        case .angle34RightQuiz: return "Blason 1A · Vue 3/4 Droite (Quiz)"
        case .angle34LeftPath: return "Blason 1A · Vue 3/4 Gauche (Parcours)"
        case .angleFrontCelebration: return "Blason 1A · Vue de Face (Célébration)"
        case .angleSprintRight: return "Blason 1A · Profil Course"
        case .angleLookupPodium: return "Blason 1A · Regard vers le Haut"
        case .angleThinking34: return "Blason 1A · Réflexion 3/4"
        case .posePresenter: return "Blason 1A · Présentateur Quiz"
        case .poseVictoryJump: return "Blason 1A · Saut de Victoire"
        case .poseCrossedArms: return "Blason 1A · Bras Croisés Solide"
        case .poseReaderMemo: return "Blason 1A · Lecteur Fiche Mémo"
        case .poseCLICoder: return "Blason 1A · Ingénieur Lab CLI"
        case .poseAnalyst: return "Blason 1A · Analyste Pensif"
        case .emotionStarryEyes: return "Blason 1A · Étoiles dans les Yeux"
        case .emotionOnFire: return "Blason 1A · Mode Série En Feu"
        case .emotionAhaIdea: return "Blason 1A · Déclic Aha !"
        case .emotionOopsCaring: return "Blason 1A · Bienveillant / Oups"
        case .emotionBossCrown: return "Blason 1A · Boss Certifié 810+"
        case .emotionDetermined: return "Blason 1A · Ultra-Déterminé"
        case .specialistCloudAzure: return "Blason Cloud Azure (3/4 Droite)"
        case .specialistSecurityEntra: return "Blason Sécurité Entra (3/4 Droite)"
        case .specialistNetworkVNet: return "Blason Réseau VNet (3/4 Droite)"
        case .specialistCLIContainers: return "Blason CLI & Conteneurs (3/4 Droite)"
        case .specialistDataSQL: return "Blason Data & SQL (3/4 Droite)"
        case .specialistAICoach: return "Blason Coach IA (3/4 Droite)"
        }
    }
}

// MARK: - 2. Official 900-Asset Catalog Resolver (52 Certifications, 291 Azure, 293 AWS, 214 GCP, 32 Brands/AI)

public enum CertiGoOfficialAssetCatalog {
    public static func certificationAssetName(forRouteCode code: String) -> String {
        let upper = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch upper {
        case "AZ-900", "AI-900", "DP-900", "SC-900", "PL-900", "MS-900":
            return "Certifications/ms-official-fundamentals-badge"
        case "AZ-305", "AZ-400", "SC-100":
            return "Certifications/ms-official-expert-badge"
        case "AZ-140", "AZ-700", "AZ-500":
            return "Certifications/ms-official-specialty-badge"
        case "AZ-104", "AZ-204", "AI-102", "DP-100", "SC-200", "SC-300":
            return "Certifications/ms-official-associate-badge"
        case "CLF-C02":
            return "Certifications/tech-aws-cloud-practitioner"
        case "AIF-C01":
            return "Certifications/tech-aws-ai-practitioner"
        case "SAA-C03":
            return "Certifications/tech-aws-solutions-architect"
        case "DVA-C02":
            return "Certifications/tech-aws-developer"
        case "SOA-C02":
            return "Certifications/tech-aws-sysops-admin"
        case "SAP-C02":
            return "Certifications/tech-aws-sa-professional"
        case "ACE":
            return "Certifications/tech-gcp-cloud-engineer"
        case "PCA":
            return "Certifications/tech-gcp-cloud-architect"
        case "PDE":
            return "Certifications/tech-gcp-data-engineer"
        case "GH-300":
            return "Certifications/tech-github-copilot"
        case "GH-900", "GH-FOUNDATIONS":
            return "Certifications/tech-github-foundations"
        case "GH-ACTIONS":
            return "Certifications/tech-github-actions"
        case "GH-AS":
            return "Certifications/tech-github-advanced-security"
        case "CCNA":
            return "Certifications/tech-cisco-ccna"
        case "CKA":
            return "Certifications/tech-cka"
        case "CKAD":
            return "Certifications/tech-cncf-ckad"
        case "CKS":
            return "Certifications/tech-cks"
        case "TF-003", "TERRAFORM":
            return "Certifications/tech-terraform-associate"
        case "VAULT":
            return "Certifications/tech-vault-associate"
        case "CCA-F", "CLAUDE":
            return "Certifications/tech-anthropic-cca-foundations"
        default:
            if upper.hasPrefix("AWS") {
                return "Certifications/tech-aws-solutions-architect"
            }
            if upper.hasPrefix("GCP") {
                return "Certifications/tech-gcp-cloud-engineer"
            }
            return "Certifications/ms-official-associate-badge"
        }
    }

    public static func brandLogoAssetName(forVendorId vendorId: String) -> String {
        switch vendorId.lowercased() {
        case "aws", "amazon":
            return "BrandLogos/brand-aws-official"
        case "microsoft":
            return "BrandLogos/brand-microsoft"
        case "azure":
            return "BrandLogos/brand-microsoft-azure"
        case "gcp", "google", "google-cloud":
            return "BrandLogos/brand-google-cloud"
        case "github":
            return "BrandLogos/brand-github"
        case "copilot", "github-copilot":
            return "BrandLogos/brand-github-copilot"
        case "openai", "chatgpt":
            return "BrandLogos/brand-openai"
        case "claude", "anthropic":
            return "BrandLogos/brand-claude-ai"
        case "gemini", "google-gemini":
            return "BrandLogos/brand-google-gemini"
        case "mistral":
            return "BrandLogos/brand-mistral-ai"
        case "meta", "llama":
            return "BrandLogos/brand-meta"
        case "huggingface":
            return "BrandLogos/brand-hugging-face"
        case "nvidia":
            return "BrandLogos/brand-nvidia"
        case "cncf", "kubernetes", "k8s":
            return "BrandLogos/brand-kubernetes"
        case "terraform", "hashicorp":
            return "BrandLogos/brand-terraform"
        case "cisco":
            return "BrandLogos/brand-cisco"
        case "docker":
            return "BrandLogos/brand-docker"
        default:
            return "BrandLogos/brand-microsoft-azure"
        }
    }

    public static func azureServiceAssetName(_ serviceSlug: String) -> String {
        "AzureServices/\(serviceSlug)"
    }

    public static func awsServiceAssetName(_ serviceSlug: String) -> String {
        "AWSServices/\(serviceSlug)"
    }

    public static func gcpServiceAssetName(_ serviceSlug: String) -> String {
        let normalized = serviceSlug.hasPrefix("gcp-") ? serviceSlug : "gcp-\(serviceSlug)"
        return "GCPServices/\(normalized)"
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 3. SwiftUI Views for Mascot Blason 1A, 3/4 Question Speech Bubble & Official Crests

public struct CertiGoMascotView: View {
    public let pose: CertiGoMascotPose
    public let size: CGFloat

    public init(pose: CertiGoMascotPose = .angle34RightQuiz, size: CGFloat = PrismSize.mascotQuiz) {
        self.pose = pose
        self.size = size
    }

    public var body: some View {
        Image(pose.rawValue, bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(verbatim: pose.displayName))
            .accessibilityAddTraits(.isImage)
    }
}

public struct CertiGoOfficialCrestView: View {
    public let routeCode: String
    public let size: CGFloat

    public init(routeCode: String, size: CGFloat = PrismSize.crestHero) {
        self.routeCode = routeCode
        self.size = size
    }

    public var body: some View {
        let assetName = CertiGoOfficialAssetCatalog.certificationAssetName(forRouteCode: routeCode)
        Image(assetName, bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(verbatim: "Blason officiel \(routeCode)"))
            .accessibilityAddTraits(.isImage)
    }
}

public struct CertiGoBrandLogoView: View {
    public let vendorId: String
    public let size: CGFloat

    public init(vendorId: String, size: CGFloat = PrismSize.brandM) {
        self.vendorId = vendorId
        self.size = size
    }

    public var body: some View {
        let assetName = CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: vendorId)
        Image(assetName, bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(verbatim: vendorId))
            .accessibilityAddTraits(.isImage)
    }
}

/// Renders the 100% validated Duolingo-style 3/4 Right Specialist Mascot + stacked speech bubble (`◀`) with clear 15pt Bold question text.
public struct CertiGoSpeechBubbleHeaderView: View {
    public let region: PrismRegion
    public let badgeText: String
    public let questionText: String
    public let poseOverride: CertiGoMascotPose?

    public init(
        region: PrismRegion = .cloud,
        badgeText: String = "SCÉNARIO ARCHITECTURE",
        questionText: String,
        poseOverride: CertiGoMascotPose? = nil
    ) {
        self.region = region
        self.badgeText = badgeText
        self.questionText = questionText
        self.poseOverride = poseOverride
    }

    public var body: some View {
        let pose = poseOverride ?? CertiGoMascotPose.specialist(for: region)
        HStack(alignment: .center, spacing: PrismSpacing.s) {
            CertiGoMascotView(pose: pose, size: PrismSize.mascotQuiz)

            HStack(alignment: .center, spacing: .zero) {
                Image(systemName: "arrowtriangle.left.fill")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.surface)
                    .frame(width: PrismSize.speechPointerWidth, height: PrismSize.speechPointerHeight)

                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: badgeText.uppercased())
                        .prismTextStyle(.caption)
                        .foregroundStyle(region.color)
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.canvas)
                        )

                    Text(verbatim: questionText)
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(PrismSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                            .fill(PrismColor.separator)
                            .offset(y: PrismSpacing.xs)
                        RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                            .fill(PrismColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                                    .strokeBorder(PrismColor.separator, lineWidth: PrismBorder.standard)
                            )
                    }
                )
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
