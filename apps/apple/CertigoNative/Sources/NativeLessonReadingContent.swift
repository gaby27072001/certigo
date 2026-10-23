import Foundation

struct NativeLessonReadingContent: Equatable {
    enum Part: Equatable {
        case title(String)
        case text(String)
        case markdown(String)
    }

    let parts: [Part]

    init(lessonTitle: String, blocks: [(type: String, title: String?, body: String?)]) {
        let readableTypes: Set<String> = ["hook", "concept", "example", "recap"]
        var parts: [Part] = [.title(lessonTitle)]
        for block in blocks where readableTypes.contains(block.type) {
            if let title = block.title { parts.append(.title(title)) }
            if let body = block.body { parts.append(.markdown(body)) }
        }
        self.parts = parts
    }

    init(
        editorialTitle: String,
        objective: String,
        hook: String,
        keyIdeas: [String],
        exampleSituation: String,
        exampleSteps: [String],
        exampleDecision: String,
        recap: String
    ) {
        var parts: [Part] = [
            .title(editorialTitle),
            .text(objective),
            .text(hook),
            .title("Idées clés"),
        ]
        parts.append(contentsOf: keyIdeas.map(Part.text))
        parts.append(.title("Exemple résolu"))
        parts.append(.text(exampleSituation))
        parts.append(
            contentsOf: exampleSteps.enumerated().map {
                .text("\($0.offset + 1). \($0.element)")
            })
        parts.append(.text(exampleDecision))
        parts.append(.title("À retenir"))
        parts.append(.text(recap))
        self.parts = parts
    }

    func spokenText(renderingMarkdown: (String) throws -> String) throws -> String {
        try parts.map { part in
            let text: String
            switch part {
            case .title(let title): text = title
            case .text(let value): text = value
            case .markdown(let body): text = try renderingMarkdown(body)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    #if canImport(Darwin)
        static func plainText(_ markdown: String) throws -> String {
            // Match Text's inline Markdown while preserving paragraph whitespace.
            let value = try AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .throwError))
            return String(value.characters)
        }
    #endif
}
