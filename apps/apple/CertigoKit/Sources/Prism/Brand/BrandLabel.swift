import BrandAssets
import CertigoDomain
import Foundation

public struct BrandLabelConfiguration: Equatable, Sendable {
    public let product: BrandProductID
    public let context: BrandContext
    public let examCode: String?
    public let size: PrismBrandIconSize
    public let resolution: BrandResolution

    public init(
        product: BrandProductID,
        context: BrandContext,
        examCode: String? = nil,
        size: PrismBrandIconSize = .medium,
        registry: BrandRegistry = .shared,
        flags: FeatureFlags? = nil
    ) {
        self.product = product
        self.context = context
        self.examCode = examCode
        self.size = size
        self.resolution = registry.resolve(product: product, context: context, flags: flags)
    }

    public var displayedText: String {
        if let examCode, !examCode.isEmpty {
            return "\(examCode) · \(resolution.officialName)"
        }
        return resolution.officialName
    }

    /// VoiceOver reads the official name (and exam code if present) exactly once (§22A.8).
    public var accessibilitySpokenLabel: String {
        displayedText
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Official icon + full untranslated official product name as a single VoiceOver element (§22A.8).
public struct BrandLabel: View {
    public let configuration: BrandLabelConfiguration
    public let registry: BrandRegistry
    public let flags: FeatureFlags?

    public init(
        product: BrandProductID,
        context: BrandContext = .learningContent,
        examCode: String? = nil,
        size: PrismBrandIconSize = .medium,
        registry: BrandRegistry = .shared,
        flags: FeatureFlags? = nil
    ) {
        self.registry = registry
        self.flags = flags
        self.configuration = BrandLabelConfiguration(
            product: product,
            context: context,
            examCode: examCode,
            size: size,
            registry: registry,
            flags: flags
        )
    }

    public var body: some View {
        Group {
            switch configuration.resolution {
            case .officialIcon:
                PrismAdaptiveStack(spacing: PrismSpacing.s) {
                    BrandIcon(
                        product: configuration.product,
                        context: configuration.context,
                        size: configuration.size,
                        registry: registry,
                        flags: flags
                    )
                    .accessibilityHidden(true)

                    PrismText(text: configuration.displayedText, style: .subheadline, role: .textPrimary)
                }
            case .fallback(let officialName, let vendor, let reason):
                BrandFallbackMark(
                    officialName: officialName,
                    region: BrandFallbackMarkModel.region(forVendor: vendor),
                    examCode: configuration.examCode,
                    fallbackReason: reason
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: configuration.accessibilitySpokenLabel))
    }
}
#endif
