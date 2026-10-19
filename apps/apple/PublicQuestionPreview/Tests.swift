import Foundation

private enum PreviewTestFailure: Error { case assertion(String) }
@main
struct PublicQuestionPreviewTests {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("FAIL readonly preview: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        guard CommandLine.arguments.count == 2 else {
            throw PreviewTestFailure.assertion("Supply pinned fixture directory")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        func bytes(_ path: String) throws -> Data {
            try Data(contentsOf: root.appendingPathComponent(path))
        }
        func object(_ data: Data) throws -> [String: Any] {
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PreviewTestFailure.assertion("Expected object")
            }
            return value
        }
        var count = 0
        func check(_ success: Bool, _ name: String) throws {
            guard success else { throw PreviewTestFailure.assertion(name) }
            count += 1
            print("PASS \(name)")
        }
        let index = try object(bytes("index.json"))
        guard let payloads = index["payloads"] as? [[String: Any]],
            let entries = index["entries"] as? [[String: Any]]
        else { throw PreviewTestFailure.assertion("Missing manifest records") }
        try check(entries.count == 3 && payloads.count == 15, "bounded three-sample suite")
        for payload in payloads {
            guard let path = payload["path"] as? String,
                let size = payload["packageFileSize"] as? Int,
                let hash = payload["packageFileSha256"] as? String,
                let bodySize = payload["canonicalBodySize"] as? Int,
                let bodyHash = payload["canonicalBodySha256"] as? String
            else { throw PreviewTestFailure.assertion("Missing digest record") }
            let data = try bytes(path)
            try CanonicalQuestionReader.verifyFile(data, size: size, sha256: hash)
            try check(data.last == 10 && !data.contains(13), "\(path) exact package bytes and LF")
            try CanonicalQuestionReader.verifyFile(
                Data(data.dropLast()), size: bodySize, sha256: bodyHash)
            try check(true, "\(path) exact canonical body digest")
            let value = try object(data)
            if let type = value["resourceType"] as? String, let id = value["id"] as? String {
                try PublicResourceReader.validate(
                    data,
                    file: PublicPackageFile(
                        id: id, path: path, resourceType: type, hash: hash, size: size))
                try check(true, "\(path) existing public resource reader")
            }
        }
        for entry in entries {
            guard let directory = entry["directory"] as? String,
                let questionID = entry["questionId"] as? String,
                let conceptID = entry["conceptId"] as? String,
                let certificationID = entry["certificationId"] as? String,
                let optionIDs = entry["optionIds"] as? [String]
            else { throw PreviewTestFailure.assertion("Missing sample identity") }
            let question = try bytes("\(directory)/question.json")
            let compiled = try bytes("\(directory)/compiled-check.json")
            let preview = try PublicQuestionPreview.decode(
                question: question, compiledCheck: compiled)
            try check(
                preview.questionID == questionID && preview.conceptID == conceptID
                    && preview.certificationID == certificationID
                    && preview.options.map(\.id) == optionIDs,
                "\(directory) source IDs preserved, never derived")
            let source = try CanonicalQuestionReader.decode(question)
            try check(
                Data(preview.prompt.utf8) == Data(source.prompt.utf8),
                "\(directory) exact full prompt")
            if directory == "aws-aip-c01" {
                try check(preview.prompt.count > 1_000, "long AWS stem is not truncated")
                try check(
                    preview.options.allSatisfy { $0.label.count > 150 },
                    "long AWS choices are not truncated")
            }
            if directory == "microsoft-az-104" {
                try check(preview.prompt.contains("é"), "French diacritics remain intact")
            }
            let compiledObject = try object(compiled)
            func reject(
                _ mutated: [String: Any], _ name: String, expected: PublicQuestionPreviewError
            ) throws {
                do {
                    _ = try PublicQuestionPreview.decode(
                        question: question,
                        compiledCheck: JSONSerialization.data(withJSONObject: mutated))
                    throw PreviewTestFailure.assertion("Accepted \(name)")
                } catch let error as PublicQuestionPreviewError {
                    try check(error == expected, "\(directory) rejects \(name)")
                }
            }
            var changed = compiledObject
            changed["type"] = "multi"
            try reject(changed, "unsupported capability", expected: .unsupportedProjection("multi"))
            for key in ["correct", "explanation", "unknown"] {
                changed = compiledObject
                changed[key] = "not public"
                try reject(changed, "\(key) property", expected: .malformedProjection)
            }
            changed = compiledObject
            changed["id"] = "invented-client-id"
            try reject(changed, "mismatched question ID", expected: .sourceMismatch)
            changed = compiledObject
            changed["stem"] = String(preview.prompt.prefix(50))
            try reject(changed, "truncated prompt", expected: .sourceMismatch)
            changed = compiledObject
            changed.removeValue(forKey: "conceptId")
            try reject(changed, "missing required concept", expected: .malformedProjection)
            guard var options = compiledObject["options"] as? [[String: Any]] else {
                throw PreviewTestFailure.assertion("Missing options")
            }
            let originalOptions = options
            options[1]["id"] = options[0]["id"]
            changed = compiledObject
            changed["options"] = options
            try reject(changed, "duplicate option IDs", expected: .malformedProjection)
            options = originalOptions
            options[0]["label"] = "changed label"
            changed["options"] = options
            try reject(changed, "changed choice text", expected: .sourceMismatch)
            options = originalOptions
            options[0]["correct"] = true
            changed["options"] = options
            try reject(changed, "nested private option field", expected: .malformedProjection)
            var malformedRejected = false
            do {
                _ = try PublicQuestionPreview.decode(
                    question: question, compiledCheck: Data("not JSON".utf8))
            } catch {
                malformedRejected = true
            }
            try check(malformedRejected, "\(directory) rejects malformed JSON")
            var invalidSource = try object(question)
            invalidSource["schemaVersion"] = "v99"
            do {
                _ = try PublicQuestionPreview.decode(
                    question: JSONSerialization.data(withJSONObject: invalidSource),
                    compiledCheck: compiled)
                throw PreviewTestFailure.assertion("Accepted unknown canonical schema")
            } catch CanonicalContentError.unsupportedSchema("v99") {
                try check(true, "\(directory) reuses strict canonical schema rejection")
            }
        }
        print(
            "\(count) readonly source checks passed. No SwiftUI, auth, API, grade or overflow validation."
        )
    }
}
