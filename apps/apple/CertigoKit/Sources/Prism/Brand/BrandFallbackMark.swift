import BrandAssets
import Foundation

public struct BrandFallbackMarkModel: Equatable, Sendable {
    public let officialName: String
    public let region: PrismRegion
    public let examCode: String?
    public let fallbackReason: String

    public init(
        officialName: String,
        region: PrismRegion = .cloud,
        examCode: String? = nil,
        fallbackReason: String = ""
    ) {
        self.officialName = officialName
        self.region = region
        self.examCode = examCode
        self.fallbackReason = fallbackReason
    }

    public var displayTitle: String {
        if let examCode, !examCode.isEmpty {
            return "\(examCode) · \(officialName)"
        }
        return officialName
    }

    public static func region(forVendor vendor: String) -> PrismRegion {
        switch vendor {
        case "microsoft": .cloud
        case "github": .devops
        case "aws": .cloud
        case "google": .data
        case "cncf": .systems
        case "linux": .systems
        case "cisco": .network
        default: .cloud
        }
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Neutral CertiGo fallback mark (§22A.11) — never imitates a third-party logo or certification badge.
public struct BrandFallbackMark: View {
    public let model: BrandFallbackMarkModel
    @Environment(\.colorSchemeContrast) private var contrast

    public init(model: BrandFallbackMarkModel) {
        self.model = model
    }

    public init(
        officialName: String,
        region: PrismRegion = .cloud,
        examCode: String? = nil,
        fallbackReason: String = ""
    ) {
        self.model = BrandFallbackMarkModel(
            officialName: officialName,
            region: region,
            examCode: examCode,
            fallbackReason: fallbackReason
        )
    }

    public var body: some View {
        HStack(spacing: PrismSpacing.s) {
            PrismIcon(glyph: .region(model.region), accessibilityLabel: nil)
                .foregroundStyle(model.region.color)
            Text(verbatim: model.displayTitle)
                .prismTextStyle(.subheadline)
                .foregroundStyle(PrismColor.textPrimary)
        }
        .padding(.horizontal, PrismSpacing.m)
        .padding(.vertical, PrismSpacing.s)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.displayTitle))
    }
}
#endif
