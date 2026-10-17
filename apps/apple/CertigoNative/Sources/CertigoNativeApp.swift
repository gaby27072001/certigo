import Foundation

#if canImport(SwiftUI)
    import CertigoData

    import CertigoDomain

    import SwiftUI

    @main
    struct CertigoNativeApp: App {
        var body: some Scene {
            WindowGroup {
                NativeEntry()
                    .tint(NativePrism.tint)
                    .environment(\.locale, Locale(identifier: "en"))
            }
        }
    }

    // THESIS: A decision workshop extends the objective-first demo; no invented course or metrics.
    // OWN-WORLD: Prism violet, semantic surfaces, SF text, native navigation and glass controls.
    // STORY: Read a situation, decide, wait, understand; every demo result is explicitly synthetic.
    // FIRST VIEWPORT: One colored objective plane, one resume action, then quiet supporting rows.
    // FORM: Reviewable extension of approved A, not a new identity; bounded iPad reading width.
    private enum NativePrism {
        static let tint = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 128 / 255, green: 151 / 255, blue: 248 / 255, alpha: 1)
                    : UIColor(red: 59 / 255, green: 53 / 255, blue: 242 / 255, alpha: 1)
            })
        static let objectiveFill = Color(red: 59 / 255, green: 53 / 255, blue: 242 / 255)
    }

    private struct NativeEntry: View {
        @State private var showDemo = false
        @State private var showDeveloper = false

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        Text("One question. A clearer idea.")
                            .font(.largeTitle.bold())
                            .padding(.vertical, 16)
                        Text("Explore Certigo’s native learning preview.")
                            .foregroundStyle(.secondary)
                        Button("Explore the demo", systemImage: "play.circle") { showDemo = true }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("open-native-demo")
                    }
                    Section("Isolated demonstration") {
                        Text(
                            "Goals, answers and explanations are fictional. No account, network or real result is used."
                        )
                    }
                    Section("Development") {
                        Button(
                            "Open the test API connector",
                            systemImage: "wrench.and.screwdriver"
                        ) {
                            showDeveloper = true
                        }
                        .frame(minHeight: 44)
                        Text(
                            "For test accounts only. This is not production sign-in."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
                .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                .sheet(isPresented: $showDeveloper) { NativeDeveloperConnector() }
            }
        }
    }

    private struct NativeDeveloperConnector: View {
        @Environment(\.dismiss) private var dismiss
        @State private var model = NativeModel()

        var body: some View {
            NativeRoot(model: model)
                .safeAreaInset(edge: .top) {
                    HStack {
                        Text("Developer connector").font(.subheadline)
                        Spacer()
                        Button("Close") { dismiss() }
                    }
                    .padding()
                    .background(.background)
                }
        }
    }

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

    private struct NativeDemoRoot: View {
        @Environment(\.dismiss) private var dismiss
        @AppStorage("certigo.native-design-demo.v1") private var savedState = ""
        @State private var flow = NativeDemoFlow()
        @State private var tab = NativeDemoTab.catalog
        @State private var learnSection = NativeDemoLearnSection.explore
        @State private var objectivePath: [NativeDemoRoute] = []
        @State private var catalogPath: [NativeDemoRoute] = []
        @State private var scenario = DemoCatalogScenario.ready
        @State private var offline = false
        @State private var issue: String?
        @State private var showScenarios = false
        @State private var showReset = false
        @State private var restored = false
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
                .tabItem { Label("Learn", systemImage: "book") }.tag(NativeDemoDestination.learn)
                NavigationStack {
                    unavailableService(
                        "Coach", symbol: "bubble.left.and.bubble.right",
                        description:
                            "Coach is not connected in this preview. No AI response, conversation history or saved memory is created."
                    )
                }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                .tag(NativeDemoDestination.coach)
                NavigationStack {
                    social
                }
                .tabItem { Label("Social", systemImage: "person.2") }.tag(
                    NativeDemoDestination.social)
                NavigationStack { followUp }
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(NativeDemoDestination.profile)
            }
            .tint(NativePrism.tint)
            .sheet(isPresented: $showScenarios) {
                NavigationStack {
                    Form {
                        Section("Catalog states · simulation") {
                            Picker("Catalog", selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }
                            Toggle("Simulate offline mode", isOn: $offline)
                        }
                        Section {
                            Text(
                                "These settings do not change the device network or a server."
                            )
                        }
                    }
                    .navigationTitle("Demo settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear only the saved demonstration?", isPresented: $showReset
            ) {
                Button("Reset the demo", role: .destructive) {
                    flow = NativeDemoFlow()
                    objectivePath = []
                    catalogPath = []
                    tab = .catalog
                    learnSection = .explore
                    scenario = .ready
                    offline = false
                    savedState = ""
                }
            }
            .alert("Demo restoration unavailable", isPresented: issuePresented) {
                Button("OK", role: .cancel) { issue = nil }
            } message: {
                Text(issue ?? "")
            }
            .task {
                guard !restored else { return }
                restored = true
                do {
                    if !savedState.isEmpty {
                        let snapshot = try NativeDemoSnapshot.restore(Data(savedState.utf8))
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
                        "The saved demonstration cannot be read. Reset only the demo in its settings."
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
            Picker("Learn section", selection: learnSectionSelection) {
                Text("My Learning").tag(NativeDemoLearnSection.myLearning)
                Text("Explore").tag(NativeDemoLearnSection.explore)
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
                        "\(title) is not connected", systemImage: symbol,
                        description: Text(description))
                    Text(
                        "This is a navigation preview, not a working \(title.lowercased()) service."
                    )
                    .foregroundStyle(.secondary)
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
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
                    Picker("Social section", selection: $socialSection) {
                        ForEach(DemoSocialSection.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    ContentUnavailableView(
                        "\(socialSection.rawValue) are not connected",
                        systemImage: socialSection == .friends ? "person.2" : "person.3",
                        description: Text(
                            "Social is unavailable in this navigation preview. No real relationships, invitations, team membership or sharing are loaded."
                        ))
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle("Social")
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
            guard restored else { return }
            do {
                let flowToPersist = currentFlow ?? flow
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flowToPersist, learnSection: learnSection)
                let snapshot = try NativeDemoSnapshot.make(
                    flow: flowToPersist, navigation: navigation)
                savedState = String(
                    decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
            } catch {
                issue =
                    "The demonstration could not be saved. You can continue in the current session."
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
                    "The question cannot be reopened. Choose a goal in Learn > Explore."
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    demoNotice
                    learnSelector
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.displayName).font(.largeTitle.bold())
                            Text(goal.displayTitle).font(.title2.weight(.semibold))
                            Text(flow.activitySummary)
                                .font(.subheadline)
                            NavigationLink(value: flow.startRoute) {
                                Label(flow.startLabel, systemImage: "arrow.right.circle.fill")
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
                            NativePrism.objectiveFill, in: RoundedRectangle(cornerRadius: 24))
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The decision workshop").font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                "Read a situation, make a choice, understand the explanation."
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                "Fictional content · not a published course",
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button("Switch goal", systemImage: "square.grid.2x2") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button("View demo history", systemImage: "clock.arrow.circlepath") {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            "Your next learning goal",
                            systemImage: "scope",
                            description: Text(
                                "Explore two fictional situations. No account or real result is needed."
                            )
                        )
                        DemoPrimaryButton(title: "Explore goals", symbol: "arrow.right") {
                            learnSection = .explore
                            tab = .catalog
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Learn")
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
                                "Choose a demo goal to begin. These French examples are fictional, not published courses."
                            )
                        }
                    }
                    Section("Demonstration workshops") {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.displayName).font(.headline)
                                        Text(goal.displayTitle).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("1 fictional situation · 1 question · French")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel("Selected goal")
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
                                Text(goal.displayTitle).font(.headline)
                                Text("A situation to explore").font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("Simulated loading…", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button("Finish simulated loading") { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            "No goals in this example", systemImage: "books.vertical",
                            description: Text("The empty catalog is a demonstration scenario.")
                        )
                        Button("Show demo goals") { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            "Catalog unavailable · simulation",
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                "Your demo state is preserved. No server is contacted."))
                        Button("Retry the simulation", systemImage: "arrow.clockwise") {
                            scenario = .ready
                        }
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Learn")
            .toolbar { demoToolbar }
        }

        private func goalDetail(_ goal: NativeDemoFlow.Objective) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Text(goal.displayName).font(.largeTitle.bold()).foregroundStyle(
                        NativePrism.tint)
                    Text(goal.displayTitle).font(.title2.bold())
                    Text(
                        "A short scenario to explore the native experience. This is not a published catalog."
                    )
                    DemoReadingSection(title: "The decision to explore", text: goal.practice.intent)
                    DemoReadingSection(
                        title: "The fictional situation", text: goal.practice.situation)
                    Label("Read, choose, understand · no grade", systemImage: "text.bubble")
                    Label("Local demo restoration", systemImage: "clock.arrow.circlepath")
                    DemoPrimaryButton(title: "Choose this goal", symbol: "scope") {
                        flow.choose(goal)
                        learnSection = .myLearning
                        catalogPath = []
                        objectivePath = []
                        tab = .objective
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Goal overview").navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(current: .situation)
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(title: "The situation", text: practice.situation)
                        DemoReadingSection(title: "Your task", text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: "Before you choose",
                            text:
                                "Identify what the team wants to manage and what it wants to delegate. Focus on that boundary, not a provider name."
                        )
                        DemoPrimaryButton(title: "Open the question", symbol: "arrow.right") {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Preparation").navigationBarTitleDisplayMode(.inline)
            .toolbar { demoToolbar }
        }

        private var exercise: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(
                            current: flow.phase == .reviewed ? .explanation : .decision)
                        switch flow.phase {
                        case .answering:
                            Label(
                                flow.selection == nil
                                    ? "Choose an answer" : "Answer selected",
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
                            Text(practice.question).font(.headline)
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
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
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
                                            ? "Selected" : "Not selected"
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text("You can change your choice before the simulated submission.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "Save the demo answer", symbol: "paperplane"
                            ) {
                                flow.submit()
                            }
                            .disabled(!flow.canSubmit)
                            .accessibilityHint("Choose an answer before continuing.")
                            .accessibilityIdentifier("demo-submit")
                        case .pending:
                            Label {
                                Text("Demo answer pending")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text("Your choice is saved in the demo.")
                                .font(.headline)
                            selectedAnswer
                            Text(
                                "No verdict, score or reward is calculated on this device."
                            )
                            if offline {
                                Label("Offline · simulation", systemImage: "wifi.slash")
                                Text(
                                    "The demo answer remains pending. The offline scenario pauses the next simulation step."
                                )
                                DemoPrimaryButton(
                                    title: "Turn off the offline scenario",
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    "The next action simulates a server response. It does not contact an API."
                                )
                                DemoPrimaryButton(
                                    title: "Simulate the fictional explanation",
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                "Fictional explanation · no verdict",
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: "The decisive constraint", text: practice.constraint)
                            DemoReadingSection(
                                title: "Understanding the decision", text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoReadingSection(title: "Takeaway", text: practice.takeaway)
                            Text(
                                "This is a design fixture, not the correction of a published question. It appears for every choice: the demo gives no verdict or score."
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "View demo history",
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                "Practice the demo question again",
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
            .navigationTitle("Practice · demo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your demo choice").font(.headline)
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
                    Text("Preview profile").font(.title2.bold())
                    Text("No account is signed in. This screen shows only the local demonstration.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink {
                        demoHistory
                    } label: {
                        Label("Progress & history", systemImage: "clock.arrow.circlepath")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        List {
                            Section("Demonstration controls") {
                                Button("Preview states & offline simulation") {
                                    showScenarios = true
                                }
                                .frame(minHeight: 44)
                                Button("Reset the demo", role: .destructive) { showReset = true }
                                    .frame(minHeight: 44)
                            }
                            Section("Appearance & accessibility") {
                                Text(
                                    "The preview follows system appearance and text size. Navigation uses system transitions and controls respect Reduce Transparency."
                                )
                            }
                            Section("Account") {
                                Text(
                                    "Account, privacy and notification settings are not connected in this preview. No account preferences are changed."
                                )
                            }
                        }
                        .navigationTitle("Settings")
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Profile")
            .toolbar { demoToolbar }
        }

        private var demoHistory: some View {
            List {
                Section { demoNotice }
                Section("Demo history") {
                    if let goal = flow.objective {
                        Text(goal.displayTitle).font(.headline)
                        Button(action: resumeExercise) {
                            Label(flow.resumeLabel, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary)
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text("This saved demonstration is not certification progress.")
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            "Start with a goal", systemImage: "scope",
                            description: Text("No demo activity is saved."))
                        Button("Explore goals") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Progress & history")
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
            enum Step: String, CaseIterable {
                case situation = "Situation"
                case decision = "Decision"
                case explanation = "Explanation"
            }
            let current: Step

            var body: some View {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { steps }
                    VStack(alignment: .leading, spacing: 8) { steps }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Current stage: \(current.rawValue). Situation, decision, explanation.")
            }

            @ViewBuilder private var steps: some View {
                ForEach(Step.allCases, id: \.self) { step in
                    Label(
                        step.rawValue,
                        systemImage: step == current ? "circle.inset.filled" : "circle"
                    )
                    .foregroundStyle(step == current ? NativePrism.tint : Color.secondary)
                    .fontWeight(step == current ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private struct DemoResponsibilities: View {
            let rows: [NativeDemoPractice.Responsibility]

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who manages what?").font(.headline)
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
                Label("Demo · fictional data and results", systemImage: "testtube.2")
                Text("Learning examples: French").font(.caption)
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("synthetic-demo-notice")
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        "Reset the demo", systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label("Demo options", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private struct DemoPrimaryButton: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            if #available(iOS 26.0, *), !reduceTransparency {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        }

        private var button: some View {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
        }
    }

    #Preview("Learn · demonstration") { NativeDemoRoot() }
#endif

// A demo-only state machine: no API identity, scoring, answer keys, rewards or production progress.
struct NativeDemoFlow: Codable, Equatable {
    enum Objective: String, Codable, CaseIterable {
        case fundamentals = "Cloud · découverte"
        case operations = "Cloud · exploitation"

        var displayName: String {
            switch self {
            case .fundamentals: "Cloud · discovery"
            case .operations: "Cloud · operations"
            }
        }
        var displayTitle: String {
            switch self {
            case .fundamentals: "Cloud fundamentals"
            case .operations: "Cloud services in practice"
            }
        }
        var title: String {
            switch self {
            case .fundamentals: "Les fondamentaux du cloud"
            case .operations: "Les services cloud au quotidien"
            }
        }
        var symbol: String {
            switch self {
            case .fundamentals: "cloud"
            case .operations: "server.rack"
            }
        }
        var practice: NativeDemoPractice {
            switch self {
            case .fundamentals: .fundamentals
            case .operations: .operations
            }
        }
    }
    enum Phase: String, Codable {
        case answering, pending, reviewed
        var symbol: String {
            switch self {
            case .answering: "circle"
            case .pending: "clock"
            case .reviewed: "text.bubble"
            }
        }
    }
    enum InvalidSnapshot: Error { case inconsistentState }
    static let options = [
        "Une infrastructure à administrer (IaaS)",
        "Une plateforme gérée (PaaS)", "Un logiciel prêt à l’emploi (SaaS)",
    ]
    private(set) var objective: Objective?
    private(set) var selection: Int?
    private(set) var phase = Phase.answering

    var canSubmit: Bool { objective != nil && selection != nil && phase == .answering }
    var practice: NativeDemoPractice? { objective?.practice }
    var startRoute: NativeDemoRoute {
        phase == .answering && selection == nil ? .preparation : .exercise
    }
    var startLabel: String {
        startRoute == .preparation ? "Explore the situation" : resumeLabel
    }
    var activitySummary: String {
        switch phase {
        case .answering:
            selection == nil
                ? "A situation to explore · no grade"
                : "An editable choice · not submitted"
        case .pending: "Demo answer pending · no confirmed result"
        case .reviewed: "Fictional explanation available · no verdict"
        }
    }
    var resumeLabel: String {
        switch phase {
        case .answering: selection == nil ? "Start a question" : "Resume your choice"
        case .pending: "Resume the pending answer"
        case .reviewed: "Read the fictional explanation again"
        }
    }
    mutating func choose(_ objective: Objective) {
        guard self.objective != objective else { return }
        self.objective = objective
        restartQuestion()
    }
    mutating func select(_ index: Int) {
        guard objective != nil, phase == .answering, Self.options.indices.contains(index) else {
            return
        }
        selection = index
    }
    mutating func submit() {
        guard canSubmit else { return }
        phase = .pending
    }
    mutating func receiveMockExplanation(offline: Bool) {
        guard phase == .pending, !offline else { return }
        phase = .reviewed
    }
    mutating func restartQuestion() {
        selection = nil
        phase = .answering
    }
    static func restore(_ data: Data) throws -> Self {
        let flow = try JSONDecoder().decode(Self.self, from: data)
        guard flow.selection.map({ options.indices.contains($0) }) ?? true,
            flow.objective != nil || (flow.selection == nil && flow.phase == .answering),
            flow.phase == .answering || flow.selection != nil
        else {
            throw InvalidSnapshot.inconsistentState
        }
        return flow
    }
}

struct NativeDemoPractice: Sendable {
    struct Responsibility: Sendable {
        let layer: String
        let owner: String
    }
    let title: String
    let intent: String
    let situation: String
    let question: String
    let constraint: String
    let explanation: String
    let takeaway: String
    let responsibilities: [Responsibility]

    static let fundamentals = Self(
        title: "Déployer sans gérer les serveurs",
        intent: "Distinguer une plateforme gérée d’une infrastructure à administrer.",
        situation:
            "L’équipe Exemple veut déployer son application sans administrer le système d’exploitation des serveurs. Elle souhaite garder la responsabilité de son code et de ses données.",
        question: "Quel modèle de service correspond à cette situation fictive ?",
        constraint:
            "L’équipe veut déléguer l’administration du système d’exploitation, pas son application.",
        explanation:
            "Dans cet exemple inventé, une plateforme gérée (PaaS) correspond à cette limite : le fournisseur prend en charge la plateforme et son système. L’équipe déploie son code. Une infrastructure (IaaS) lui laisserait la gestion du système ; un logiciel prêt à l’emploi (SaaS) ne lui fournit pas le même cadre pour déployer son application.",
        takeaway:
            "Le critère utile est la responsabilité conservée par l’équipe, pas seulement la présence de serveurs dans le cloud.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Exemple"),
            .init(
                layer: "Plateforme et système d’exploitation",
                owner: "Le fournisseur, dans cet exemple PaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])

    static let operations = Self(
        title: "Garder la main sur le système",
        intent: "Identifier ce qui reste à administrer dans une infrastructure cloud.",
        situation:
            "L’équipe Atelier exploite une application qui exige une configuration particulière du système d’exploitation. Elle veut installer ses composants système et gérer elle-même les mises à jour, sans entretenir de serveurs physiques.",
        question:
            "Quel modèle de service lui laisse cette responsabilité dans ce scénario fictif ?",
        constraint:
            "L’équipe veut conserver le contrôle du système d’exploitation tout en déléguant le matériel.",
        explanation:
            "Dans cet exemple inventé, une infrastructure à administrer (IaaS) laisse à l’équipe le choix et la gestion du système d’exploitation. Le fournisseur prend en charge le matériel. Une plateforme gérée (PaaS) ou un logiciel prêt à l’emploi (SaaS) ne lui donnent pas cette même responsabilité système.",
        takeaway:
            "Déléguer le matériel ne signifie pas déléguer les mises à jour du système : la frontière dépend du modèle choisi.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Atelier"),
            .init(
                layer: "Système d’exploitation et mises à jour",
                owner: "L’équipe Atelier, dans cet exemple IaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])
}

enum NativeDemoDestination: String, CaseIterable, Hashable {
    case learn, coach, social, profile
}

enum NativeDemoLearnSection: String, Codable {
    case myLearning, explore
}

// Retain version-one storage identifiers; visible destinations use the approved English names.
enum NativeDemoTab: String, Codable, CaseIterable, Hashable {
    case objective, catalog, followUp, coach, social

    var destination: NativeDemoDestination {
        switch self {
        case .objective, .catalog: .learn
        case .followUp: .profile
        case .coach: .coach
        case .social: .social
        }
    }

    static func selecting(
        _ destination: NativeDemoDestination, learnSection: NativeDemoLearnSection
    ) -> Self {
        switch destination {
        case .learn: learnSection == .myLearning ? .objective : .catalog
        case .coach: .coach
        case .social: .social
        case .profile: .followUp
        }
    }
}

enum NativeDemoRoute: Codable, Equatable, Hashable {
    case preparation
    case exercise
    case goalDetail(NativeDemoFlow.Objective)
}

struct NativeDemoNavigationState: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, inconsistentRoute }
    private static let maximumEncodedBytes = 4_096

    let selectedTab: NativeDemoTab
    let objectivePath: [NativeDemoRoute]
    let catalogPath: [NativeDemoRoute]
    let learnSection: NativeDemoLearnSection

    init(
        selectedTab: NativeDemoTab, objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute], learnSection: NativeDemoLearnSection? = nil
    ) {
        self.selectedTab = selectedTab
        self.objectivePath = objectivePath
        self.catalogPath = catalogPath
        self.learnSection = learnSection ?? (selectedTab == .catalog ? .explore : .myLearning)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedTab, objectivePath, catalogPath, learnSection
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedTab: try values.decode(NativeDemoTab.self, forKey: .selectedTab),
            objectivePath: try values.decode([NativeDemoRoute].self, forKey: .objectivePath),
            catalogPath: try values.decode([NativeDemoRoute].self, forKey: .catalogPath),
            learnSection: try values.decodeIfPresent(
                NativeDemoLearnSection.self, forKey: .learnSection))
    }

    static func make(
        selectedTab: NativeDemoTab,
        objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute],
        flow: NativeDemoFlow,
        learnSection: NativeDemoLearnSection? = nil
    ) throws -> Self {
        let state = Self(
            selectedTab: selectedTab, objectivePath: objectivePath, catalogPath: catalogPath,
            learnSection: learnSection)
        try state.validate(for: flow)
        return state
    }

    static func restore(_ data: Data, for flow: NativeDemoFlow) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let state = try JSONDecoder().decode(Self.self, from: data)
        try state.validate(for: flow)
        return state
    }

    func resumingExercise(for flow: NativeDemoFlow) throws -> Self {
        try Self.make(
            selectedTab: .objective, objectivePath: [.exercise],
            catalogPath: catalogPath, flow: flow)
    }

    private func validate(for flow: NativeDemoFlow) throws {
        let objectiveRoutesAreValid =
            objectivePath.count <= 1
            && objectivePath.allSatisfy { $0 == .exercise || $0 == .preparation }
            && (objectivePath.isEmpty || flow.objective != nil)
        let catalogRoutesAreValid =
            catalogPath.count <= 1
            && catalogPath.allSatisfy {
                if case .goalDetail = $0 { true } else { false }
            }
        let sectionMatchesTab =
            (selectedTab != .objective || learnSection == .myLearning)
            && (selectedTab != .catalog || learnSection == .explore)
        guard objectiveRoutesAreValid, catalogRoutesAreValid, sectionMatchesTab else {
            throw InvalidSnapshot.inconsistentRoute
        }
    }
}

struct NativeDemoSnapshot: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, unsupportedSchema }

    private static let maximumEncodedBytes = 8_192
    let schema: Int
    let flow: NativeDemoFlow
    let navigation: NativeDemoNavigationState

    static func make(
        flow: NativeDemoFlow, navigation: NativeDemoNavigationState
    ) throws -> Self {
        let validatedNavigation = try NativeDemoNavigationState.make(
            selectedTab: navigation.selectedTab,
            objectivePath: navigation.objectivePath,
            catalogPath: navigation.catalogPath,
            flow: flow, learnSection: navigation.learnSection)
        return Self(schema: 1, flow: flow, navigation: validatedNavigation)
    }

    static func restore(_ data: Data) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let decoder = JSONDecoder()
        do {
            let snapshot = try decoder.decode(Self.self, from: data)
            guard snapshot.schema == 1 else {
                throw InvalidSnapshot.unsupportedSchema
            }
            return try make(flow: snapshot.flow, navigation: snapshot.navigation)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "schema" {
            let legacyFlow = try NativeDemoFlow.restore(data)
            let legacyNavigation = try NativeDemoNavigationState.make(
                selectedTab: legacyFlow.objective == nil ? .catalog : .objective,
                objectivePath: [], catalogPath: [], flow: legacyFlow)
            return try make(flow: legacyFlow, navigation: legacyNavigation)
        }
    }
}

#if canImport(SwiftUI)
    private struct NativeRoot: View {
        @Bindable var model: NativeModel
        @State private var selectedTrack: String?
        @State private var selectedLesson: String?

        var body: some View {
            Group {
                if model.profile == nil {
                    connection
                } else {
                    NavigationSplitView {
                        List(selection: $selectedTrack) {
                            Section("Certifications") {
                                ForEach(model.tracks) { track in
                                    NavigationLink(value: track.id) {
                                        VStack(alignment: .leading) {
                                            Text(track.code).font(.headline)
                                            Text(track.title).foregroundStyle(.secondary)
                                        }
                                    }
                                    .disabled(!track.learningAvailable)
                                }
                            }
                            if model.tracks.isEmpty {
                                Text("No certifications available.")
                            }
                        }
                        .disabled(model.busy)
                        .navigationTitle("Library")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Disconnect", systemImage: "person.crop.circle.badge.xmark")
                                {
                                    Task { await model.disconnect() }
                                }
                            }
                        }
                    } content: {
                        path
                    } detail: {
                        session
                    }
                    .onChange(of: selectedTrack) { _, id in
                        selectedLesson = nil
                        guard let track = model.tracks.first(where: { $0.id == id }) else { return }
                        Task { await model.loadPath(track) }
                    }
                    .onChange(of: selectedLesson) { _, id in
                        guard
                            let node = model.path?.units.flatMap(\.lessons).first(where: {
                                $0.id == id
                            }
                            )
                        else { return }
                        Task { await model.loadLesson(node) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.busy {
                    ProgressView("Operation in progress…")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
            .alert(
                "Operation not confirmed",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task { await model.restore() }
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        Text("Connect only a test account to the development API.")
                        Text(
                            "This developer connector is not production sign-in. No Apple account or new identity is created."
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · development")
                    }
                    Section("Test connection") {
                        TextField("HTTPS API URL", text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField("Test account access token", text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button("Connect the test account") { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            "The token stays in this device’s secure vault. Pending answers are never graded locally."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
            }
        }

        private var path: some View {
            List(selection: $selectedLesson) {
                if let path = model.path {
                    Section {
                        LabeledContent("Confirmed readiness", value: "\(path.readinessScore) %")
                        Button("Refresh progress", systemImage: "arrow.clockwise") {
                            Task { await model.refreshProgress() }
                        }
                        .disabled(model.busy)
                    }
                    ForEach(path.units) { unit in
                        Section(unit.title) {
                            ForEach(unit.lessons) { lesson in
                                NavigationLink(value: lesson.id) {
                                    Label {
                                        VStack(alignment: .leading) {
                                            Text(lesson.title)
                                            Text("\(lesson.estMinutes) min").foregroundStyle(
                                                .secondary)
                                        }
                                    } icon: {
                                        Image(systemName: lesson.canOpen ? "book" : "lock")
                                    }
                                }
                                .disabled(!lesson.canOpen || model.busy)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Choose a certification", systemImage: "books.vertical",
                        description: Text("Its learning path will load from the server.")
                    )
                }
                if !model.queue.isEmpty {
                    Section("Saved answers") {
                        ForEach(model.queue) { saved in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(saved.lessonId).font(.headline)
                                switch saved.status {
                                case .pendingCorrection:
                                    Label("Correction pending", systemImage: "clock")
                                    Button("Retry correction") {
                                        Task { await model.retry(saved) }
                                    }
                                    .disabled(model.busy)
                                case .corrected:
                                    if let result = saved.result {
                                        Text("Confirmed score: \(result.scorePct) %")
                                        ForEach(result.results) { item in
                                            Text(item.explanation)
                                        }
                                    }
                                case .failed:
                                    Label(
                                        "Submission rejected · answers preserved",
                                        systemImage: "exclamationmark.triangle")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(model.path?.trackName ?? "Learning path")
        }

        private var session: some View {
            Group {
                if let lesson = model.lesson {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(lesson.title).font(.title).bold()
                            Text(
                                "Answer the questions, then submit your answers for server correction."
                            )
                            .foregroundStyle(.secondary)
                            ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                                if let title = block.title { Text(title).font(.headline) }
                                if let body = block.body {
                                    Text(.init(body)).textSelection(.enabled)
                                }
                                if let code = block.code {
                                    Text(code).font(.body.monospaced()).textSelection(.enabled)
                                }
                                if let question = block.check {
                                    questionView(question)
                                }
                            }
                            if let outcome = model.outcome {
                                switch outcome {
                                case .pendingCorrection:
                                    Label(
                                        "Answers saved. Correction will be requested after reconnecting.",
                                        systemImage: "clock"
                                    )
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    Text("Confirmed score: \(result.scorePct) %").font(.title2)
                                        .bold()
                                    Text("Confirmed XP: \(result.rewards.xpEarned)")
                                    ForEach(result.results) { item in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label(
                                                item.correct ? "Correct answer" : "Review needed",
                                                systemImage: item.correct
                                                    ? "checkmark.circle" : "book"
                                            )
                                            Text(.init(item.explanation)).textSelection(.enabled)
                                        }
                                    }
                                }
                            } else {
                                Button("Submit for correction") { Task { await model.submit() } }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .disabled(!model.canSubmit)
                                    .accessibilityIdentifier("submit-for-correction")
                            }
                        }
                        .padding()
                        .frame(maxWidth: 700, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        "One session at a time", systemImage: "book",
                        description: Text("Choose an activity in the learning path.")
                    )
                }
            }
            .navigationTitle("Practice")
        }

        private func questionView(_ question: QuizItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(.init(question.stem)).font(.headline)
                ForEach(question.options) { option in
                    Button {
                        model.select(option, question: question)
                    } label: {
                        Label(
                            option.label,
                            systemImage: model.selections[question.id] == option.id
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.outcome != nil || model.busy)
                    .accessibilityAddTraits(
                        model.selections[question.id] == option.id ? .isSelected : [])
                }
            }
            .onAppear { model.questionAppeared(question.id) }
        }
    }
#endif
