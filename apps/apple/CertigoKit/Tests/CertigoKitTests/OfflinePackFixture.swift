import CertigoData
import Foundation

struct OfflinePackFixture {
    let manifest: Data
    let files: [String: Data]
    let releaseId = "sha256:" + String(repeating: "a", count: 64)

    init(
        resources: URL, revision: Int = 0, legacyChoices: Bool = false, guided: Bool = false
    ) throws {
        let bytes = try Data(
            contentsOf: resources.appendingPathComponent("offline/question-pack.json"))
        guard var objects = try JSONSerialization.jsonObject(with: bytes) as? [[String: Any]],
            var question = try JSONSerialization.jsonObject(
                with: Data(
                    contentsOf:
                        resources.appendingPathComponent(
                            "apple-compat/v1/supported/question-v4-mcq.json")))
                as? [String: Any]
        else { throw PublicReleaseError.malformed }
        if revision != 0 { question["prompt"] = "Synthetic revision \(revision)" }
        if legacyChoices {
            question["schemaVersion"] = "v3"
            for key in ["legacyId", "itemType", "difficulty", "options"] {
                question.removeValue(forKey: key)
            }
            question["choices"] = ["IaaS", "PaaS", "SaaS", "On-premises"]
            guard var metadata = question["metadata"] as? [String: Any] else {
                throw PublicReleaseError.malformed
            }
            metadata.removeValue(forKey: "domainId")
            metadata.removeValue(forKey: "conceptId")
            question["metadata"] = metadata
            for index in objects.indices {
                for key in ["id", "domainId"] {
                    if let value = objects[index][key] as? String {
                        objects[index][key] =
                            value
                            .replacingOccurrences(
                                of: ".domain.cloud-concepts", with: ".domain.section-1"
                            )
                            .replacingOccurrences(
                                of: ".concept.cloud-service-models", with: ".concept.cloud-models")
                    }
                }
                if let domains = objects[index]["domainIds"] as? [String] {
                    objects[index]["domainIds"] = domains.map {
                        $0.replacingOccurrences(
                            of: ".domain.cloud-concepts", with: ".domain.section-1")
                    }
                }
            }
        }
        if guided {
            let unitID = "microsoft.az-900.unit.intro"
            let lessonID = "microsoft.az-900.lesson.intro"
            let conceptID = "microsoft.az-900.concept.cloud-service-models"
            objects[0]["mode"] = "guided"
            objects[0]["unitIds"] = [unitID]
            var unit: [String: Any] = [
                "schema": "certigo.runtime.unit/v1", "resourceType": "unit", "id": unitID,
                "certificationId": "microsoft:az-900", "blueprintVersion": "2026-08-17",
                "lifecycle": ["status": "active"],
                "domainId": "microsoft.az-900.domain.cloud-concepts",
                "title": "Synthetic unit", "lessonIds": [lessonID],
            ]
            objects.append(unit)
            unit["schema"] = "certigo.runtime.lesson/v1"
            unit["resourceType"] = "lesson"
            unit["id"] = lessonID
            unit["legacyId"] = "synthetic-guided-lesson"
            unit["title"] = "Synthetic authored fixture only"
            unit["unitId"] = unitID
            unit["estimatedMinutes"] = 2
            unit.removeValue(forKey: "domainId")
            unit.removeValue(forKey: "lessonIds")
            unit["blocks"] = [
                [
                    "id": "\(lessonID).block.001", "type": "hook", "conceptId": conceptID,
                    "body": "Synthetic public teaching text.",
                ],
                [
                    "id": "\(lessonID).block.002", "type": "check", "conceptId": conceptID,
                    "questionId": "microsoft.az-900.section-1.cloud-models.001",
                ],
            ]
            objects.append(unit)
        }
        objects.append(question)
        var files: [String: Data] = [:]
        var entries: [[String: Any]] = []
        for object in objects {
            let type =
                object["resourceType"] as? String
                ?? (object["schema"] == nil ? "question" : "certificationCatalog")
            let id = object["id"] as? String ?? "certification-catalog"
            let path =
                type == "certificationCatalog"
                ? "catalog/certifications.json"
                : type == "question" ? "questions/synthetic.json" : "runtime/\(type)s/\(id).json"
            var encoded = try JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
            encoded.append(0x0A)
            files[path] = encoded
            let digest = try CanonicalQuestionReader.digest(encoded)
            entries.append([
                "id": id, "resourceType": type, "path": path,
                "hash": digest.sha256, "size": digest.size,
            ])
        }
        var body: [String: Any] = [
            "schema": "certigo.content.package-manifest/v3", "channel": "public",
            "artifact": "public", "algorithm": "sha256",
            "serialization": "json-sorted-keys-compact-utf8-lf",
            "files": entries, "fileCount": entries.count,
        ]
        let digest = try CanonicalQuestionReader.digest(
            JSONSerialization.data(
                withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        ).sha256
        body["manifestId"] = "sha256:\(digest)"
        body["rootHash"] = digest
        body["releaseId"] = releaseId
        manifest = try JSONSerialization.data(
            withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        self.files = files
    }
}
