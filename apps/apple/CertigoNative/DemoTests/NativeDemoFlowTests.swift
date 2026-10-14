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
        var navigationFlow = NativeDemoFlow()
        navigationFlow.choose(.fundamentals)
        navigationFlow.select(1)
        navigationFlow.submit()
        let exerciseNavigation = try NativeDemoNavigationState.make(
            selectedTab: .objective,
            objectivePath: [.exercise],
            catalogPath: [],
            flow: navigationFlow)
        let restoredNavigation = try NativeDemoNavigationState.restore(
            JSONEncoder().encode(exerciseNavigation), for: navigationFlow)
        try check(
            restoredNavigation == exerciseNavigation && navigationFlow.phase == .pending,
            "resume restores the objective tab, exercise route, and pending demo state")
        let catalogNavigation = try NativeDemoNavigationState.make(
            selectedTab: .catalog,
            objectivePath: [],
            catalogPath: [.goalDetail(.operations)],
            flow: navigationFlow)
        try check(
            try NativeDemoNavigationState.restore(
                JSONEncoder().encode(catalogNavigation), for: navigationFlow) == catalogNavigation,
            "catalog detail route survives demo re-entry")
        var emptyFlow = NativeDemoFlow()
        let invalidNavigation = NativeDemoNavigationState(
            selectedTab: .objective,
            objectivePath: [.exercise],
            catalogPath: [])
        var rejectedRoute = false
        do {
            _ = try NativeDemoNavigationState.restore(
                JSONEncoder().encode(invalidNavigation), for: emptyFlow)
        } catch {
            rejectedRoute = true
        }
        try check(rejectedRoute, "exercise route without a selected objective is rejected")
        emptyFlow.choose(.operations)
        var rejectedWrongStack = false
        let wrongStack = NativeDemoNavigationState(
            selectedTab: .catalog,
            objectivePath: [.goalDetail(.operations)],
            catalogPath: [])
        do {
            _ = try NativeDemoNavigationState.restore(
                JSONEncoder().encode(wrongStack), for: emptyFlow)
        } catch {
            rejectedWrongStack = true
        }
        try check(rejectedWrongStack, "route stored under the wrong tab is rejected")
        let snapshot = try NativeDemoSnapshot.make(
            flow: navigationFlow, navigation: exerciseNavigation)
        try check(
            try NativeDemoSnapshot.restore(JSONEncoder().encode(snapshot)) == snapshot,
            "demo flow and route restore together from one snapshot")
        let legacySnapshot = try NativeDemoSnapshot.restore(JSONEncoder().encode(navigationFlow))
        try check(
            legacySnapshot.flow == navigationFlow
                && legacySnapshot.navigation.selectedTab == .objective
                && legacySnapshot.navigation.objectivePath.isEmpty,
            "existing flow-only demo storage remains resumable")
        var rejectedOversizedSnapshot = false
        do {
            _ = try NativeDemoSnapshot.restore(Data(repeating: 0, count: 8_193))
        } catch {
            rejectedOversizedSnapshot = true
        }
        try check(rejectedOversizedSnapshot, "oversized demo snapshots are rejected")
        print("\(count) demo-only Foundation checks passed; no Apple UI was compiled or rendered.")
    }
}
