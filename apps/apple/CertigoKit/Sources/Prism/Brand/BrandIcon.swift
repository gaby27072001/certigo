import BrandAssets
import CertigoDomain
import Foundation

public enum PrismBrandIconSize: CaseIterable, Equatable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    public var points: CGFloat {
        switch self {
        case .small: PrismSize.brandS
        case .medium: PrismSize.brandM
        case .large: PrismSize.brandL
        case .extraLarge: PrismSize.brandXL
        }
    }

    public var clearSpacePadding: CGFloat {
        switch self {
        case .small: PrismSpacing.xs
        case .medium: PrismSpacing.s
        case .large: PrismSpacing.m
        case .extraLarge: PrismSpacing.l
        }
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Renders an unmodified official publisher icon on a neutral plate, or falls back cleanly (§22A.6, §22A.8).
public struct BrandIcon: View {
    public let product: BrandProductID
    public let context: BrandContext
    public let size: PrismBrandIconSize
    public let registry: BrandRegistry
    public let flags: FeatureFlags?
    @Environment(\.colorSchemeContrast) private var contrast

    public init(
        product: BrandProductID,
        context: BrandContext,
        size: PrismBrandIconSize = .medium,
        registry: BrandRegistry = .shared,
        flags: FeatureFlags? = nil
    ) {
        self.product = product
        self.context = context
        self.size = size
        self.registry = registry
        self.flags = flags
    }

    public var resolution: BrandResolution {
        registry.resolve(product: product, context: context, flags: flags)
    }

    public var body: some View {
        switch resolution {
        case .officialIcon(let iconId, let officialName, _, _):
            Image(iconId, bundle: BrandRegistry.bundle)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size.points, height: size.points)
                .padding(size.clearSpacePadding)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                        .fill(PrismColor.brandPlate)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                        .strokeBorder(
                            contrast == .increased ? PrismColor.textPrimary : PrismColor.separator,
                            lineWidth: contrast == .increased ? PrismBorder.strong : PrismBorder.hairline
                        )
                )
                .accessibilityIgnoresInvertColors(true)
                .accessibilityLabel(Text(verbatim: officialName))
                .accessibilityAddTraits(.isImage)
        case .fallback(let officialName, let vendor, let reason):
            BrandFallbackMark(
                officialName: officialName,
                region: BrandFallbackMarkModel.region(forVendor: vendor),
                fallbackReason: reason
            )
        }
    }
}
#endif
