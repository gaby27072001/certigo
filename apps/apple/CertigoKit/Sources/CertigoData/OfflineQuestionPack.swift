import CertigoDomain
import Foundation

public struct OfflineQuestionPack: Sendable {
    public let trackId: String
    public let manifestId: String
    public let lessons: [Lesson]
}
enum OfflineQuestionPackReader {
    static func read(
        trackId: String, snapshot: RuntimeContentSnapshot,
        file: (PublicPackageFile) throws -> Data
    ) throws -> OfflineQuestionPack? {
        func resource(_ type: String, _ id: String) throws -> [String: Any] {
            guard
                let entry = snapshot.manifest.files.first(where: {
                    $0.resourceType == type && $0.id == id
                })
            else { throw RuntimeStoreError.missingFile }
            return try PublicReleaseContracts.json(file(entry))
        }
        func text(_ object: [String: Any], _ key: String) throws -> String {
            try PublicReleaseContracts.text(object, key)
        }
        func ids(_ object: [String: Any], _ key: String) throws -> [String] {
            guard let values = object[key] as? [String] else {
                throw PublicReleaseError.malformed
            }
            return values
        }
        func runtimeId(_ object: [String: Any]) throws -> String {
            try object["legacyId"] as? String ?? text(object, "id")
        }
        func question(_ entry: PublicPackageFile) throws -> (CanonicalPublicQuestion, String) {
            let value = try CanonicalQuestionReader.decode(file(entry))
            let certification = value.metadata.certification.replacingOccurrences(
                of: ":", with: ".")
            return (
                value,
                value.metadata.domainId ?? "\(certification).domain.\(value.metadata.objective)"
            )
        }
        func conceptId(_ value: CanonicalPublicQuestion) -> String {
            value.metadata.conceptId
                ?? "\(value.metadata.certification.replacingOccurrences(of: ":", with: ".")).concept.\(value.id.split(separator: ".")[3])"
        }
        func check(_ value: CanonicalPublicQuestion) throws -> [String: Any] {
            try value.requireBasicCapability()
            let canonicalConcept = conceptId(value)
            let concept = try resource("concept", canonicalConcept)
            guard try text(concept, "certificationId") == value.metadata.certification,
                try text(concept, "blueprintVersion") == value.metadata.blueprintVersion,
                try text(concept, "domainId")
                    == (value.metadata.domainId
                        ?? "\(value.metadata.certification.replacingOccurrences(of: ":", with: ".")).domain.\(value.metadata.objective)")
            else { throw PublicReleaseError.provenance }
            let options: [[String: String]]
            switch value.options {
            case .identified(let values):
                options = values.map { ["id": $0.id, "label": $0.label] }
            case .legacyChoices(let choices):
                options = try choices.map { ["id": try optionId($0), "label": $0] }
            }
            return [
                "id": value.legacyId ?? value.id, "conceptId": try runtimeId(concept),
                "type": value.itemType, "stem": value.prompt, "options": options,
            ]
        }
        func lesson(_ id: String, _ title: String, _ blocks: [[String: Any]]) throws -> Lesson {
            let bytes = try JSONSerialization.data(withJSONObject: [
                "id": id, "trackId": trackId, "title": title, "blocks": blocks,
                "publicManifestId": snapshot.manifest.manifestId,
            ])
            return try JSONDecoder().decode(Lesson.self, from: bytes)
                .validated(trackId: trackId, lessonId: id)
        }
        let tracks = snapshot.manifest.files.filter { $0.resourceType == "track" }
        var selected: [String: Any]?
        for entry in tracks {
            let value = try PublicReleaseContracts.json(file(entry))
            if try runtimeId(value) == trackId {
                guard selected == nil else { throw PublicReleaseError.provenance }
                selected = value
            }
        }
        guard let track = selected else { return nil }
        let certification = try text(track, "certificationId")
        let blueprint = try text(track, "blueprintVersion")
        var lessons: [Lesson] = []
        if try text(track, "mode") == "questionBank" {
            let catalog = try resource("certificationCatalog", "certification-catalog")
            guard let certifications = catalog["certifications"] as? [[String: Any]],
                let definition = certifications.first(where: {
                    $0["id"] as? String == certification
                }),
                let definitionBlueprint = definition["blueprint"] as? [String: Any],
                definitionBlueprint["version"] as? String == blueprint,
                let objectives = definitionBlueprint["objectives"] as? [[String: Any]]
            else { throw PublicReleaseError.provenance }
            let questions = try snapshot.manifest.files.filter { $0.resourceType == "question" }
                .map(question)
            for domainId in try ids(track, "domainIds") {
                let domain = try resource("domain", domainId)
                guard try text(domain, "certificationId") == certification,
                    try text(domain, "blueprintVersion") == blueprint
                else { throw PublicReleaseError.provenance }
                let objective = try text(domain, "objectiveId")
                guard let definition = objectives.first(where: { $0["id"] as? String == objective })
                else { throw PublicReleaseError.provenance }
                let values = questions.filter {
                    $0.0.metadata.certification == certification && $0.1 == domainId
                }.sorted { $0.0.id < $1.0.id }
                let blocks = try values.map { value -> [String: Any] in
                    guard value.0.metadata.blueprintVersion == blueprint else {
                        throw PublicReleaseError.provenance
                    }
                    return ["type": "check", "check": try check(value.0)]
                }
                lessons.append(
                    try lesson(
                        "\(trackId).lesson.\(objective).practice",
                        "\(try text(definition, "title")) practice", blocks))
            }
        } else {
            for unitId in try ids(track, "unitIds") {
                let unit = try resource("unit", unitId)
                guard try text(unit, "certificationId") == certification,
                    try text(unit, "blueprintVersion") == blueprint,
                    try ids(track, "domainIds").contains(text(unit, "domainId"))
                else { throw PublicReleaseError.provenance }
                for lessonId in try ids(unit, "lessonIds") {
                    let value = try resource("lesson", lessonId)
                    guard try text(value, "certificationId") == certification,
                        try text(value, "blueprintVersion") == blueprint,
                        try text(value, "unitId") == unitId,
                        let rawBlocks = value["blocks"] as? [[String: Any]]
                    else { throw PublicReleaseError.provenance }
                    let blocks = try rawBlocks.map { block -> [String: Any] in
                        let concept = try resource("concept", text(block, "conceptId"))
                        guard try text(concept, "certificationId") == certification,
                            try text(concept, "blueprintVersion") == blueprint,
                            try text(concept, "domainId") == text(unit, "domainId")
                        else { throw PublicReleaseError.provenance }
                        var projected: [String: Any] = ["type": try text(block, "type")]
                        for key in ["title", "body", "code"] { projected[key] = block[key] }
                        if block["type"] as? String == "check" {
                            let id = try text(block, "questionId")
                            guard
                                let entry = snapshot.manifest.files.first(where: {
                                    $0.resourceType == "question" && $0.id == id
                                })
                            else { throw RuntimeStoreError.missingFile }
                            let value = try question(entry).0
                            guard value.metadata.certification == certification,
                                value.metadata.blueprintVersion == blueprint,
                                conceptId(value) == (block["conceptId"] as? String)
                            else { throw PublicReleaseError.provenance }
                            projected["check"] = try check(value)
                        }
                        return projected
                    }
                    lessons.append(
                        try lesson(
                            runtimeId(value), text(value, "title"), blocks))
                }
            }
        }
        guard !lessons.isEmpty, Set(lessons.map(\.id)).count == lessons.count else {
            throw PublicReleaseError.provenance
        }
        return OfflineQuestionPack(
            trackId: trackId, manifestId: snapshot.manifest.manifestId, lessons: lessons)
    }

    // Matches ContentContractVerifier.OptionId for legacy v3 public choices, not answer keys.
    private static func optionId(_ label: String) throws -> String {
        var slug = ""
        var separator = false
        for scalar in label.decomposedStringWithCanonicalMapping.lowercased().unicodeScalars {
            if scalar.properties.generalCategory == .nonspacingMark { continue }
            if (97...122).contains(scalar.value) || (48...57).contains(scalar.value) {
                if separator && !slug.isEmpty { slug.append("-") }
                slug.unicodeScalars.append(scalar)
                separator = false
            } else {
                separator = !slug.isEmpty
            }
        }
        slug = String(slug.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let prefix = slug.isEmpty ? "option" : String(slug.prefix(39))
        let hash = try CanonicalQuestionReader.digest(Data(label.utf8)).sha256.prefix(8)
        return "\(prefix)-\(hash)"
    }
}
