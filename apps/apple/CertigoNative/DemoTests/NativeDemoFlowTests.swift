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
        for (code, band) in [
            ("AZ-900", 0), ("AI-900", 1), ("PL-900", 2), ("MS-900", 3),
            ("DP-900", 4), ("SC-900", 5), (" ai-102 ", 1), ("", 0), ("UNKNOWN-1", 0),
        ] {
            try check(
                NativeTrackAppearance.band(for: code) == band,
                "stable Prism band for \(code.debugDescription)")
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
        var realNavigation = NativeLearningNavigation()
        try check(
            realNavigation.tab == .learn && realNavigation.learn == .explore,
            "real account without a goal starts in Learn Explore without a mutation")
        realNavigation = NativeLearningNavigation(hasGoal: true)
        try check(
            realNavigation.tab == .learn && realNavigation.learn == .myLearning,
            "real account with a confirmed goal starts in My Learning")
        realNavigation.learn = .explore
        try check(
            realNavigation.showsTrack("catalog", activeID: "active", openedID: "opened"),
            "Explore lists catalog entries without selecting a goal")
        realNavigation.learn = .myLearning
        try check(
            realNavigation.showsTrack("opened", activeID: "active", openedID: "opened")
                && realNavigation.showsTrack("ACTIVE", activeID: "active", openedID: "opened")
                && !realNavigation.showsTrack("other", activeID: "active", openedID: "opened"),
            "My Learning keeps the open path visible alongside the confirmed goal")
        realNavigation.learn = .explore
        realNavigation.social = .teams
        for destination in NativeLearningNavigation.Tab.allCases {
            realNavigation.tab = destination
            try check(
                realNavigation.learn == .explore && realNavigation.social == .teams,
                "real \(destination.rawValue) tab switch preserves local navigation choices")
        }
        try check(
            NativeLearningNavigation.Tab.allCases.map(\.rawValue) == [
                "learn", "coach", "social", "profile",
            ],
            "real and demo shells use the same approved four destinations")
        realNavigation = NativeLearningNavigation(hasGoal: false)
        try check(
            realNavigation.tab == .learn && realNavigation.learn == .explore
                && realNavigation.social == .friends,
            "a new account resets only local navigation without restoring another account's tabs")
        let situationProgress = NativeDemoPracticeProgress(current: .situation)
        try check(
            situationProgress.state(for: .situation) == .current
                && situationProgress.state(for: .decision) == .upcoming
                && situationProgress.state(for: .explanation) == .upcoming,
            "situation stage distinguishes current from upcoming without a result signal")
        let decisionProgress = NativeDemoPracticeProgress(current: .decision)
        try check(
            decisionProgress.state(for: .situation) == .completed
                && decisionProgress.state(for: .decision) == .current
                && decisionProgress.state(for: .explanation) == .upcoming
                && decisionProgress.state(for: .situation).symbol == "circle.fill",
            "decision stage shows reading order with a neutral completed marker")
        let explanationProgress = NativeDemoPracticeProgress(current: .explanation)
        try check(
            explanationProgress.state(for: .situation) == .completed
                && explanationProgress.state(for: .decision) == .completed
                && explanationProgress.state(for: .explanation) == .current
                && explanationProgress.accessibilityLabel
                    .contains("not whether an answer is correct"),
            "explanation stage explicitly separates flow progress from answer correctness")
        var persistence = NativeDemoPersistence.awaitingRestoration
        var storedSnapshot = "not yet restored"
        try persistence.save(snapshot, to: &storedSnapshot)
        try check(
            storedSnapshot == "not yet restored" && persistence == .awaitingRestoration,
            "initial loading cannot replace stored demo data")
        let freshSnapshot = try NativeDemoSnapshot.make(
            flow: NativeDemoFlow(),
            navigation: NativeDemoNavigationState(
                selectedTab: .catalog, objectivePath: [], catalogPath: []))
        let validSnapshot = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        let futureSnapshot = validSnapshot.replacingOccurrences(
            of: "\"schema\":1", with: "\"schema\":2")
        try check(futureSnapshot != validSnapshot, "future-schema fixture changes the schema")
        for rejectedSnapshot in ["not json · é", futureSnapshot] {
            persistence = .awaitingRestoration
            storedSnapshot = rejectedSnapshot
            var rejected = false
            do {
                _ = try persistence.restore(storedSnapshot)
            } catch {
                rejected = true
            }
            try check(
                rejected && persistence == .preservingRejectedSnapshot,
                "invalid or future demo restoration blocks automatic persistence")
            for destination in NativeDemoDestination.allCases {
                let changedNavigation = try NativeDemoNavigationState.make(
                    selectedTab: .selecting(destination, learnSection: .myLearning),
                    objectivePath: [.exercise], catalogPath: [],
                    flow: workshop, learnSection: .myLearning)
                let changedSnapshot = try NativeDemoSnapshot.make(
                    flow: workshop, navigation: changedNavigation)
                try persistence.save(changedSnapshot, to: &storedSnapshot)
                try check(
                    Array(storedSnapshot.utf8) == Array(rejectedSnapshot.utf8),
                    "\(destination) navigation preserves rejected snapshot bytes")
            }
            try persistence.save(freshSnapshot, to: &storedSnapshot)
            try check(
                Array(storedSnapshot.utf8) == Array(rejectedSnapshot.utf8),
                "new in-memory demo work cannot overwrite a rejected snapshot")
            persistence.reset(&storedSnapshot)
            try check(
                storedSnapshot.isEmpty && persistence == .ready,
                "explicit demo reset alone clears rejected storage and re-enables saving")
            try persistence.save(freshSnapshot, to: &storedSnapshot)
            try check(
                try NativeDemoSnapshot.restore(Data(storedSnapshot.utf8)) == freshSnapshot,
                "a fresh demo persists normally after explicit reset")
        }
        persistence = .awaitingRestoration
        storedSnapshot = validSnapshot
        try check(
            try persistence.restore(storedSnapshot) == snapshot && persistence == .ready,
            "valid restoration preserves the saved flow and enables persistence")
        try persistence.save(freshSnapshot, to: &storedSnapshot)
        try check(
            try NativeDemoSnapshot.restore(Data(storedSnapshot.utf8)) == freshSnapshot,
            "normal restored demo accepts subsequent saves")
        persistence = .awaitingRestoration
        storedSnapshot = ""
        try check(
            try persistence.restore(storedSnapshot) == nil && persistence == .ready,
            "an empty installation finishes restoration without inventing saved activity")
        try persistence.save(snapshot, to: &storedSnapshot)
        try check(
            try NativeDemoSnapshot.restore(Data(storedSnapshot.utf8)) == snapshot,
            "first-run demo activity persists after empty restoration")
        let readingContent = NativeLessonReadingContent(
            lessonTitle: "  Loaded lesson  ",
            blocks: [
                (type: "hook", title: "Situation", body: "Hook paragraph"),
                (type: "concept", title: "Concept", body: "Concept paragraph\n\nSecond paragraph"),
                (type: "example", title: nil, body: "Example paragraph"),
                (type: "code", title: "Do not read code", body: "Excluded code"),
                (type: "check", title: "Do not read questions", body: "Excluded question"),
                (type: "recap", title: "Takeaway", body: "Recap paragraph"),
                (type: "unknown", title: "Do not read unknown blocks", body: "Excluded unknown"),
            ])
        try check(
            readingContent.parts == [
                .title("  Loaded lesson  "), .title("Situation"), .markdown("Hook paragraph"),
                .title("Concept"), .markdown("Concept paragraph\n\nSecond paragraph"),
                .markdown("Example paragraph"), .title("Takeaway"), .markdown("Recap paragraph"),
            ],
            "audio selects pedagogical titles and bodies in order, excluding code/check/unknown")
        var renderedBodies: [String] = []
        try check(
            try readingContent.spokenText { body in
                renderedBodies.append(body)
                return body
            } == """
                Loaded lesson

                Situation

                Hook paragraph

                Concept

                Concept paragraph

                Second paragraph

                Example paragraph

                Takeaway

                Recap paragraph
                """,
            "audio assembles every selected paragraph in reading order")
        try check(
            renderedBodies == [
                "Hook paragraph", "Concept paragraph\n\nSecond paragraph",
                "Example paragraph", "Recap paragraph",
            ],
            "only body Markdown is sent to the renderer; literal titles are preserved")
        let editorialReading = NativeLessonReadingContent(
            editorialTitle: "Assistants responsables",
            objective: "Repérer les responsabilités humaines.",
            hook: "Un assistant propose une réponse.",
            keyIdeas: ["Définir le périmètre.", "Prévoir une supervision."],
            exampleSituation: "Une équipe automatise un tri.",
            exampleSteps: ["Vérifier les données.", "Prévoir une escalade."],
            exampleDecision: "Une personne garde la décision finale.",
            recap: "L’automatisation reste sous contrôle humain."
        )
        try check(
            editorialReading.parts == [
                .title("Assistants responsables"),
                .text("Repérer les responsabilités humaines."),
                .text("Un assistant propose une réponse."),
                .title("Idées clés"),
                .text("Définir le périmètre."),
                .text("Prévoir une supervision."),
                .title("Exemple résolu"),
                .text("Une équipe automatise un tri."),
                .text("1. Vérifier les données."),
                .text("2. Prévoir une escalade."),
                .text("Une personne garde la décision finale."),
                .title("À retenir"),
                .text("L’automatisation reste sous contrôle humain."),
            ],
            "editorial audio follows only the displayed pedagogical allowlist in order")
        var editorialMarkdownBodies: [String] = []
        let editorialSpeech = try editorialReading.spokenText { body in
            editorialMarkdownBodies.append(body)
            return body
        }
        try check(
            editorialMarkdownBodies.isEmpty
                && editorialSpeech == """
                    Assistants responsables

                    Repérer les responsabilités humaines.

                    Un assistant propose une réponse.

                    Idées clés

                    Définir le périmètre.

                    Prévoir une supervision.

                    Exemple résolu

                    Une équipe automatise un tri.

                    1. Vérifier les données.

                    2. Prévoir une escalade.

                    Une personne garde la décision finale.

                    À retenir

                    L’automatisation reste sous contrôle humain.
                    """,
            "editorial audio preserves plain text without Markdown conversion")
        enum ReadingFailure: Error { case invalidMarkdown }
        var renderingFailed = false
        do {
            _ = try readingContent.spokenText { _ in throw ReadingFailure.invalidMarkdown }
        } catch ReadingFailure.invalidMarkdown {
            renderingFailed = true
        }
        try check(
            renderingFailed,
            "renderer failure aborts the complete reading rather than skipping a body")
        try check(
            try NativeLessonReadingContent(
                lessonTitle: " \n ", blocks: [(type: "recap", title: nil, body: "\t")]
            ).spokenText { $0 } == "",
            "missing and whitespace-only lesson text never invents audio content")
        try check(
            try NativeLessonReadingContent(
                lessonTitle: "Équipe — 日本語",
                blocks: [(type: "concept", title: nil, body: "Données\n\n学習")]
            ).spokenText { $0 } == "Équipe — 日本語\n\nDonnées\n\n学習",
            "portable assembly preserves original multilingual text and paragraph boundaries")
        #if canImport(Darwin)
            let markdownText = try NativeLessonReadingContent.plainText(
                "**Comprendre** le [cloud](https://example.invalid/hidden-url).\n\n次の段落")
            try check(
                markdownText == "Comprendre le cloud.\n\n次の段落",
                "Apple Markdown extraction strips markup and link targets but preserves paragraphs")
            try check(
                try NativeLessonReadingContent(
                    lessonTitle: "Lesson",
                    blocks: [(type: "concept", title: "Section", body: "*First*.\n\nSecond.")]
                ).spokenText(renderingMarkdown: NativeLessonReadingContent.plainText)
                    == "Lesson\n\nSection\n\nFirst.\n\nSecond.",
                "Apple Markdown renderer is wired into full lesson assembly")
        #endif
        print(
            "\(count) Foundation presentation/demo checks passed; no Apple UI was compiled or rendered."
        )
    }
}
