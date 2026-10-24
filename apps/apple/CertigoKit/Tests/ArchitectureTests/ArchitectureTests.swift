import Foundation
import Testing

private struct ArchitectureRule {
    let id: String
    let pattern: String
    let suggestion: String

    static let all: [Self] = [
        .init(
            id: "color",
            pattern: #"Color\s*\(\s*(?:red:|hue:|#)|UIColor\s*\(\s*red:|\.init\s*\(\s*red:|\.(?:blue|indigo|purple|orange|red|green|yellow|pink|cyan|mint|teal|brown)\b"#,
            suggestion: "Use PrismColor or PrismRegion."),
        .init(
            id: "type",
            pattern: #"\.font\s*\(\s*\.system\s*\(\s*size:|Font\.custom\s*\(|\.fontWeight\s*\("#,
            suggestion: "Use prismTextStyle."),
        .init(
            id: "layout",
            pattern: #"\.padding\s*\(\s*(?:\.[A-Za-z]+\s*,\s*)?[0-9]|\.frame\s*\([^)\n]*\b(?:width|height):\s*[0-9]|cornerRadius\s*\(\s*[0-9]|RoundedRectangle\s*\(\s*cornerRadius:\s*[0-9]"#,
            suggestion: "Use PrismSpacing, PrismSize or PrismRadius."),
        .init(
            id: "motion",
            pattern: #"withAnimation\s*\(\s*\.(?:easeIn|easeOut|easeInOut|linear)\s*\(\s*duration:\s*[0-9]|\.spring\s*\(\s*response:\s*[0-9]"#,
            suggestion: "Use PrismMotion.resolve with Reduce Motion."),
        .init(
            id: "haptic", pattern: #"UIImpactFeedbackGenerator\s*\("#,
            suggestion: "Use PrismHapticToken."),
        .init(
            id: "literal", pattern: #"\bText\s*\(\s*"[^"]*[A-Za-z][^"]*"\s*\)"#,
            suggestion: "Use localized interface copy (content exceptions remain in the baseline)."),
        .init(
            id: "print", pattern: #"\bprint\s*\("#,
            suggestion: "Use repository-standard logging."),
        .init(
            id: "brand-image", pattern: #"Image\s*\([^)\n]*Brand(?:Assets|Registry)"#,
            suggestion: "Use BrandIcon."),
        .init(
            id: "brand-modifier",
            pattern: #"Brand(?:Icon|Label)\s*\([^)]*\)(?:\s*\.[A-Za-z0-9_]+\s*\([^)]*\))*\s*\.(?:renderingMode|foregroundStyle|tint|colorMultiply|hueRotation|saturation|grayscale|colorInvert|blendMode|mask|clipShape|rotationEffect|rotation3DEffect|scaleEffect|blur|shadow|glassEffect)\s*\("#,
            suggestion: "Do not alter official brand assets."),
    ]
}

private struct Violation {
    let path: String
    let line: Int
    let rule: ArchitectureRule
    let excerpt: String

    var key: String { "\(path)|\(rule.id)|\(excerpt)" }
    var report: String { "\(path):\(line): [\(rule.id)] \(rule.suggestion) \(excerpt)" }
}

private func violations(in source: String, path: String) throws -> [Violation] {
    let whole = NSRange(source.startIndex..., in: source)
    let comments = try NSRegularExpression(pattern: #"/\*[\s\S]*?\*/|(?m)^\s*//[^\n]*"#)
    var scrubbed = source
    for match in comments.matches(in: source, range: whole).reversed() {
        guard let range = Range(match.range, in: scrubbed) else { continue }
        scrubbed.replaceSubrange(
            range, with: scrubbed[range].map { $0 == "\n" ? "\n" : " " })
    }
    var result: [Violation] = []
    for rule in ArchitectureRule.all {
        let regex = try NSRegularExpression(pattern: rule.pattern)
        for match in regex.matches(in: scrubbed, range: NSRange(scrubbed.startIndex..., in: scrubbed)) {
            guard let range = Range(match.range, in: scrubbed) else { continue }
            let line = scrubbed[..<range.lowerBound].filter { $0 == "\n" }.count + 1
            let excerpt = String(source.split(separator: "\n", omittingEmptySubsequences: false)[line - 1])
                .trimmingCharacters(in: .whitespaces)
            result.append(.init(path: path, line: line, rule: rule, excerpt: excerpt))
        }
    }
    return result
}

@Suite struct ArchitectureTests {
    @Test func scannerRejectsEveryProhibitedFamilyWithActionableLocations() throws {
        let examples = [
            "Color(red: 1, green: 0, blue: 0)", ".foregroundStyle(.indigo)",
            ".font(.system(size: 12))", ".fontWeight(.bold)",
            ".padding(.horizontal, 12)", ".frame(width: 20)", ".frame(height: 20)",
            "RoundedRectangle(cornerRadius: 9)", "cornerRadius(9)",
            "withAnimation(.easeIn(duration: 1)) {}", ".spring(response: 0.4)",
            "UIImpactFeedbackGenerator()", #"Text("Not localized")"#, "print(value)",
            #"Image("thing", bundle: BrandAssets.bundle)"#,
            "BrandIcon(product: .azure, context: .diagram).tint(.primary)",
            "BrandLabel(product: .azure)\n    .shadow(radius: 2)",
        ]
        for example in examples {
            let result = try violations(in: example, path: "Example.swift")
            #expect(!result.isEmpty, "\(example)")
            #expect(result.allSatisfy { $0.report.hasPrefix("Example.swift:1:") })
        }
        #expect(try violations(in: "// print(value)\n/* Color(red: 1) */", path: "Comments.swift").isEmpty)
        #expect(try violations(
            in: "Text(copy.title).padding(PrismSpacing.l).prismTextStyle(.body)",
            path: "Good.swift").isEmpty)
    }

    @Test func migratedSourcesHaveNoViolationsAndLegacyDebtCannotGrow() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let apple = root.appendingPathComponent("apps/apple")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: apple, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))
        var found: [Violation] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            guard relative.contains("/Sources/") else { continue }
            let source = try String(contentsOf: file, encoding: .utf8)
            found += try violations(in: source, path: relative).filter {
                // RGBA channel arithmetic defines the palette; other Prism files remain audited.
                !($0.path == "apps/apple/CertigoKit/Sources/Prism/PrismColors.swift"
                    && $0.rule.id == "color")
                && !($0.path == "apps/apple/CertigoKit/Sources/Prism/Brand/BrandIcon.swift"
                    && $0.rule.id == "brand-image")
            }
            if relative.contains("/Sources/CertigoDomain/")
                || relative.contains("/Sources/CertigoCortex/")
            {
                #expect(!source.contains("import SwiftUI"), "\(relative): domain imports SwiftUI")
                #expect(!source.contains("import UIKit"), "\(relative): domain imports UIKit")
            }
        }
        let counts = Dictionary(grouping: found, by: \.key).mapValues(\.count)
        let baselineURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("LegacyExceptions.json")
        if ProcessInfo.processInfo.environment["CERTIGO_RECORD_ARCHITECTURE_BASELINE"] == "1" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(counts).write(to: baselineURL)
            return
        }
        let resource = try #require(Bundle.module.url(forResource: "LegacyExceptions", withExtension: "json"))
        let baseline = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: resource))
        for (key, count) in counts where count > (baseline[key] ?? 0) {
            let reports = found.filter { $0.key == key }.map(\.report).joined(separator: "\n")
            Issue.record("New architecture violations (baseline \(baseline[key] ?? 0), actual \(count)):\n\(reports)")
        }
        // Removing a legacy violation also removes its exception; stale suppressions cannot accumulate.
        #expect(Set(baseline.keys).subtracting(counts.keys).isEmpty, "Remove resolved legacy exceptions.")
        for (key, count) in counts where count < (baseline[key] ?? 0) {
            Issue.record("Reduce the resolved exception count for \(key) to \(count).")
        }
    }
}
