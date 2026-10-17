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
        let untouchedFlow = NativeDemoFlow()
        try check(untouchedFlow.practice == nil, "empty objective never invents practice content")
        var workshop = NativeDemoFlow()
        workshop.choose(.fundamentals)
        try check(
            workshop.startRoute == .preparation
                && workshop.startLabel == "Explore the situation"
                && workshop.resumeLabel == "Start a question",
            "new objective leads to preparation before the question")
        let preparationNavigation = try NativeDemoNavigationState.make(
            selectedTab: .objective, objectivePath: [.preparation], catalogPath: [],
            flow: workshop)
        let preparationSnapshot = try NativeDemoSnapshot.make(
            flow: workshop, navigation: preparationNavigation)
        try check(
            try NativeDemoSnapshot.restore(JSONEncoder().encode(preparationSnapshot))
                == preparationSnapshot,
            "preparation route round trips without changing the storage schema")
        var rejectedPreparationWithoutGoal = false
        do {
            _ = try NativeDemoNavigationState.make(
                selectedTab: .objective, objectivePath: [.preparation], catalogPath: [],
                flow: untouchedFlow)
        } catch {
            rejectedPreparationWithoutGoal = true
        }
        try check(
            rejectedPreparationWithoutGoal, "preparation cannot open without an objective")
        for goal in NativeDemoFlow.Objective.allCases {
            workshop.choose(goal)
            let practice = goal.practice
            try check(
                workshop.practice?.title == practice.title
                    && !practice.situation.isEmpty && !practice.intent.isEmpty
                    && !practice.question.isEmpty && !practice.constraint.isEmpty
                    && !practice.explanation.isEmpty && !practice.takeaway.isEmpty
                    && practice.responsibilities.count == 3
                    && practice.responsibilities.allSatisfy {
                        !$0.layer.isEmpty && !$0.owner.isEmpty
                    },
                "\(goal) has a complete preparation, decision and explanation")
        }
        try check(
            NativeDemoFlow.Objective.fundamentals.practice.situation
                != NativeDemoFlow.Objective.operations.practice.situation
                && NativeDemoFlow.Objective.fundamentals.practice.explanation
                    != NativeDemoFlow.Objective.operations.practice.explanation,
            "objectives never reuse an unrelated question or explanation")
        workshop.select(0)
        try check(
            workshop.startRoute == .exercise,
            "an existing selection resumes the question instead of preparation")
        for phase in [NativeDemoFlow.Phase.answering, .pending, .reviewed] {
            if phase == .pending { workshop.submit() }
            if phase == .reviewed { workshop.receiveMockExplanation(offline: false) }
            let followUpNavigation = try NativeDemoNavigationState.make(
                selectedTab: .followUp, objectivePath: [],
                catalogPath: [.goalDetail(.fundamentals)],
                flow: workshop)
            let resumed = try followUpNavigation.resumingExercise(for: workshop)
            try check(
                resumed.selectedTab == .objective && resumed.objectivePath == [.exercise]
                    && resumed.catalogPath == followUpNavigation.catalogPath
                    && workshop.phase == phase && workshop.selection == 0,
                "follow-up opens the owning exercise stack and preserves \(phase)")
            let resumedSnapshot = try NativeDemoSnapshot.make(flow: workshop, navigation: resumed)
            try check(
                try NativeDemoSnapshot.restore(JSONEncoder().encode(resumedSnapshot))
                    == resumedSnapshot,
                "resumed \(phase) route persists with its exact demo state")
        }
        var rejectedEmptyResume = false
        do {
            _ = try NativeDemoNavigationState.make(
                selectedTab: .followUp, objectivePath: [], catalogPath: [], flow: untouchedFlow
            ).resumingExercise(for: untouchedFlow)
        } catch {
            rejectedEmptyResume = true
        }
        try check(rejectedEmptyResume, "follow-up cannot invent an exercise without an objective")
        try check(
            workshop.activitySummary.contains("no verdict"),
            "reviewed summary cannot present a grade or certification progress")
        for goal in NativeDemoFlow.Objective.allCases {
            for option in NativeDemoFlow.options.indices {
                var example = NativeDemoFlow()
                example.choose(goal)
                example.select(option)
                example.submit()
                example.receiveMockExplanation(offline: false)
                let restoredExample = try NativeDemoFlow.restore(JSONEncoder().encode(example))
                try check(
                    restoredExample.phase == .reviewed && restoredExample.selection == option
                        && restoredExample.practice?.title == goal.practice.title
                        && restoredExample.startRoute == .exercise,
                    "\(goal) option \(option) retains its context without local grading")
            }
        }
        try check(
            NativeDemoDestination.allCases.map(\.rawValue) == [
                "learn", "coach", "social", "profile",
            ],
            "four main destinations match the approved navigation")
        for (legacyTab, destination, section) in [
            (
                NativeDemoTab.objective, NativeDemoDestination.learn,
                NativeDemoLearnSection.myLearning
            ),
            (.catalog, .learn, .explore), (.followUp, .profile, .myLearning),
        ] {
            let legacyJSON = """
                {"schema":1,"flow":{"objective":"Cloud · découverte","selection":1,"phase":"pending"},
                 "navigation":{"selectedTab":"\(legacyTab.rawValue)","objectivePath":[{"exercise":{}}],
                 "catalogPath":[{"goalDetail":{"_0":"Cloud · exploitation"}}]}}
                """
            let migrated = try NativeDemoSnapshot.restore(Data(legacyJSON.utf8))
            try check(
                migrated.navigation.selectedTab.destination == destination
                    && migrated.navigation.learnSection == section
                    && migrated.flow.selection == 1 && migrated.flow.phase == .pending
                    && migrated.navigation.objectivePath == [.exercise]
                    && migrated.navigation.catalogPath == [.goalDetail(.operations)],
                "legacy \(legacyTab) migrates to \(destination) without dropping work")
        }
        for destination in NativeDemoDestination.allCases {
            for section in [NativeDemoLearnSection.myLearning, .explore] {
                let state = try NativeDemoNavigationState.make(
                    selectedTab: .selecting(destination, learnSection: section),
                    objectivePath: [.exercise], catalogPath: [.goalDetail(.operations)],
                    flow: workshop, learnSection: section)
                let snapshot = try NativeDemoSnapshot.make(flow: workshop, navigation: state)
                let restored = try NativeDemoSnapshot.restore(JSONEncoder().encode(snapshot))
                try check(
                    restored == snapshot
                        && restored.navigation.selectedTab.destination == destination
                        && restored.navigation.learnSection == section,
                    "\(destination) preserves the \(section) Learn section and both detail routes")
            }
        }
        let emptyLegacy = try NativeDemoSnapshot.restore(
            JSONEncoder().encode(NativeDemoFlow()))
        try check(
            emptyLegacy.navigation.selectedTab.destination == .learn
                && emptyLegacy.navigation.learnSection == .explore,
            "an empty legacy demo starts in Learn Explore")
        var rejectedConflictingSection = false
        do {
            _ = try NativeDemoNavigationState.make(
                selectedTab: .catalog, objectivePath: [], catalogPath: [], flow: workshop,
                learnSection: .myLearning)
        } catch { rejectedConflictingSection = true }
        try check(rejectedConflictingSection, "a conflicting Learn tab and section is rejected")
        try check(
            NativeDemoFlow.Objective.fundamentals.rawValue == "Cloud · découverte"
                && NativeDemoFlow.Objective.operations.rawValue == "Cloud · exploitation"
                && NativeDemoFlow.Objective.fundamentals.displayName == "Cloud · discovery",
            "English interface labels do not rewrite persisted goal identifiers")
        let browsingGoal = NativeActiveGoalPresentation(
            targetID: "new-goal", confirmedID: "old-goal", savingID: nil, busy: false)
        try check(
            browsingGoal.canChoose && !browsingGoal.isConfirmed
                && browsingGoal.status == "Viewing a goal · not selected",
            "browsing another goal never presents it as confirmed")
        let savingGoal = NativeActiveGoalPresentation(
            targetID: "new-goal", confirmedID: "old-goal", savingID: "new-goal", busy: true)
        try check(
            !savingGoal.canChoose && !savingGoal.isConfirmed
                && savingGoal.symbol == "clock"
                && savingGoal.status.contains("waiting for the server"),
            "saving blocks duplicate action without optimistic goal confirmation")
        let confirmedGoal = NativeActiveGoalPresentation(
            targetID: "new-goal", confirmedID: "new-goal", savingID: nil, busy: false)
        try check(
            confirmedGoal.isConfirmed && !confirmedGoal.canChoose
                && confirmedGoal.symbol == "checkmark.circle",
            "only the authoritative profile enables confirmed-goal presentation")
        let normalizedGoal = NativeActiveGoalPresentation(
            targetID: "New-Goal", confirmedID: "new-goal", savingID: nil, busy: false)
        try check(
            normalizedGoal.isConfirmed && !normalizedGoal.canChoose,
            "confirmed-goal comparison follows the transport's case-insensitive target contract")
        let failedGoal = NativeActiveGoalPresentation(
            targetID: "new-goal", confirmedID: "old-goal", savingID: nil, busy: false)
        try check(
            failedGoal.canChoose && !failedGoal.isConfirmed,
            "failed or conflicted goal changes do not fabricate success and allow explicit retry")
        let busyGoal = NativeActiveGoalPresentation(
            targetID: "new-goal", confirmedID: nil, savingID: nil, busy: true)
        try check(
            !busyGoal.canChoose && !busyGoal.isSaving && !busyGoal.isConfirmed,
            "unrelated model work disables choosing without claiming a goal save")
        let concurrentGoal = NativeActiveGoalPresentation(
            targetID: "other-goal", confirmedID: nil, savingID: "new-goal", busy: false)
        try check(
            !concurrentGoal.canChoose && !concurrentGoal.isConfirmed,
            "an in-flight UI selection cannot start another goal operation")
        print(
            "\(count) Foundation presentation/demo checks passed; no Apple UI was compiled or rendered."
        )
    }
}
