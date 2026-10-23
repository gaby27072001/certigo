import CertigoDomain
import Foundation

public struct BrandProductID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let microsoftAzure = Self(rawValue: "microsoft.microsoft-azure")
    public static let azureVirtualMachines = Self(rawValue: "microsoft.azure-virtual-machines")
    public static let azureVirtualNetwork = Self(rawValue: "microsoft.azure-virtual-network")
    public static let azureLoadBalancer = Self(rawValue: "microsoft.azure-load-balancer")
    public static let azureStorage = Self(rawValue: "microsoft.azure-storage")
    public static let azureCosmosDB = Self(rawValue: "microsoft.azure-cosmos-db")
    public static let azureSQLDatabase = Self(rawValue: "microsoft.azure-sql-database")
    public static let azureOpenAIService = Self(rawValue: "microsoft.azure-openai-service")
    public static let microsoftFoundry = Self(rawValue: "microsoft.microsoft-foundry")
    public static let microsoftEntraID = Self(rawValue: "microsoft.microsoft-entra-id")
    public static let microsoftDefenderForCloud = Self(rawValue: "microsoft.microsoft-defender-for-cloud")
    public static let microsoftSentinel = Self(rawValue: "microsoft.microsoft-sentinel")
    public static let microsoftFabric = Self(rawValue: "microsoft.microsoft-fabric")
    public static let microsoftPowerPlatform = Self(rawValue: "microsoft.microsoft-power-platform")
    public static let microsoftCopilotStudio = Self(rawValue: "microsoft.microsoft-copilot-studio")
    public static let microsoftDataverse = Self(rawValue: "microsoft.microsoft-dataverse")
    public static let aiBuilder = Self(rawValue: "microsoft.ai-builder")
    public static let microsoftDynamics365 = Self(rawValue: "microsoft.microsoft-dynamics-365")
    public static let m365Word = Self(rawValue: "microsoft.microsoft-word")
    public static let m365Excel = Self(rawValue: "microsoft.microsoft-excel")
    public static let m365PowerPoint = Self(rawValue: "microsoft.microsoft-powerpoint")
    public static let m365Outlook = Self(rawValue: "microsoft.microsoft-outlook")
    public static let m365Teams = Self(rawValue: "microsoft.microsoft-teams")
    public static let githubPlatform = Self(rawValue: "github.github-plateforme-foundations-administration")
    public static let githubActions = Self(rawValue: "github.github-actions")
    public static let githubAdvancedSecurity = Self(rawValue: "github.github-advanced-security")
    public static let githubCopilot = Self(rawValue: "github.github-copilot")
    public static let aws = Self(rawValue: "aws.amazon-web-services-aws")
    public static let amazonBedrock = Self(rawValue: "aws.amazon-bedrock")
    public static let googleCloud = Self(rawValue: "google.google-cloud")
    public static let kubernetes = Self(rawValue: "cncf.kubernetes-cncf")
}

public enum BrandContext: String, Codable, CaseIterable, Sendable {
    case diagram
    case learningContent
    case catalog
    case passport
}

public struct BrandVendorEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let notice: String
    public let termsUrl: String
}

public struct BrandIconConstraints: Codable, Equatable, Sendable {
    public let minSizePt: Double
    public let clearSpaceRatio: Double
    public let neutralPlateRequired: Bool
    public let darkVariantAvailable: Bool
}

public struct BrandIconManifestEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String { iconId }
    public let iconId: String
    public let vendor: String
    public let tier: Int
    public let kit: String
    public let kitVersion: String
    public let sourceUrl: String
    public let fileInKit: String
    public let storedFilename: String
    public let downloadedAt: String
    public let termsUrl: String
    public let termsSnapshot: String
    public let termsAcceptedBy: String?
    public let termsAcceptedAt: String?
    public let permissionEvidence: String?
    public let permittedContexts: [BrandContext]
    public let constraints: BrandIconConstraints
    public let attribution: String
    public let sha256: String
    public let status: String
    public let verifiedAt: String
    public let verifiedBy: String
}

public struct BrandProductManifestEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let vendor: String
    public let officialName: String
    public let aliases: [String]
    public let tier: Int
    public let icon: String?
    public let status: String
    public let permittedContexts: [BrandContext]
    public let fallbackReason: String
    public let fallbackDate: String
    public let decisionRef: String
}

public struct BrandManifestDocument: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let generatedAt: String
    public let nonAffiliationNotice: String
    public let vendors: [BrandVendorEntry]
    public let icons: [BrandIconManifestEntry]
    public let products: [BrandProductManifestEntry]
}

public enum BrandResolution: Equatable, Sendable {
    case officialIcon(iconId: String, officialName: String, vendor: String, constraints: BrandIconConstraints)
    case fallback(officialName: String, vendor: String, reason: String)

    public var officialName: String {
        switch self {
        case .officialIcon(_, let officialName, _, _):
            return officialName
        case .fallback(let officialName, _, _):
            return officialName
        }
    }

    public var isOfficialIcon: Bool {
        if case .officialIcon = self { return true }
        return false
    }
}

public struct BrandCoverageReport: Equatable, Sendable {
    public let totalProducts: Int
    public let approvedIconsCount: Int
    public let pendingPermissionCount: Int
    public let fallbackOnlyCount: Int
    public let byVendor: [String: Int]
}

public struct BrandRegistry: Sendable {
    public static let bundle: Bundle = .module
    public static let shared: BrandRegistry = {
        do {
            return try BrandRegistry.loadFromBundle()
        } catch {
            return BrandRegistry(
                manifest: BrandManifestDocument(
                    schemaVersion: "1.0",
                    generatedAt: "",
                    nonAffiliationNotice: "",
                    vendors: [],
                    icons: [],
                    products: []
                )
            )
        }
    }()

    public let manifest: BrandManifestDocument
    private let productsByID: [String: BrandProductManifestEntry]
    private let iconsByID: [String: BrandIconManifestEntry]

    public init(manifest: BrandManifestDocument) {
        self.manifest = manifest
        self.productsByID = Dictionary(uniqueKeysWithValues: manifest.products.map { ($0.id, $0) })
        self.iconsByID = Dictionary(uniqueKeysWithValues: manifest.icons.map { ($0.iconId, $0) })
    }

    public static func loadFromBundle() throws -> BrandRegistry {
        guard let url = Bundle.module.url(forResource: "brand-manifest", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(BrandManifestDocument.self, from: data)
        return BrandRegistry(manifest: manifest)
    }

    public func productEntry(for id: BrandProductID) -> BrandProductManifestEntry? {
        productsByID[id.rawValue]
    }

    public func iconEntry(for iconId: String) -> BrandIconManifestEntry? {
        iconsByID[iconId]
    }

    /// Resolves a product + usage context into either an approved official icon or a documented fallback (§22A.5).
    public func resolve(
        product id: BrandProductID,
        context: BrandContext,
        flags: FeatureFlags? = nil,
        requireGlobalFlagEnabled: Bool = false
    ) -> BrandResolution {
        guard let product = productsByID[id.rawValue] else {
            return .fallback(
                officialName: id.rawValue,
                vendor: "other",
                reason: "Produit non trouvé dans le registre BrandAssets"
            )
        }

        if let flags {
            if requireGlobalFlagEnabled && !flags.isEnabled(.brandIcons) {
                return .fallback(
                    officialName: product.officialName,
                    vendor: product.vendor,
                    reason: "Interrupteur global brand.icons.v1 désactivé"
                )
            }
            if let vendorEnum = FeatureFlag.BrandVendor(rawValue: product.vendor) {
                let vendorFlag = FeatureFlag.brandIcons(vendor: vendorEnum)
                if requireGlobalFlagEnabled {
                    if !flags.isEnabled(vendorFlag) {
                        return .fallback(
                            officialName: product.officialName,
                            vendor: product.vendor,
                            reason: "Interrupteur éditeur \(vendorFlag.rawValue) désactivé"
                        )
                    }
                } else if flags.isVendorExplicitlyDisabled(vendorEnum) {
                    return .fallback(
                        officialName: product.officialName,
                        vendor: product.vendor,
                        reason: "Interrupteur éditeur \(vendorFlag.rawValue) désactivé"
                    )
                }
            }
        }

        guard product.status == "approved",
              let iconId = product.icon,
              let icon = iconsByID[iconId],
              icon.status == "approved",
              icon.permittedContexts.contains(context)
        else {
            return .fallback(
                officialName: product.officialName,
                vendor: product.vendor,
                reason: product.fallbackReason
            )
        }

        return .officialIcon(
            iconId: icon.iconId,
            officialName: product.officialName,
            vendor: product.vendor,
            constraints: icon.constraints
        )
    }

    /// Maps an exam or track code (e.g. "AZ-900", "AI-103", "DP-600", "GH-300") to its primary BrandProductID.
    public static func productID(forTrackCode code: String) -> BrandProductID {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("AI-") {
            return .microsoftFoundry
        }
        if normalized.hasPrefix("DP-") || normalized.contains("FABRIC") {
            return .microsoftFabric
        }
        if normalized.hasPrefix("SC-") {
            return .microsoftEntraID
        }
        if normalized.hasPrefix("PL-") {
            return .microsoftPowerPlatform
        }
        if normalized.hasPrefix("MB-") || normalized.hasPrefix("D365") {
            return .microsoftDynamics365
        }
        if normalized.hasPrefix("MO-") || normalized.contains("EXCEL") {
            return .m365Excel
        }
        if normalized.contains("WORD") {
            return .m365Word
        }
        if normalized.hasPrefix("GH-") || normalized.contains("GITHUB") {
            return .githubActions
        }
        if normalized.hasPrefix("AWS") || normalized.hasPrefix("CLF-") || normalized.hasPrefix("SAA-") {
            return .aws
        }
        if normalized.hasPrefix("CK") || normalized.contains("K8S") {
            return .kubernetes
        }
        return .microsoftAzure
    }


    public func withAddedPermittedContext(
        _ context: BrandContext,
        forIcon targetIconId: String,
        permissionEvidence: String
    ) -> BrandRegistry {
        let updatedIcons = manifest.icons.map { icon -> BrandIconManifestEntry in
            guard icon.iconId == targetIconId else { return icon }
            var contexts = icon.permittedContexts
            if !contexts.contains(context) {
                contexts.append(context)
            }
            return BrandIconManifestEntry(
                iconId: icon.iconId,
                vendor: icon.vendor,
                tier: icon.tier,
                kit: icon.kit,
                kitVersion: icon.kitVersion,
                sourceUrl: icon.sourceUrl,
                fileInKit: icon.fileInKit,
                storedFilename: icon.storedFilename,
                downloadedAt: icon.downloadedAt,
                termsUrl: icon.termsUrl,
                termsSnapshot: icon.termsSnapshot,
                termsAcceptedBy: icon.termsAcceptedBy,
                termsAcceptedAt: icon.termsAcceptedAt,
                permissionEvidence: permissionEvidence,
                permittedContexts: contexts,
                constraints: icon.constraints,
                attribution: icon.attribution,
                sha256: icon.sha256,
                status: icon.status,
                verifiedAt: icon.verifiedAt,
                verifiedBy: icon.verifiedBy
            )
        }
        return BrandRegistry(
            manifest: BrandManifestDocument(
                schemaVersion: manifest.schemaVersion,
                generatedAt: manifest.generatedAt,
                nonAffiliationNotice: manifest.nonAffiliationNotice,
                vendors: manifest.vendors,
                icons: updatedIcons,
                products: manifest.products
            )
        )
    }

    public func coverageReport() -> BrandCoverageReport {
        var approved = 0
        var pending = 0
        var fallbackOnly = 0
        var byVendor: [String: Int] = [:]
        for p in manifest.products {
            byVendor[p.vendor, default: 0] += 1
            if p.status == "approved" {
                approved += 1
            } else if p.status == "pending-permission" {
                pending += 1
            } else {
                fallbackOnly += 1
            }
        }
        return BrandCoverageReport(
            totalProducts: manifest.products.count,
            approvedIconsCount: approved,
            pendingPermissionCount: pending,
            fallbackOnlyCount: fallbackOnly,
            byVendor: byVendor
        )
    }
}
