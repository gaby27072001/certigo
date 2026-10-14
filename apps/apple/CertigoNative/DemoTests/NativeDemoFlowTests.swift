import Foundation

private enum DemoTestFailure: Error {
    case assertion(String)
}
@main
struct NativeDemoFlowTests {
    static func main() throws {
        var count = 0
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw DemoTestFailure.assertion(name) }
            count += 1
            print("PASS \(name)")
        }
        var flow = NativeDemoFlow()
        flow.select(1)
        flow.submit()
        try check(
            flow.objective == nil && flow.selection == nil && flow.phase == .answering,
            "no objective cannot select or submit")
        flow.choose(.fundamentals)
        flow.submit()
        try check(!flow.canSubmit && flow.phase == .answering, "unselected answer cannot submit")
        flow.select(-1)
        flow.select(3)
        try check(flow.selection == nil, "out-of-range options never enter state")
        flow.select(0)
        flow.select(1)
        try check(flow.selection == 1 && flow.canSubmit, "answer can change before submission")
        flow.submit()
        try check(
            flow.phase == .pending && !flow.canSubmit, "submission only creates pending state")
        flow.select(2)
        flow.submit()
        try check(flow.selection == 1 && flow.phase == .pending, "pending answer is immutable")
        flow.receiveMockExplanation(offline: true)
        try check(flow.phase == .pending, "offline simulation never creates correction")
        let pending = try NativeDemoFlow.restore(JSONEncoder().encode(flow))
        try check(pending == flow, "pending selection and objective survive restart")
        flow.choose(.fundamentals)
        try check(flow == pending, "choosing current objective preserves pending work")
        flow.receiveMockExplanation(offline: false)
        try check(
            flow.phase == .reviewed && flow.selection == 1,
            "explicit mock action displays explanation")
        try check(
            try NativeDemoFlow.restore(JSONEncoder().encode(flow)) == flow,
            "reviewed explanation survives restart")
        flow.restartQuestion()
        try check(
            flow.objective == .fundamentals && flow.selection == nil && flow.phase == .answering,
            "restart clears answer without changing objective")
        flow.select(2)
        flow.choose(.operations)
        try check(
            flow.objective == .operations && flow.selection == nil && flow.phase == .answering,
            "changing objective clears unrelated answer")
        flow.receiveMockExplanation(offline: false)
        try check(flow.phase == .answering, "mock explanation cannot precede submission")
        let invalidSnapshots = [
            #"{"phase":"pending"}"#,
            #"{"objective":"Cloud · découverte","selection":99,"phase":"answering"}"#,
            #"{"selection":1,"phase":"answering"}"#,
            #"{"objective":"Cloud · découverte","phase":"reviewed"}"#,
            #"{"phase":"unknown"}"#,
            #"not json"#,
        ]
        for (index, snapshot) in invalidSnapshots.enumerated() {
            var rejected = false
            do {
                _ = try NativeDemoFlow.restore(Data(snapshot.utf8))
            } catch {
                rejected = true
            }
            try check(rejected, "invalid snapshot \(index) is rejected explicitly")
        }
        for index in NativeDemoFlow.options.indices {
            var answer = NativeDemoFlow()
            answer.choose(.fundamentals)
            answer.select(index)
            answer.submit()
            answer.receiveMockExplanation(offline: false)
            try check(
                answer.phase == .reviewed && answer.selection == index,
                "option \(index) never triggers a local grade")
        }
        print("\(count) demo-only Foundation checks passed; no Apple UI was compiled or rendered.")
    }
}
