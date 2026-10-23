import Foundation
import XCTest

@testable import CertigoDomain

final class EditorialPilotLessonLinkTests: XCTestCase {
    func testAcceptsOnlyStableEditorialPilotLessonPaths() throws {
        for lessonID in EditorialPilotLessonLink.lessonIDs {
            for suffix in ["", "/"] {
                let url = try XCTUnwrap(
                    URL(
                        string:
                            "https://www.certigo-app.com/learn/responsible-ai-assistants/\(lessonID)\(suffix)"
                    ))
                let link = try XCTUnwrap(EditorialPilotLessonLink(url: url))

                XCTAssertEqual(link.pilotID, "responsible-ai-assistants")
                XCTAssertEqual(link.lessonID, lessonID)
                XCTAssertEqual(link.canonicalPath, "/learn/responsible-ai-assistants/\(lessonID)/")
            }
        }
    }

    func testRejectsOtherHostsSchemesAndURLComponents() {
        let rejectedURLs = [
            "http://www.certigo-app.com/learn/responsible-ai-assistants/verify-claims/",
            "https://certigo-app.com/learn/responsible-ai-assistants/verify-claims/",
            "https://www.certigo-app.com.example.test/learn/responsible-ai-assistants/verify-claims/",
            "https://www.certigo-app.com:443/learn/responsible-ai-assistants/verify-claims/",
            "https://user@www.certigo-app.com/learn/responsible-ai-assistants/verify-claims/",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/verify-claims/?token=secret",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/verify-claims/#fragment",
            "https://www.certigo-app.com/learn/other-pilot/verify-claims/",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/unknown-lesson/",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/verify-claims//",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/%76erify-claims/",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/verify%2Fclaims/",
            "https://www.certigo-app.com/learn/responsible-ai-assistants/../verify-claims/",
        ]

        for value in rejectedURLs {
            guard let url = URL(string: value) else { continue }
            XCTAssertNil(EditorialPilotLessonLink(url: url), value)
        }
    }
}
