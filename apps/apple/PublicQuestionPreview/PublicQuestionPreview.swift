import Foundation

/// Read-only compiler fixture, not an HTTP lesson DTO or an authenticated exercise.
enum PublicQuestionPreviewError: Error, Equatable {
    case malformedProjection
    case unsupportedProjection(String)
    case sourceMismatch
}
struct PublicQuestionPreview: Equatable {
    struct Option: Equatable {
        let id: String
        let label: String
    }
    let questionID: String
    let conceptID: String
    let certificationID: String
    let prompt: String
    let options: [Option]

    static func decode(question: Data, compiledCheck: Data) throws -> Self {
        let source = try CanonicalQuestionReader.decode(question)
        try source.requireBasicCapability()
        guard compiledCheck.count <= CanonicalQuestionReader.maximumPayloadBytes else {
            throw CanonicalContentError.payloadTooLarge
        }
        guard let root = try JSONSerialization.jsonObject(with: compiledCheck) as? [String: Any],
            Set(root.keys) == ["id", "conceptId", "type", "stem", "options"],
            let type = root["type"] as? String
        else { throw PublicQuestionPreviewError.malformedProjection }
        guard type == "mcq" else {
            throw PublicQuestionPreviewError.unsupportedProjection(type)
        }
        guard let id = root["id"] as? String,
            let concept = root["conceptId"] as? String, !concept.isEmpty,
            let stem = root["stem"] as? String, !stem.isEmpty,
            let rawOptions = root["options"] as? [[String: Any]],
            (2...8).contains(rawOptions.count)
        else { throw PublicQuestionPreviewError.malformedProjection }
        let options = try rawOptions.map { value -> Option in
            guard Set(value.keys) == ["id", "label"],
                let id = value["id"] as? String, !id.isEmpty,
                let label = value["label"] as? String, !label.isEmpty
            else { throw PublicQuestionPreviewError.malformedProjection }
            return Option(id: id, label: label)
        }
        guard Set(options.map(\.id)).count == options.count else {
            throw PublicQuestionPreviewError.malformedProjection
        }
        let labels = options.map { Data($0.label.utf8) }
        let sourceLabels: [Data]
        switch source.options {
        case .legacyChoices(let choices): sourceLabels = choices.map { Data($0.utf8) }
        case .identified(let identified):
            sourceLabels = identified.map { Data($0.label.utf8) }
            guard identified.map(\.id) == options.map(\.id) else {
                throw PublicQuestionPreviewError.sourceMismatch
            }
        }
        guard Data(id.utf8) == Data(source.id.utf8),
            Data(stem.utf8) == Data(source.prompt.utf8),
            labels == sourceLabels,
            source.metadata.conceptId.map({ Data($0.utf8) == Data(concept.utf8) }) ?? true
        else { throw PublicQuestionPreviewError.sourceMismatch }
        return Self(
            questionID: id, conceptID: concept, certificationID: source.metadata.certification,
            prompt: stem, options: options)
    }
}
