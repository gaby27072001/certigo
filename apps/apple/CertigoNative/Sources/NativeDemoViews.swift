import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    private enum DemoCatalogScenario: String, CaseIterable {
        case ready = "Available"
        case loading = "Loading"
        case empty = "Empty"
        case error = "Error"
    }

    private enum DemoSocialSection: String, CaseIterable {
        case friends = "Friends"
        case teams = "Teams"
    }

    struct NativeDemoRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @AppStorage("certigo.native-design-demo.v1") private var savedState = ""
        @State private var flow = NativeDemoFlow()
        @State private var tab = NativeDemoTab.catalog
        @State private var learnSection = NativeDemoLearnSection.explore
        @State private var objectivePath: [NativeDemoRoute] = []
        @State private var catalogPath: [NativeDemoRoute] = []
        @State private var scenario = DemoCatalogScenario.ready
        @State private var offline = false
        @State private var issue: AppInterfaceCopy.NativeLabel?
        @State private var showScenarios = false
        @State private var showReset = false
        @State private var persistence = NativeDemoPersistence.awaitingRestoration
        @State private var socialSection = DemoSocialSection.friends

        var body: some View {
            TabView(selection: mainTabSelection) {
                Group {
                    if learnSection == .myLearning {
                        NavigationStack(path: $objectivePath) {
                            objective.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    } else {
                        NavigationStack(path: $catalogPath) {
                            catalog.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    }
                }
                .tabItem { Label(copy.learn, systemImage: "book") }.tag(NativeDemoDestination.learn)
                NavigationStack {
                    unavailableService(
                        copy.coach, symbol: "bubble.left.and.bubble.right",
                        description:
                            copy.native(.demoCoachUnavailable)
                    )
                }
                .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                .tag(NativeDemoDestination.coach)
                NavigationStack {
                    social
                }
                .tabItem { Label(copy.social, systemImage: "person.2") }.tag(
                    NativeDemoDestination.social)
                NavigationStack { followUp }
                    .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                    .tag(NativeDemoDestination.profile)
            }
            .tint(NativePrism.tint)
            .sheet(isPresented: $showScenarios) {
                NavigationStack {
                    Form {
                        Section(copy.appLanguage) { NativeAppLanguagePicker() }
                        Section(copy.native(.demoCatalogStates)) {
                            Picker(copy.native(.demoCatalog), selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text(scenarioTitle($0)).tag($0)
                                }
                            }
                            Toggle(copy.native(.demoOfflineToggle), isOn: $offline)
                        }
                        Section {
                            Text(
                                copy.native(.demoSettingsScope)
                            )
                        }
                    }
                    .navigationTitle(copy.native(.demoSettings))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(copy[.done]) { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                copy.native(.demoResetConfirmation), isPresented: $showReset
            ) {
                Button(copy.native(.demoReset), role: .destructive) {
                    flow = NativeDemoFlow()
                    objectivePath = []
                    catalogPath = []
                    tab = .catalog
                    learnSection = .explore
                    scenario = .ready
                    offline = false
                    persistence.reset(&savedState)
                }
            }
            .alert(copy.native(.demoRestorationUnavailable), isPresented: issuePresented) {
                Button(copy[.done], role: .cancel) { issue = nil }
            } message: {
                Text(issue.map { copy.native($0) } ?? "")
            }
            .task {
                guard persistence == .awaitingRestoration else { return }
                do {
                    if let snapshot = try persistence.restore(savedState) {
                        flow = snapshot.flow
                        let navigation = snapshot.navigation
                        tab = navigation.selectedTab
                        learnSection = navigation.learnSection
                        objectivePath = navigation.objectivePath
                        catalogPath = navigation.catalogPath
                    } else {
                        learnSection = flow.objective == nil ? .explore : .myLearning
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                } catch {
                    issue =
                        .demoRestoreFailure
                }
            }
            .onChange(of: flow) { _, value in
                persistDemoSnapshot(flow: value)
            }
            .onChange(of: tab) { _, _ in persistDemoSnapshot() }
            .onChange(of: learnSection) { _, _ in persistDemoSnapshot() }
            .onChange(of: objectivePath) { _, _ in persistDemoSnapshot() }
            .onChange(of: catalogPath) { _, _ in persistDemoSnapshot() }
        }

        private var mainTabSelection: Binding<NativeDemoDestination> {
            Binding(
                get: { tab.destination },
                set: { destination in
                    tab = NativeDemoTab.selecting(destination, learnSection: learnSection)
                })
        }

        private var learnSectionSelection: Binding<NativeDemoLearnSection> {
            Binding(
                get: { learnSection },
                set: { section in
                    learnSection = section
                    tab = NativeDemoTab.selecting(.learn, learnSection: section)
                })
        }

        private var learnSelector: some View {
            Picker(copy.learn, selection: learnSectionSelection) {
                Text(copy.myLearning).tag(NativeDemoLearnSection.myLearning)
                Text(copy.explore).tag(NativeDemoLearnSection.explore)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("learn-section")
        }

        private func unavailableService(_ title: String, symbol: String, description: String)
            -> some View
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    ContentUnavailableView(
                        copy.native(.unavailable), systemImage: symbol,
                        description: Text(description))
                    Text(copy.native(.demoPreviewOnly))
                        .foregroundStyle(.secondary)
                    DemoPrimaryButton(title: copy.native(.demoReturnLearn), symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(title)
            .toolbar { demoToolbar }
        }

        private var social: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Picker(copy.social, selection: $socialSection) {
                        ForEach(DemoSocialSection.allCases, id: \.self) { section in
                            Text(section == .friends ? copy.friends : copy.teams).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    ContentUnavailableView(
                        copy.native(.unavailable),
                        systemImage: socialSection == .friends ? "person.2" : "person.3",
                        description: Text(
                            copy.native(.demoSocialUnavailable)
                        ))
                    DemoPrimaryButton(title: copy.native(.demoReturnLearn), symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.social)
            .toolbar { demoToolbar }
        }

        @ViewBuilder private func destination(for route: NativeDemoRoute) -> some View {
            switch route {
            case .preparation:
                preparation
            case .exercise:
                exercise
            case .goalDetail(let goal):
                goalDetail(goal)
            }
        }

        private func persistDemoSnapshot(flow currentFlow: NativeDemoFlow? = nil) {
            guard persistence == .ready else { return }
            do {
                let flowToPersist = currentFlow ?? flow
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flowToPersist, learnSection: learnSection)
                let snapshot = try NativeDemoSnapshot.make(
                    flow: flowToPersist, navigation: navigation)
                try persistence.save(snapshot, to: &savedState)
            } catch {
                issue =
                    .demoSaveFailure
            }
        }

        private var issuePresented: Binding<Bool> {
            Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })
        }

        private func resumeExercise() {
            do {
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flow
                ).resumingExercise(for: flow)
                objectivePath = navigation.objectivePath
                learnSection = .myLearning
                tab = navigation.selectedTab
            } catch {
                issue =
                    .demoReopenFailure
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    learnSelector
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.displayName(copy)).font(.largeTitle.bold())
                            Text(goal.displayTitle(copy)).font(.title2.weight(.semibold))
                            Text(flow.activitySummary(copy))
                                .font(.subheadline)
                            NavigationLink(value: flow.startRoute) {
                                Label(flow.startLabel(copy), systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .tint(.white)
                            .accessibilityIdentifier("resume-demo")
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.white)
                        .background(
                            NativePrism.objectiveFill,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy.native(.demoWorkshop)).font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                copy.native(.demoWorkshopHint)
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                copy.native(.demoFictionalContent),
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button(copy.native(.demoSwitchGoal), systemImage: "square.grid.2x2") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button(
                            copy.native(.demoHistoryAction), systemImage: "clock.arrow.circlepath"
                        ) {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            copy.native(.demoNextGoal),
                            systemImage: "scope",
                            description: Text(
                                copy.native(.demoExploreHint)
                            )
                        )
                        DemoPrimaryButton(title: copy[.chooseGoal], symbol: "arrow.right") {
                            learnSection = .explore
                            tab = .catalog
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private var catalog: some View {
            List {
                Section {
                    demoNotice
                    learnSelector
                }
                switch scenario {
                case .ready:
                    if flow.objective == nil {
                        Section {
                            Text(
                                copy.native(.demoChooseHint)
                            )
                        }
                    }
                    Section(copy.native(.demoWorkshops)) {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.displayName(copy)).font(.headline)
                                        Text(goal.displayTitle(copy)).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(copy.native(.demoVolume))
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel(copy.native(.demoSelectedGoal))
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                case .loading:
                    Section {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(goal.displayTitle(copy)).font(.headline)
                                Text(copy.native(.demoSituationExplore)).font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("\(copy.loading) · \(copy[.demo])", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button(copy.native(.demoFinishLoading)) { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            copy.native(.demoNoGoals), systemImage: "books.vertical",
                            description: Text(copy.native(.demoEmptyHint))
                        )
                        Button(copy.native(.demoShowGoals)) { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            copy.native(.demoCatalogUnavailable),
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                copy.native(.demoPreservedHint)))
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            scenario = .ready
                        }
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private func goalDetail(_ goal: NativeDemoFlow.Objective) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Text(goal.displayName(copy)).font(.largeTitle.bold()).foregroundStyle(
                        NativePrism.tint)
                    Text(goal.displayTitle(copy)).font(.title2.bold())
                    Text(
                        copy.native(.demoScenarioHint)
                    )
                    DemoReadingSection(
                        title: copy.native(.demoDecisionExplore), text: goal.practice.intent)
                    DemoReadingSection(
                        title: copy.native(.demoFictionalSituation), text: goal.practice.situation)
                    Label(copy.native(.demoNoGrade), systemImage: "text.bubble")
                    Label(copy.native(.demoLocalRestore), systemImage: "clock.arrow.circlepath")
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                DemoPrimaryButton(title: copy[.chooseGoal], symbol: "scope") {
                    flow.choose(goal)
                    learnSection = .myLearning
                    catalogPath = []
                    objectivePath = []
                    tab = .objective
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle(copy.native(.goalOverview)).navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(progress: NativeDemoPracticeProgress(current: .situation))
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(
                            title: copy.native(.demoSituation), text: practice.situation)
                        DemoReadingSection(title: copy.native(.demoTask), text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: copy.native(.demoBeforeChoose),
                            text:
                                copy.native(.demoBoundaryHint)
                        )
                        DemoPrimaryButton(
                            title: copy.native(.demoOpenQuestion), symbol: "arrow.right"
                        ) {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.native(.demoPreparation)).navigationBarTitleDisplayMode(.inline)
            .toolbar { demoToolbar }
        }

        private var exercise: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(
                            progress: NativeDemoPracticeProgress(
                                current: flow.phase == .reviewed ? .explanation : .decision))
                        switch flow.phase {
                        case .answering:
                            Label(
                                flow.selection == nil
                                    ? copy.native(.demoChooseAnswer)
                                    : copy.native(.demoAnswerSelected),
                                systemImage: flow.selection == nil
                                    ? "circle" : "checkmark.circle.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                flow.selection == nil ? Color.secondary : NativePrism.tint
                            )
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-answer-state")
                            Text(practice.title).font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(practice.situation).textSelection(.enabled)
                            Text(practice.question)
                                .font(.title3.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 12) {
                                ForEach(Array(NativeDemoFlow.options.enumerated()), id: \.offset) {
                                    index, option in
                                    Button {
                                        flow.select(index)
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Image(
                                                systemName: flow.selection == index
                                                    ? "checkmark.circle.fill" : "circle")
                                            Text(option).multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .frame(
                                            maxWidth: .infinity, minHeight: 44, alignment: .leading
                                        )
                                        .padding(12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(
                                        flow.selection == index ? NativePrism.tint : .primary
                                    )
                                    .background(
                                        Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                flow.selection == index
                                                    ? NativePrism.tint : Color(uiColor: .separator),
                                                lineWidth: flow.selection == index ? 2 : 1)
                                    }
                                    .accessibilityAddTraits(
                                        flow.selection == index ? .isSelected : []
                                    )
                                    .accessibilityLabel(option)
                                    .accessibilityValue(
                                        flow.selection == index
                                            ? copy.native(.selected) : copy.native(.notSelected)
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text(copy.native(.demoEditableHint))
                                .font(.subheadline).foregroundStyle(.secondary)
                        case .pending:
                            Label {
                                Text("\(copy.pending) · \(copy[.demo])")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text(copy.native(.demoChoiceSaved))
                                .font(.headline)
                            selectedAnswer
                            Text(
                                copy.native(.demoNoVerdict)
                            )
                            if offline {
                                Label(
                                    "\(copy[.offline]) · \(copy[.demo])", systemImage: "wifi.slash")
                                Text(
                                    copy.native(.demoOfflinePending)
                                )
                                DemoPrimaryButton(
                                    title: copy.native(.demoDisableOffline),
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    copy.native(.demoSimulateHint)
                                )
                                DemoPrimaryButton(
                                    title: copy.native(.demoSimulateExplanation),
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                copy.native(.demoExplanation),
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: copy.native(.demoConstraint), text: practice.constraint)
                            DemoReadingSection(
                                title: copy.native(.demoUnderstanding), text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoTakeaway(text: practice.takeaway)
                            Text(
                                copy.native(.demoFixtureHint)
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: copy.progressAndHistory,
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                copy.native(.demoPracticeAgain),
                                systemImage: "arrow.counterclockwise"
                            ) {
                                flow.restartQuestion()
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if flow.practice != nil, flow.phase == .answering {
                    DemoPrimaryButton(
                        title: "\(copy.submitAnswer) · \(copy[.demo])", symbol: "paperplane"
                    ) {
                        flow.submit()
                    }
                    .disabled(!flow.canSubmit)
                    .accessibilityHint(copy.native(.demoChooseBeforeContinue))
                    .accessibilityIdentifier("demo-submit")
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle(copy.native(.demoPractice)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.native(.demoSettings), systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.native(.demoChoice)).font(.headline)
                if let selection = flow.selection {
                    Text(NativeDemoFlow.options[selection])
                }
            }
            .accessibilityElement(children: .combine)
        }

        private var followUp: some View {
            List {
                Section {
                    demoNotice
                    Text(copy.native(.demoProfile)).font(.title2.bold())
                    Text(copy.native(.demoProfileHint))
                        .foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink {
                        demoHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        List {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section(copy.native(.demoControls)) {
                                Button(copy.native(.demoPreviewStates)) {
                                    showScenarios = true
                                }
                                .frame(minHeight: 44)
                                Button(copy.native(.demoReset), role: .destructive) {
                                    showReset = true
                                }
                                .frame(minHeight: 44)
                            }
                            Section(copy.native(.demoAppearance)) {
                                Text(
                                    copy.native(.demoAppearanceHint)
                                )
                            }
                            Section(copy.native(.account)) {
                                Text(
                                    copy.native(.demoAccountHint)
                                )
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.profile)
            .toolbar { demoToolbar }
        }

        private var demoHistory: some View {
            List {
                Section { demoNotice }
                Section(copy.native(.demoHistory)) {
                    if let goal = flow.objective {
                        Text(goal.displayTitle(copy)).font(.headline)
                        Button(action: resumeExercise) {
                            Label(copy.resume, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary(copy))
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text(copy.native(.demoHistoryHint))
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            copy[.chooseGoal], systemImage: "scope",
                            description: Text(copy[.noHistory]))
                        Button(copy[.chooseGoal]) {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.native(.demoHistory))
            .toolbar { demoToolbar }
        }

        private struct DemoReadingSection: View {
            let title: String
            let text: String

            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(text).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private struct DemoPracticeTrail: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let progress: NativeDemoPracticeProgress

            var body: some View {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { steps }
                    VStack(alignment: .leading, spacing: 8) { steps }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress.accessibilityLabel(copy))
            }

            @ViewBuilder private var steps: some View {
                ForEach(NativeDemoPracticeStage.allCases, id: \.self) { step in
                    let state = progress.state(for: step)
                    Label(
                        step.label(copy),
                        systemImage: state.symbol
                    )
                    .foregroundStyle(state == .current ? NativePrism.tint : Color.secondary)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private struct DemoTakeaway: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let text: String

            var body: some View {
                GroupBox {
                    Text(text)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Label(copy.native(.takeaway), systemImage: "lightbulb")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }

        private struct DemoResponsibilities: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let rows: [NativeDemoPractice.Responsibility]

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text(copy.native(.demoResponsibilities)).font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(rows, id: \.layer) { row in
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.layer).font(.subheadline.weight(.semibold))
                            Text(row.owner)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }

        private var demoNotice: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label(copy.native(.demoNotice), systemImage: "testtube.2")
                Text(copy.native(.demoFrenchExamples)).font(.caption)
                NativeContentLanguageBadges(languages: ["fr"])
            }

            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("synthetic-demo-notice")
        }

        private func scenarioTitle(_ scenario: DemoCatalogScenario) -> String {
            switch scenario {
            case .ready: copy.native(.demoReady)
            case .loading: copy.native(.demoLoading)
            case .empty: copy.native(.demoEmpty)
            case .error: copy.native(.demoError)
            }
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button(copy.native(.close)) { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(copy.native(.demoSettings), systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        copy.native(.demoReset), systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label(copy.native(.demoOptions), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private struct DemoPrimaryButton: View {
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            NativePrimaryButton(title: title, symbol: symbol, action: action)
        }
    }

    #Preview("Learn · demonstration") { NativeDemoRoot() }
#endif
