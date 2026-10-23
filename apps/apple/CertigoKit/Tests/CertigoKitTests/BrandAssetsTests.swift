import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct BrandAssetsTests {
    private func repositoryRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        return root
    }

    @Test func completenessAndOriginalRenderingIntentInAssetCatalog() throws {
        let root = try repositoryRoot()
        let xcassets = root.appendingPathComponent(
            "apps/apple/CertigoKit/Sources/BrandAssets/Resources/BrandAssets.xcassets"
        )
        let registry = try BrandRegistry.loadFromBundle()
        let contents = try FileManager.default.contentsOfDirectory(
            at: xcassets, includingPropertiesForKeys: nil
        )
        let imagesets = contents.filter { $0.pathExtension == "imageset" }
        #expect(imagesets.count == registry.manifest.icons.count)
        #expect(imagesets.count == 80)

        let manifestIDs = Set(registry.manifest.icons.map(\.iconId))
        let folderIDs = Set(imagesets.map { $0.deletingPathExtension().lastPathComponent })
        #expect(manifestIDs == folderIDs)

        var totalBytes = 0
        for iset in imagesets {
            let jsonURL = iset.appendingPathComponent("Contents.json")
            let data = try Data(contentsOf: jsonURL)
            let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let props = try #require(obj["properties"] as? [String: Any])
            #expect(props["template-rendering-intent"] as? String == "original")
            #expect(props["preserves-vector-representation"] as? Bool == true)

            let iconId = iset.deletingPathExtension().lastPathComponent
            let entry = try #require(registry.iconEntry(for: iconId))
            let svgURL = iset.appendingPathComponent(entry.storedFilename)
            let svgData = try Data(contentsOf: svgURL)
            totalBytes += svgData.count
            #expect(!svgData.isEmpty)

            let termsURL = root.appendingPathComponent(entry.termsSnapshot)
            #expect(FileManager.default.fileExists(atPath: termsURL.path))
        }
        // §22A.9: initial budget <= 2 MB
        #expect(totalBytes <= 2 * 1024 * 1024)
    }

    @Test func coverageReportAccountsForEveryRegisteredProduct() throws {
        let registry = try BrandRegistry.loadFromBundle()
        let report = registry.coverageReport()
        #expect(report.totalProducts == 132)
        #expect(report.approvedIconsCount == 80)
        #expect(report.approvedIconsCount + report.pendingPermissionCount + report.fallbackOnlyCount == report.totalProducts)

        for product in registry.manifest.products {
            if product.status == "approved" {
                let iconId = try #require(product.icon)
                #expect(registry.iconEntry(for: iconId) != nil)
            } else {
                #expect(!product.fallbackReason.isEmpty)
                #expect(!product.fallbackDate.isEmpty)
                #expect(product.decisionRef == "DR-010")
            }
        }
    }

    @Test func givenWhenThenAcceptanceCriteriaForOfficialBrandIconography() throws {
        let registry = try BrandRegistry.loadFromBundle()

        // 1. Given a Situation diagram with Azure VM, VNet, and Load Balancer -> official icons + official names
        for product in [BrandProductID.azureVirtualMachines, .azureVirtualNetwork, .azureLoadBalancer] {
            let res = registry.resolve(product: product, context: .diagram)
            #expect(res.isOfficialIcon)
            let label = BrandLabelConfiguration(product: product, context: .diagram, registry: registry)
            #expect(label.accessibilitySpokenLabel == res.officialName)
        }

        // 2. Given AZ-900 in .catalog without .catalog permission -> fallback mark + text, and when .catalog is added -> official icon without code change
        let az900Catalog = registry.resolve(product: .microsoftAzure, context: .catalog)
        #expect(!az900Catalog.isOfficialIcon)
        let az900Label = BrandLabelConfiguration(
            product: .microsoftAzure, context: .catalog, examCode: "AZ-900", registry: registry
        )
        #expect(az900Label.displayedText == "AZ-900 · Microsoft Azure")

        let unlockedRegistry = registry.withAddedPermittedContext(
            .catalog,
            forIcon: "b001-ms-azure",
            permissionEvidence: "docs/legal/brand-terms/microsoft-catalog-permission.pdf"
        )
        #expect(unlockedRegistry.resolve(product: .microsoftAzure, context: .catalog).isOfficialIcon)

        // 3. Given Microsoft Office Specialist: Excel without trademark license -> fallback text "Microsoft Excel"
        let excelRes = registry.resolve(product: .m365Excel, context: .learningContent)
        #expect(!excelRes.isOfficialIcon)
        #expect(excelRes.officialName == "Microsoft Excel")

        // 4. Given remote kill switch brand.icons.microsoft OFF -> all Microsoft icons switch to fallback
        var flags = FeatureFlags()
        try flags.applyRemoteJSON(Data(#"{"brand.icons.microsoft": false}"#.utf8))
        let killedRes = registry.resolve(
            product: .azureVirtualMachines, context: .learningContent, flags: flags
        )
        #expect(!killedRes.isOfficialIcon)

        // 5. Given BrandNoticesModel -> non-affiliation notice + every vendor + kits present
        let notices = BrandNoticesModel(registry: registry)
        #expect(notices.nonAffiliationNotice.contains("application indépendante"))
        #expect(!notices.vendors.isEmpty)
        #expect(!notices.kits.isEmpty)
    }

    @Test func freshnessOfVerifiedManifestEntriesWithinNinetyDays() throws {
        let registry = try BrandRegistry.loadFromBundle()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let referenceDate = try #require(formatter.date(from: "2026-10-23"))
        for icon in registry.manifest.icons {
            let verifiedDate = try #require(formatter.date(from: icon.verifiedAt))
            let days = Calendar(identifier: .gregorian)
                .dateComponents([.day], from: verifiedDate, to: referenceDate).day ?? 999
            #expect(days <= 90)
        }
    }
}
