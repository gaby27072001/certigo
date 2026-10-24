import BrandAssets
import Foundation

public struct BrandNoticesModel: Equatable, Sendable {
    public static let mandatoryNonAffiliationNotice =
        "CertiGo est une application indépendante. Elle n'est ni affiliée à, ni autorisée, sponsorisée ou approuvée par les éditeurs cités, dont Microsoft Corporation et GitHub, Inc. Les noms, icônes et logos de produits appartiennent à leurs propriétaires respectifs et ne sont utilisés que pour identifier leurs produits."

    public struct KitSummary: Equatable, Sendable, Identifiable {
        public var id: String { "\(vendorId).\(kit)" }
        public let vendorId: String
        public let kit: String
        public let kitVersion: String
        public let termsUrl: String
        public let iconCount: Int
    }

    public let nonAffiliationNotice: String
    public let vendors: [BrandVendorEntry]
    public let kits: [KitSummary]
    public let octiconsMITNotice: String

    public init(registry: BrandRegistry = .shared) {
        let notice = registry.manifest.nonAffiliationNotice
        self.nonAffiliationNotice = notice.isEmpty ? Self.mandatoryNonAffiliationNotice : notice
        self.vendors = registry.manifest.vendors

        var kitGroups: [String: (vendor: String, kit: String, version: String, terms: String, count: Int)] = [:]
        for icon in registry.manifest.icons {
            let key = "\(icon.vendor)|\(icon.kit)"
            let current = kitGroups[key]
            kitGroups[key] = (
                vendor: icon.vendor,
                kit: icon.kit,
                version: icon.kitVersion,
                terms: icon.termsUrl,
                count: (current?.count ?? 0) + 1
            )
        }
        self.kits = kitGroups.values
            .sorted { $0.kit < $1.kit }
            .map {
                KitSummary(
                    vendorId: $0.vendor,
                    kit: $0.kit,
                    kitVersion: $0.version,
                    termsUrl: $0.terms,
                    iconCount: $0.count
                )
            }
        self.octiconsMITNotice = "Primer Octicons — Copyright (c) 2026 GitHub, Inc. Distribué sous licence MIT."
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Screen "Profil › À propos › Marques et mentions légales" (§22A.7).
public struct BrandNoticesView: View {
    public let model: BrandNoticesModel

    public init(registry: BrandRegistry = .shared) {
        self.model = BrandNoticesModel(registry: registry)
    }

    public var body: some View {
        List {
            Section {
                Text(verbatim: model.nonAffiliationNotice)
                    .prismTextStyle(.body)
                    .foregroundStyle(PrismColor.textPrimary)
            } header: {
                Text(verbatim: "Non-affiliation")
            }

            Section {
                ForEach(model.vendors) { vendor in
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: vendor.name)
                            .prismTextStyle(.headline)
                            .foregroundStyle(PrismColor.textPrimary)
                        Text(verbatim: vendor.notice)
                            .prismTextStyle(.footnote)
                            .foregroundStyle(PrismColor.textSecondary)
                        Text(verbatim: vendor.termsUrl)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.accent)
                    }
                    .padding(.vertical, PrismSpacing.xs)
                }
            } header: {
                Text(verbatim: "Éditeurs et mentions de marque")
            }

            Section {
                ForEach(model.kits) { kit in
                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "\(kit.kit) (\(kit.kitVersion)) · \(kit.iconCount) icônes")
                            .prismTextStyle(.subheadline)
                            .foregroundStyle(PrismColor.textPrimary)
                        Text(verbatim: kit.termsUrl)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.textSecondary)
                    }
                    .padding(.vertical, PrismSpacing.xxs)
                }
            } header: {
                Text(verbatim: "Kits officiels importés (Niveau 1)")
            }

            Section {
                Text(verbatim: model.octiconsMITNotice)
                    .prismTextStyle(.footnote)
                    .foregroundStyle(PrismColor.textSecondary)
            } header: {
                Text(verbatim: "Licences Open Source")
            }
        }
        .navigationTitle(Text(verbatim: "Marques et mentions légales"))
    }
}

#Preview("BrandNoticesView") {
    NavigationStack {
        BrandNoticesView()
    }
}
#endif
