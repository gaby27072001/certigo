import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeContentLanguageBadges: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let languages: [String]

        var body: some View {
            ForEach(NativeDeclaredContentLanguage.badges(languages), id: \.self) { language in
                Label(
                    language == "FR" ? copy[.contentLanguageFR] : copy[.contentLanguageEN],
                    systemImage: "textformat"
                )
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(NativePrism.surface, in: Capsule(style: .continuous))
                .accessibilityLabel("\(copy.native(.contentLanguage)) · \(language)")
            }
        }
    }

    // THESIS: A vibrant learning studio; evidence becomes visible progress, never invented success.
    // OWN-WORLD: Ocean, indigo, emerald, amber and plum; SF medallions, rings and opaque reading.
    // STORY: See today's confirmed state, take one lesson, understand the answer, return tomorrow.
    // FIRST VIEWPORT: Compact activity tiles, a spectrum goal with readiness ring, one next action.
    // FORM: User-selected Brilliant / Duolingo + Apple Fitness+; native navigation stays authoritative.
    enum NativePrism {
        // Prism spectrumInk / spectrumGlow plus info; glow is never a solid reading fill.
        private static let ink: [UInt32] = [
            0x3B35F2, 0x901BAE, 0xA91A66, 0x924A13, 0x177331, 0x176C7A, 0x1562AA,
        ]
        private static let glow: [UInt32] = [
            0x8097F8, 0xD764F8, 0xF95DA5, 0xEC7B26, 0x2DBC55, 0x2CB0C7, 0x52A2F8,
        ]
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let edge = Color(
            uiColor: UIColor { traits in
                traits.accessibilityContrast == .high ? .label : .separator
            })
        static let tint = accent(band: 0)
        static let objectiveFill = Color(uiColor: color(ink[0]))
        static let confirmed = accent(band: 4)
        static let pending = accent(band: 3)
        // PrismMotion.base and standard, shared with the Flutter design system.
        static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)

        static func accent(for code: String) -> Color {
            NativeTrackTheme(code: code).accent
        }

        static func solid(band: Int) -> Color { Color(uiColor: color(ink[band])) }

        static func accent(band: Int) -> Color {
            Color(
                uiColor: UIColor { traits in
                    let dark = traits.userInterfaceStyle == .dark
                    let base = color(dark ? glow[band] : ink[band])
                    guard traits.accessibilityContrast == .high else { return base }
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    let target: CGFloat = dark ? 1 : 0
                    return UIColor(
                        red: red + (target - red) * 0.25,
                        green: green + (target - green) * 0.25,
                        blue: blue + (target - blue) * 0.25, alpha: 1)
                })
        }

        private static func color(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    struct NativeTrackTheme {
        let band: Int
        let symbol: String

        init(band: Int, symbol: String) {
            self.band = band
            self.symbol = symbol
        }

        init(code: String) {
            let value = code.uppercased()
            if value.hasPrefix("GH-") || value.contains(":GH-") || value.hasPrefix("GITHUB") {
                band = 0
                symbol = "sparkles"
            } else if value.hasPrefix("AWS") || value.contains("AWS:") {
                band = 3
                symbol = "cloud.sun.fill"
            } else if value.hasPrefix("DP-") || value.contains(":DP-")
                || value.contains("FABRIC")
            {
                band = 4
                symbol = "square.stack.3d.up.fill"
            } else if value.hasPrefix("SC-") || value.contains(":SC-")
                || value.contains("SECURITY")
            {
                band = 1
                symbol = "checkmark.shield.fill"
            } else if value.hasPrefix("AZ-") || value.contains(":AZ-") {
                band = 6
                symbol = "cloud.fill"
            } else if value.hasPrefix("AI-") || value.contains(":AI-") {
                band = 0
                symbol = "brain"
            } else {
                band = NativeTrackAppearance.band(for: code)
                symbol = "books.vertical.fill"
            }
        }

        var accent: Color { NativePrism.accent(band: band) }
        var gradient: LinearGradient {
            LinearGradient(
                colors: [
                    NativePrism.solid(band: band),
                    NativePrism.solid(band: band == 3 ? 2 : (band + 1) % 7),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    struct NativeSymbolMedallion: View {
        let symbol: String
        var accent: Color = NativePrism.tint

        var body: some View {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 52, height: 52)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
        }
    }

    // Original Certigo preparation artwork, not official certification badges.
    struct NativeEcosystemArtwork {
        enum Silhouette: Sendable { case pennant, hexagon, octagon }
        enum Motif: Sendable {
            case microsoftAzure, microsoftFabric, microsoftSecurity
            case github, aws, google
            case facets, constellation, ribbons
        }
        static let microsoftTileColors = Self.colors([
            0xF25022, 0x7FBA00, 0x00A4EF, 0xFFB900,
        ])
        let silhouette: Silhouette
        let motif: Motif
        let isMicrosoft: Bool
        let colors: [Color]

        init(code: String) {
            let normalized = NativeTrackAppearance.normalized(code)
            let components = normalized.split(separator: "-").map(String.init)
            let family = NativeCatalogFilter.family(for: code)
            if components.contains("GH") || family == "GITHUB" {
                silhouette = .octagon
                motif = .github
                isMicrosoft = false
                colors = Self.colors([0x24292F, 0x8534F3, 0xBF3989, 0x2DA44E])
            } else if family == "AWS"
                || components.contains(where: {
                    ["AWS", "CLF", "AIF", "SAA", "DVA", "SOA", "SAP", "DOP"].contains($0)
                })
            {
                silhouette = .hexagon
                motif = .aws
                isMicrosoft = false
                colors = Self.colors([0x232F3E, 0xFF9900])
            } else if family == "GCP" || components.contains("GOOGLE") {
                silhouette = .hexagon
                motif = .google
                isMicrosoft = false
                colors = Self.colors([0x4285F4, 0xEA4335, 0xFBBC05, 0x34A853])
            } else if components.contains("DP") || normalized.contains("FABRIC") {
                silhouette = .pennant
                motif = .microsoftFabric
                isMicrosoft = true
                colors = Self.colors([0x00B7C3, 0x117865, 0x79E7C5])
            } else if components.contains("SC") || normalized.contains("SECURITY") {
                silhouette = .pennant
                motif = .microsoftSecurity
                isMicrosoft = true
                colors = Self.colors([0x008559, 0x0078D4, 0xA5E8D1])
            } else if family == "MICROSOFT"
                || components.contains(where: {
                    ["MICROSOFT", "MSFT", "AZ", "AI", "MS", "PL"].contains($0)
                })
            {
                silhouette = .pennant
                motif = .microsoftAzure
                isMicrosoft = true
                colors = Self.colors([0x0078D4, 0x50E6FF, 0x00A4EF])
            } else if family == "ISC2" {
                silhouette = .pennant
                motif = .constellation
                isMicrosoft = false
                colors = Self.colors([0x008559, 0x0078D4, 0xA5E8D1])
            } else if family == "COMPTIA" {
                silhouette = .octagon
                motif = .ribbons
                isMicrosoft = false
                colors = Self.colors([0xC8102E, 0xF58CA1, 0x54253F])
            } else if family == "CNCF" || components.contains("KUBERNETES") {
                silhouette = .hexagon
                motif = .constellation
                isMicrosoft = false
                colors = Self.colors([0x326CE5, 0x8DD9FF, 0x5962B8])
            } else {
                silhouette = .pennant
                motif = .facets
                isMicrosoft = false
                colors = [
                    NativePrism.accent(for: code), NativePrism.accent(band: 1),
                    NativePrism.accent(band: 6),
                ]
            }
        }

        static func paintMicrosoftTiles(in context: inout GraphicsContext, rect: CGRect) {
            let gutter = rect.width * 0.08
            let tile = (rect.width - gutter) / 2
            let radius = tile * 0.08
            let origins = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.minX + tile + gutter, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.minY + tile + gutter),
                CGPoint(x: rect.minX + tile + gutter, y: rect.minY + tile + gutter),
            ]
            for (index, origin) in origins.enumerated() {
                let tileRect = CGRect(x: origin.x, y: origin.y, width: tile, height: tile)
                context.fill(
                    Path(roundedRect: tileRect, cornerRadius: radius),
                    with: .color(microsoftTileColors[index]))
            }
        }

        private static func colors(_ hexes: [UInt32]) -> [Color] {
            hexes.map {
                Color(
                    .sRGB, red: Double(($0 >> 16) & 255) / 255,
                    green: Double(($0 >> 8) & 255) / 255, blue: Double($0 & 255) / 255,
                    opacity: 1)
            }
        }
    }

    private struct NativeCrestOutline: Shape {
        let silhouette: NativeEcosystemArtwork.Silhouette

        func path(in rect: CGRect) -> Path {
            let vertices: [CGPoint]
            switch silhouette {
            case .pennant:
                vertices = [
                    .init(x: 0.16, y: 0.04), .init(x: 0.84, y: 0.04),
                    .init(x: 0.96, y: 0.20), .init(x: 0.86, y: 0.76),
                    .init(x: 0.50, y: 0.98), .init(x: 0.14, y: 0.76),
                    .init(x: 0.04, y: 0.20),
                ]
            case .hexagon:
                vertices = [
                    .init(x: 0.50, y: 0.02), .init(x: 0.94, y: 0.25),
                    .init(x: 0.94, y: 0.75), .init(x: 0.50, y: 0.98),
                    .init(x: 0.06, y: 0.75), .init(x: 0.06, y: 0.25),
                ]
            case .octagon:
                vertices = [
                    .init(x: 0.30, y: 0.04), .init(x: 0.70, y: 0.04),
                    .init(x: 0.96, y: 0.30), .init(x: 0.96, y: 0.70),
                    .init(x: 0.70, y: 0.96), .init(x: 0.30, y: 0.96),
                    .init(x: 0.04, y: 0.70), .init(x: 0.04, y: 0.30),
                ]
            }
            var path = Path()
            path.addLines(
                vertices.map {
                    CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
                })
            path.closeSubpath()
            return path
        }
    }

    struct NativeMicrosoftVendorBadge: View {
        var size: CGFloat = 14

        var body: some View {
            Canvas { context, canvasSize in
                let edge = min(canvasSize.width, canvasSize.height)
                let rect = CGRect(
                    x: (canvasSize.width - edge) / 2,
                    y: (canvasSize.height - edge) / 2,
                    width: edge, height: edge)
                NativeEcosystemArtwork.paintMicrosoftTiles(in: &context, rect: rect)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    struct NativeEcosystemEmblem: View {
        let code: String

        var body: some View {
            let artwork = NativeEcosystemArtwork(code: code)
            Canvas { context, size in
                let scale = min(size.width, size.height)
                let origin = CGPoint(x: (size.width - scale) / 2, y: (size.height - scale) / 2)
                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
                }
                switch artwork.motif {
                case .microsoftAzure:
                    var leftWing = Path()
                    leftWing.addLines([point(0.46, 0.10), point(0.14, 0.78), point(0.42, 0.68)])
                    leftWing.closeSubpath()
                    context.fill(leftWing, with: .color(artwork.colors[0]))
                    var rightWing = Path()
                    rightWing.addLines([
                        point(0.50, 0.16), point(0.86, 0.84), point(0.32, 0.84), point(0.56, 0.58),
                    ])
                    rightWing.closeSubpath()
                    context.fill(
                        rightWing,
                        with: .linearGradient(
                            Gradient(colors: [artwork.colors[1], artwork.colors[2]]),
                            startPoint: point(0.45, 0.16), endPoint: point(0.86, 0.84)))
                    let badgeRect = CGRect(
                        x: origin.x + scale * 0.08, y: origin.y + scale * 0.08,
                        width: scale * 0.26, height: scale * 0.26)
                    NativeEcosystemArtwork.paintMicrosoftTiles(in: &context, rect: badgeRect)
                case .microsoftFabric:
                    let layers: [([CGPoint], Color)] = [
                        (
                            [
                                point(0.52, 0.10), point(0.88, 0.36), point(0.52, 0.62),
                                point(0.16, 0.36),
                            ],
                            artwork.colors[0]
                        ),
                        (
                            [
                                point(0.52, 0.38), point(0.88, 0.62), point(0.52, 0.88),
                                point(0.16, 0.62),
                            ],
                            artwork.colors[1]
                        ),
                        (
                            [
                                point(0.52, 0.26), point(0.76, 0.48), point(0.52, 0.70),
                                point(0.28, 0.48),
                            ],
                            artwork.colors[2]
                        ),
                    ]
                    for (vertices, color) in layers {
                        var diamond = Path()
                        diamond.addLines(vertices)
                        diamond.closeSubpath()
                        context.fill(diamond, with: .color(color))
                    }
                    let badgeRect = CGRect(
                        x: origin.x + scale * 0.08, y: origin.y + scale * 0.08,
                        width: scale * 0.26, height: scale * 0.26)
                    NativeEcosystemArtwork.paintMicrosoftTiles(in: &context, rect: badgeRect)
                case .microsoftSecurity:
                    var outerShield = Path()
                    outerShield.addLines([
                        point(0.52, 0.10), point(0.86, 0.24), point(0.80, 0.64),
                        point(0.52, 0.90), point(0.24, 0.64), point(0.18, 0.24),
                    ])
                    outerShield.closeSubpath()
                    context.fill(
                        outerShield,
                        with: .linearGradient(
                            Gradient(colors: [artwork.colors[0], artwork.colors[1]]),
                            startPoint: point(0.18, 0.10), endPoint: point(0.86, 0.90)))
                    var innerCrest = Path()
                    innerCrest.addLines([
                        point(0.52, 0.24), point(0.72, 0.34), point(0.68, 0.60),
                        point(0.52, 0.76), point(0.36, 0.60), point(0.32, 0.34),
                    ])
                    innerCrest.closeSubpath()
                    context.fill(innerCrest, with: .color(artwork.colors[2]))
                    let badgeRect = CGRect(
                        x: origin.x + scale * 0.08, y: origin.y + scale * 0.08,
                        width: scale * 0.26, height: scale * 0.26)
                    NativeEcosystemArtwork.paintMicrosoftTiles(in: &context, rect: badgeRect)
                case .github:
                    let haloCenter = point(0.50, 0.50)
                    let haloRadius = scale * 0.44
                    var halo = Path()
                    halo.addArc(
                        center: haloCenter, radius: haloRadius,
                        startAngle: .radians(0), endAngle: .radians(2 * Double.pi),
                        clockwise: false)
                    context.stroke(
                        halo,
                        with: .linearGradient(
                            Gradient(colors: Array(artwork.colors.dropFirst())),
                            startPoint: point(0.06, 0.06), endPoint: point(0.94, 0.94)),
                        style: StrokeStyle(lineWidth: scale * 0.08, lineCap: .round))
                    var ears = Path()
                    ears.move(to: point(0.24, 0.30))
                    ears.addLine(to: point(0.36, 0.14))
                    ears.addLine(to: point(0.44, 0.34))
                    ears.closeSubpath()
                    ears.move(to: point(0.76, 0.30))
                    ears.addLine(to: point(0.64, 0.14))
                    ears.addLine(to: point(0.56, 0.34))
                    ears.closeSubpath()
                    context.fill(ears, with: .color(artwork.colors[0]))
                    let headR = scale * 0.34
                    let headCenter = point(0.50, 0.52)
                    let head = Path(
                        ellipseIn: CGRect(
                            x: headCenter.x - headR, y: headCenter.y - headR,
                            width: headR * 2, height: headR * 2))
                    context.fill(head, with: .color(artwork.colors[0]))
                    let body = Path(
                        roundedRect: CGRect(
                            x: origin.x + scale * 0.20, y: origin.y + scale * 0.52,
                            width: scale * 0.60, height: scale * 0.34),
                        cornerRadius: scale * 0.20)
                    context.fill(body, with: .color(artwork.colors[0]))
                    let eyeR = scale * 0.055
                    for eyeX in [0.40, 0.60] {
                        let eyeCenter = point(eyeX, 0.50)
                        let eye = Path(
                            ellipseIn: CGRect(
                                x: eyeCenter.x - eyeR, y: eyeCenter.y - eyeR,
                                width: eyeR * 2, height: eyeR * 2))
                        context.fill(eye, with: .color(.white))
                    }
                case .aws:
                    let backdrop = Path(
                        roundedRect: CGRect(
                            x: origin.x + scale * 0.06, y: origin.y + scale * 0.06,
                            width: scale * 0.88, height: scale * 0.88),
                        cornerRadius: scale * 0.22)
                    context.fill(backdrop, with: .color(artwork.colors[0]))
                    var arc = Path()
                    arc.move(to: point(0.16, 0.56))
                    arc.addQuadCurve(to: point(0.84, 0.56), control: point(0.50, 0.86))
                    context.stroke(
                        arc, with: .color(artwork.colors[1]),
                        style: StrokeStyle(lineWidth: scale * 0.11, lineCap: .round))
                    var arrow = Path()
                    arrow.move(to: point(0.84, 0.56))
                    arrow.addLine(to: point(0.72, 0.52))
                    arrow.addLine(to: point(0.80, 0.66))
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(artwork.colors[1]))
                case .google:
                    let center = point(0.50, 0.50)
                    let radius = scale * 0.36
                    let stroke = scale * 0.18
                    let start = -Double.pi / 4
                    let sweep = (2 * Double.pi - Double.pi / 3) / 4
                    for index in 0..<4 {
                        var segment = Path()
                        segment.addArc(
                            center: center, radius: radius,
                            startAngle: .radians(start + Double(index) * sweep),
                            endAngle: .radians(start + Double(index + 1) * sweep),
                            clockwise: false)
                        context.stroke(
                            segment, with: .color(artwork.colors[index]),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                    }
                    var bar = Path()
                    bar.move(to: CGPoint(x: center.x + radius * 0.1, y: center.y))
                    bar.addLine(to: CGPoint(x: center.x + radius + stroke * 0.2, y: center.y))
                    context.stroke(
                        bar, with: .color(artwork.colors[0]),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                case .facets:
                    let panels: [[CGPoint]] = [
                        [point(0.12, 0.28), point(0.51, 0.08), point(0.48, 0.54)],
                        [point(0.58, 0.14), point(0.91, 0.46), point(0.56, 0.58)],
                        [point(0.17, 0.39), point(0.47, 0.65), point(0.40, 0.92)],
                        [point(0.55, 0.69), point(0.87, 0.57), point(0.70, 0.88)],
                    ]
                    for (index, panel) in panels.enumerated() {
                        var facet = Path()
                        facet.addLines(panel)
                        facet.closeSubpath()
                        context.fill(
                            facet,
                            with: .linearGradient(
                                Gradient(colors: [
                                    artwork.colors[index % artwork.colors.count],
                                    artwork.colors[(index + 1) % artwork.colors.count],
                                ]),
                                startPoint: point(0, 0), endPoint: point(1, 1)))
                    }
                case .constellation:
                    let nodes = [
                        point(0.18, 0.40), point(0.48, 0.14), point(0.81, 0.32),
                        point(0.69, 0.78), point(0.27, 0.86),
                    ]
                    var links = Path()
                    links.addLines(nodes)
                    links.closeSubpath()
                    context.stroke(links, with: .color(artwork.colors[0]), lineWidth: scale * 0.045)
                    for (index, node) in nodes.enumerated() {
                        let radius = scale * (index == 1 ? 0.12 : 0.075)
                        let circle = Path(
                            ellipseIn: CGRect(
                                x: node.x - radius, y: node.y - radius,
                                width: radius * 2, height: radius * 2))
                        context.fill(
                            circle, with: .color(artwork.colors[index % artwork.colors.count]))
                    }
                case .ribbons:
                    for index in 0..<artwork.colors.count {
                        let y = CGFloat(index) * 0.17 + 0.12
                        var ribbon = Path()
                        ribbon.move(to: point(0.12, y + 0.18))
                        ribbon.addCurve(
                            to: point(0.88, y + 0.04),
                            control1: point(0.36, y - 0.16), control2: point(0.62, y + 0.42))
                        context.stroke(
                            ribbon, with: .color(artwork.colors[index]),
                            style: StrokeStyle(lineWidth: scale * 0.10, lineCap: .round))
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    struct NativeCertificationCrest: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.colorSchemeContrast) private var contrast
        @ScaledMetric(relativeTo: .headline) private var emblemSize = 70.0
        let code: String
        var compact = false

        var body: some View {
            let artwork = NativeEcosystemArtwork(code: code)
            let layout =
                compact
                ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 8))
            layout {
                ZStack {
                    NativeCrestOutline(silhouette: artwork.silhouette)
                        .fill(NativePrism.surface)
                    NativeCrestOutline(silhouette: artwork.silhouette)
                        .stroke(
                            contrast == .increased
                                ? NativePrism.edge : NativePrism.accent(for: code),
                            lineWidth: 2)
                    NativeCrestOutline(silhouette: artwork.silhouette)
                        .stroke(NativePrism.accent(for: code).opacity(0.5), lineWidth: 1)
                        .padding(6)
                    NativeEcosystemEmblem(code: code).padding(compact ? 10 : 16)
                }
                .frame(
                    width: min(112, emblemSize) * (compact ? 0.65 : 1),
                    height: min(112, emblemSize) * (compact ? 0.65 : 1))
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        if artwork.isMicrosoft {
                            NativeMicrosoftVendorBadge(size: 11)
                        }
                        Text("Certigo").font(.caption2.weight(.medium))
                    }
                    Text(code).font(.system(.caption, design: .rounded, weight: .bold))
                }
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(NativePrism.accent(for: code))
                .background(NativePrism.surface, in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(copy.native(.learningPath)) · \(code)")
            .accessibilityIdentifier("certigo-preparation-crest")
        }
    }

    struct NativeShowcaseTile: View {
        let code: String
        let title: String
        var detail: String?
        var selected = false

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                NativeEcosystemEmblem(code: code)
                    .frame(width: 56, height: 56)
                    .padding(8)
                    .background(NativePrism.surface, in: RoundedRectangle(cornerRadius: 20))
                Text(title).font(.headline).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(.caption.weight(.medium)).foregroundStyle(.white)
                }
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .padding(20)
            .frame(width: 200, alignment: .leading)
            .background(
                NativeTrackTheme(code: code).gradient, in: RoundedRectangle(cornerRadius: 26)
            )
            .accessibilityElement(children: .combine)
        }
    }

    struct NativeDeveloperToolbar: ViewModifier {
        @Environment(\.nativeInterfaceCopy) private var copy
        let close: (() -> Void)?

        func body(content: Content) -> some View {
            content.toolbar {
                if let close {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: close) {
                            Image(systemName: "xmark").font(.caption.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(
                            "\(copy.native(.close)) · \(copy.native(.developerConnector))"
                        )
                        .accessibilityIdentifier("close-developer-connector")
                    }
                }
            }
        }
    }

    struct NativeReadinessRing: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @ScaledMetric(relativeTo: .title2) private var diameter = 88.0
        let percent: Int
        let title: String
        var accent: Color = NativePrism.tint

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(accent.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(100, max(0, percent))) / 100)
                        .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(percent) %").font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                .frame(width: diameter, height: diameter)
                Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            }
            .animation(reduceMotion ? nil : NativePrism.feedback, value: percent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(percent) %")
        }
    }

    struct NativeMetricTile: View {
        let title: String
        let value: String
        let symbol: String
        var accent: Color = NativePrism.tint

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                NativeSymbolMedallion(symbol: symbol, accent: accent)
                Text(value).font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(NativePrism.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(accent.opacity(0.18), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    struct NativeMetricGrid<Content: View>: View {
        @Environment(\.dynamicTypeSize) private var typeSize
        @ViewBuilder let content: Content

        var body: some View {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: typeSize.isAccessibilitySize ? 1 : 2),
                alignment: .leading, spacing: 12
            ) { content }
        }
    }

    struct NativeGoalHero: View {
        let title: String
        let subtitle: String
        let theme: NativeTrackTheme
        var readiness: Int?
        let readinessTitle: String
        var code: String?

        var body: some View {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    heading
                    if let readiness, (0...100).contains(readiness) {
                        NativeReadinessRing(
                            percent: readiness, title: readinessTitle, accent: .white)
                    }
                }
                VStack(alignment: .leading, spacing: 24) {
                    heading
                    if let readiness, (0...100).contains(readiness) {
                        NativeReadinessRing(
                            percent: readiness, title: readinessTitle, accent: .white)
                    }
                }
            }
            .padding(24).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.gradient, in: RoundedRectangle(cornerRadius: 28))
        }

        private var heading: some View {
            VStack(alignment: .leading, spacing: 12) {
                if let code {
                    NativeCertificationCrest(code: code, compact: true)
                } else {
                    NativeEcosystemEmblem(code: "")
                        .frame(width: 56, height: 56)
                }
                Text(title).font(.system(.title2, design: .rounded, weight: .bold)).fixedSize(
                    horizontal: false, vertical: true
                )
                .accessibilityAddTraits(.isHeader)
                Text(subtitle).font(.subheadline.weight(.medium))
            }
        }
    }

    struct NativeCertificationCard: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let track: Track

        var body: some View {
            let theme = NativeTrackTheme(code: track.code)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    NativeCertificationCrest(code: track.code)
                    Spacer()
                    Text(NativeCatalogFilter.family(for: track.code))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(theme.accent)
                        .background(theme.accent.opacity(0.12), in: Capsule())
                }
                Text(track.title).font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                NativeContentLanguageBadges(languages: track.languages ?? [])
                Text(track.summary).font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    NativePracticeBadge(available: track.learningAvailable)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(20)
            .background(NativePrism.surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(theme.accent.opacity(0.24), lineWidth: 1)
            }
        }
    }

    struct NativeAnswerLabel: View {
        let text: String
        let index: Int
        let selected: Bool

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(
                    index < 26
                        ? String("ABCDEFGHIJKLMNOPQRSTUVWXYZ".dropFirst(index).prefix(1))
                        : "\(index + 1)"
                )
                .font(.system(.headline, design: .rounded)).monospacedDigit()
                .frame(width: 36, height: 36)
                .foregroundStyle(selected ? Color.white : NativePrism.tint)
                .background(
                    selected ? NativePrism.objectiveFill : NativePrism.tint.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)
                Text(text).multilineTextAlignment(.leading).foregroundStyle(.primary)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(NativePrism.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    struct NativeQuestionProgress: View {
        let selected: Int
        let total: Int
        let title: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    ForEach(0..<min(max(total, 0), 30), id: \.self) { index in
                        Capsule()
                            .fill(
                                Double(index) / Double(min(total, 30))
                                    < Double(selected) / Double(max(1, total))
                                    ? NativePrism.tint : NativePrism.tint.opacity(0.15)
                            )
                            .frame(height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    struct NativePracticeBadge: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let available: Bool

        var body: some View {
            Label(
                copy[available ? .practiceAvailable : .practiceUnavailable],
                systemImage: available ? "book" : "book.closed"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NativePrism.surface, in: Capsule(style: .continuous))
            .accessibilityIdentifier("catalog-practice-availability")
        }
    }

    struct NativeReadingPage<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { content }
                    .padding(20)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .background(NativePrism.canvas)
        }
    }

    struct NativeCatalogSearch: ViewModifier {
        @Environment(\.nativeInterfaceCopy) private var copy
        let enabled: Bool
        @Binding var query: String

        @ViewBuilder func body(content: Content) -> some View {
            if enabled {
                content.searchable(text: $query, prompt: copy[.searchPlaceholder])
            } else {
                content
            }
        }
    }

    struct NativeReadingSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct NativeReadingCard<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    NativePrism.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(NativePrism.edge, lineWidth: 1)
                }
        }
    }

    struct NativePrimaryButton: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            Group {
                if #available(iOS 26.0, *), !reduceTransparency {
                    button.buttonStyle(.glassProminent)
                } else {
                    button.buttonStyle(.borderedProminent)
                }
            }
            .tint(NativePrism.objectiveFill)
        }

        private var button: some View {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
        }
    }

    struct NativeChoiceButtonStyle: ButtonStyle {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var isSelected = false
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .padding(16)
                .background(
                    isSelected
                        ? NativePrism.tint.opacity(0.1)
                        : configuration.isPressed
                            ? Color(uiColor: .tertiarySystemFill) : NativePrism.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? NativePrism.tint : NativePrism.edge,
                            lineWidth: isSelected ? 2 : 1)
                }
                .animation(reduceMotion ? nil : NativePrism.feedback, value: isSelected)
        }
    }

    struct NativeEntryHeading: View {
        let title: String
        let message: String
        var prominent = false

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "book.pages")
                    .font(.title2).symbolRenderingMode(.monochrome).accessibilityHidden(true)
                Text(title).font(prominent ? .largeTitle.bold() : .title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.body)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(
                NativeTrackTheme(code: "").gradient,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
#endif
