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
                        Text("Une question. Une idée plus claire.")
                            .font(.largeTitle.bold())
                            .padding(.vertical, 16)
                        Text("Découvrez le premier parcours natif de Certigo.")
                            .foregroundStyle(.secondary)
                        Button("Découvrir la démo", systemImage: "play.circle") { showDemo = true }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("open-native-demo")
                    }
                    Section("Démonstration isolée") {
                        Text(
                            "Les objectifs, réponses et explications sont fictifs. Aucun compte, réseau ou résultat réel n’est utilisé."
                        )
                    }
                    Section("Développement") {
                        Button(
                            "Ouvrir le connecteur API de test",
                            systemImage: "wrench.and.screwdriver"
                        ) {
                            showDeveloper = true
                        }
                        .frame(minHeight: 44)
                        Text(
                            "Réservé aux comptes de test. Ce n’est pas la connexion de production."
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
                        Text("Connecteur développeur").font(.subheadline)
                        Spacer()
                        Button("Fermer") { dismiss() }
                    }
                    .padding()
                    .background(.background)
                }
        }
    }

    private enum DemoCatalogScenario: String, CaseIterable {
        case ready = "Disponible"
        case loading = "Chargement"
        case empty = "Vide"
        case error = "Erreur"
    }

    private struct NativeDemoRoot: View {
        @Environment(\.dismiss) private var dismiss
        @AppStorage("certigo.native-design-demo.v1") private var savedState = ""
        @State private var flow = NativeDemoFlow()
        @State private var tab = NativeDemoTab.objective
        @State private var objectivePath: [NativeDemoRoute] = []
        @State private var catalogPath: [NativeDemoRoute] = []
        @State private var scenario = DemoCatalogScenario.ready
        @State private var offline = false
        @State private var issue: String?
        @State private var showScenarios = false
        @State private var showReset = false
        @State private var restored = false

        var body: some View {
            TabView(selection: $tab) {
                NavigationStack(path: $objectivePath) {
                    objective.navigationDestination(for: NativeDemoRoute.self) { route in
                        destination(for: route)
                    }
                }
                .tabItem { Label("Objectif", systemImage: "scope") }.tag(NativeDemoTab.objective)
                NavigationStack(path: $catalogPath) {
                    catalog.navigationDestination(for: NativeDemoRoute.self) { route in
                        destination(for: route)
                    }
                }
                .tabItem { Label("Explorer", systemImage: "square.grid.2x2") }.tag(
                    NativeDemoTab.catalog)
                NavigationStack { followUp }
                    .tabItem { Label("Suivi", systemImage: "clock.arrow.circlepath") }.tag(
                        NativeDemoTab.followUp)
            }
            .tint(NativePrism.tint)
            .sheet(isPresented: $showScenarios) {
                NavigationStack {
                    Form {
                        Section("États du catalogue · simulation") {
                            Picker("Catalogue", selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }
                            Toggle("Simuler le mode hors ligne", isOn: $offline)
                        }
                        Section {
                            Text(
                                "Ces réglages ne modifient ni le réseau de l’appareil ni un serveur."
                            )
                        }
                    }
                    .navigationTitle("Scénarios de démo")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Terminé") { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Effacer uniquement la reprise de démonstration ?", isPresented: $showReset
            ) {
                Button("Réinitialiser la démo", role: .destructive) {
                    flow = NativeDemoFlow()
                    objectivePath = []
                    catalogPath = []
                    tab = .objective
                    scenario = .ready
                    offline = false
                    savedState = ""
                }
            }
            .alert("Reprise de démo indisponible", isPresented: issuePresented) {
                Button("Compris", role: .cancel) { issue = nil }
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
                        objectivePath = navigation.objectivePath
                        catalogPath = navigation.catalogPath
                    }
                } catch {
                    issue =
                        "La reprise de démonstration est illisible. Réinitialisez uniquement la démo dans les options."
                }
            }
            .onChange(of: flow) { _, value in
                persistDemoSnapshot(flow: value)
            }
            .onChange(of: tab) { _, _ in persistDemoSnapshot() }
            .onChange(of: objectivePath) { _, _ in persistDemoSnapshot() }
            .onChange(of: catalogPath) { _, _ in persistDemoSnapshot() }
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
                    catalogPath: catalogPath, flow: flowToPersist)
                let snapshot = try NativeDemoSnapshot.make(
                    flow: flowToPersist, navigation: navigation)
                savedState = String(
                    decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
            } catch {
                issue =
                    "La reprise de démonstration n’a pas pu être enregistrée. Le parcours reste ouvert."
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
                tab = navigation.selectedTab
            } catch {
                issue =
                    "La question ne peut pas être rouverte. Choisissez un objectif dans Explorer."
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    demoNotice
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.rawValue).font(.largeTitle.bold())
                            Text(goal.title).font(.title2.weight(.semibold))
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
                            Text("L’atelier des décisions").font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                "Une situation à lire, un choix à faire, une explication à comprendre."
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                "Contenu inventé · pas un cours publié",
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button("Changer d’objectif", systemImage: "square.grid.2x2") {
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button("Voir le suivi fictif", systemImage: "clock.arrow.circlepath") {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            "Votre prochain objectif",
                            systemImage: "scope",
                            description: Text(
                                "Explorez deux situations inventées. Aucun compte ni résultat réel n’est nécessaire."
                            )
                        )
                        DemoPrimaryButton(title: "Explorer les objectifs", symbol: "arrow.right") {
                            tab = .catalog
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Votre objectif")
            .toolbar { demoToolbar }
        }

        private var catalog: some View {
            List {
                Section { demoNotice }
                switch scenario {
                case .ready:
                    Section("Ateliers de démonstration") {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.rawValue).font(.headline)
                                        Text(goal.title).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("1 situation fictive · 1 question")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel("Objectif sélectionné")
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
                                Text(goal.title).font(.headline)
                                Text("Une situation à découvrir").font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("Chargement simulé…", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button("Terminer le chargement simulé") { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            "Aucun objectif dans cet exemple", systemImage: "books.vertical",
                            description: Text("Le catalogue vide est un scénario de démonstration.")
                        )
                        Button("Afficher les objectifs fictifs") { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            "Catalogue indisponible · simulation",
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                "Votre reprise fictive est conservée. Aucun serveur n’est appelé."))
                        Button("Réessayer la simulation", systemImage: "arrow.clockwise") {
                            scenario = .ready
                        }
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Explorer")
            .toolbar { demoToolbar }
        }

        private func goalDetail(_ goal: NativeDemoFlow.Objective) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Text(goal.rawValue).font(.largeTitle.bold()).foregroundStyle(NativePrism.tint)
                    Text(goal.title).font(.title2.bold())
                    Text(
                        "Un scénario court pour découvrir le parcours natif. Ce n’est pas un catalogue publié."
                    )
                    DemoReadingSection(title: "La décision à explorer", text: goal.practice.intent)
                    DemoReadingSection(title: "La situation fictive", text: goal.practice.situation)
                    Label("Lire, choisir, comprendre · sans note", systemImage: "text.bubble")
                    Label("Reprise locale de la démo", systemImage: "clock.arrow.circlepath")
                    DemoPrimaryButton(title: "Choisir cet objectif", symbol: "scope") {
                        flow.choose(goal)
                        catalogPath = []
                        objectivePath = []
                        tab = .objective
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Choisir un objectif").navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(current: .situation)
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(title: "La situation", text: practice.situation)
                        DemoReadingSection(title: "Votre mission", text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: "Avant de choisir",
                            text:
                                "Repérez ce que l’équipe veut prendre en charge et ce qu’elle veut déléguer. La question porte sur cette limite, pas sur un nom de fournisseur."
                        )
                        DemoPrimaryButton(title: "Passer à la question", symbol: "arrow.right") {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Mise en situation").navigationBarTitleDisplayMode(.inline)
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
                                    ? "Choisissez une réponse" : "Réponse sélectionnée",
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
                                            ? "Sélectionnée" : "Non sélectionnée"
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text("Votre choix reste modifiable avant l’envoi simulé.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "Enregistrer la réponse fictive", symbol: "paperplane"
                            ) {
                                flow.submit()
                            }
                            .disabled(!flow.canSubmit)
                            .accessibilityHint("Choisissez une réponse avant de continuer.")
                            .accessibilityIdentifier("demo-submit")
                        case .pending:
                            Label {
                                Text("Réponse fictive en attente")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text("Votre choix est conservé dans la démo.")
                                .font(.headline)
                            selectedAnswer
                            Text(
                                "Aucun verdict, score ou récompense n’est calculé sur cet appareil."
                            )
                            if offline {
                                Label("Hors ligne · simulation", systemImage: "wifi.slash")
                                Text(
                                    "La réponse de démonstration reste en attente. Le scénario hors ligne empêche la suite de la simulation."
                                )
                                DemoPrimaryButton(
                                    title: "Désactiver le scénario hors ligne",
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    "La prochaine action simule une réponse serveur. Elle ne contacte aucune API."
                                )
                                DemoPrimaryButton(
                                    title: "Simuler l’explication fictive",
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                "Explication fictive affichée · sans verdict",
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: "La contrainte décisive", text: practice.constraint)
                            DemoReadingSection(
                                title: "Comprendre la décision", text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoReadingSection(title: "À retenir", text: practice.takeaway)
                            Text(
                                "Ce texte est une fixture de design, pas la correction d’une question publiée. Il est affiché quel que soit votre choix : la démo ne vous attribue ni verdict ni score."
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "Consulter le suivi fictif",
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                "Recommencer la question fictive",
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
            .navigationTitle("Révision · démo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Scénarios", systemImage: "slider.horizontal.3") { showScenarios = true }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Votre choix fictif").font(.headline)
                if let selection = flow.selection {
                    Text(NativeDemoFlow.options[selection])
                }
            }
            .accessibilityElement(children: .combine)
        }

        private var followUp: some View {
            List {
                Section { demoNotice }
                Section("Reprise de démonstration") {
                    if let goal = flow.objective {
                        Text(goal.title).font(.headline)
                        Button(action: resumeExercise) {
                            Label(flow.resumeLabel, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary)
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text("Cette reprise n’est pas une progression de certification.")
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            "Tout commence par un objectif", systemImage: "scope",
                            description: Text("Aucune activité fictive enregistrée."))
                        Button("Explorer les objectifs") { tab = .catalog }
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Suivi")
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
                case decision = "Décision"
                case explanation = "Explication"
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
                    "Étape actuelle : \(current.rawValue). Situation, décision, explication.")
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
                    Text("Qui prend en charge quoi ?").font(.headline)
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
            Label("Démo · données et résultats fictifs", systemImage: "testtube.2")
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("synthetic-demo-notice")
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button("Fermer") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Scénarios de démonstration", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        "Réinitialiser la démo", systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label("Options de démo", systemImage: "ellipsis.circle")
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

    #Preview("Objectif · démonstration") { NativeDemoRoot() }
#endif

// A demo-only state machine: no API identity, scoring, answer keys, rewards or production progress.
struct NativeDemoFlow: Codable, Equatable {
    enum Objective: String, Codable, CaseIterable {
        case fundamentals = "Cloud · découverte"
        case operations = "Cloud · exploitation"

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
        startRoute == .preparation ? "Découvrir la situation" : resumeLabel
    }
    var activitySummary: String {
        switch phase {
        case .answering:
            selection == nil
                ? "Une situation à découvrir · sans note"
                : "Un choix modifiable · pas encore envoyé"
        case .pending: "Réponse fictive en attente · aucun résultat confirmé"
        case .reviewed: "Explication fictive consultable · aucun verdict"
        }
    }
    var resumeLabel: String {
        switch phase {
        case .answering: selection == nil ? "Commencer une question" : "Reprendre votre choix"
        case .pending: "Reprendre la réponse en attente"
        case .reviewed: "Relire l’explication fictive"
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

enum NativeDemoTab: String, Codable, CaseIterable, Hashable {
    case objective, catalog, followUp
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

    static func make(
        selectedTab: NativeDemoTab,
        objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute],
        flow: NativeDemoFlow
    ) throws -> Self {
        let state = Self(
            selectedTab: selectedTab, objectivePath: objectivePath, catalogPath: catalogPath)
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
        guard objectiveRoutesAreValid, catalogRoutesAreValid else {
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
            flow: flow)
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
                selectedTab: .objective, objectivePath: [], catalogPath: [], flow: legacyFlow)
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
                                Text("Aucune certification disponible.")
                            }
                        }
                        .disabled(model.busy)
                        .navigationTitle("Bibliothèque")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Déconnecter", systemImage: "person.crop.circle.badge.xmark")
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
                    ProgressView("Opération en cours…")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
            .alert(
                "Opération non confirmée",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("Compris", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task { await model.restore() }
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        Text("Connectez uniquement un compte de test à l’API de développement.")
                        Text(
                            "Ce connecteur développeur n’est pas le parcours de connexion de la future app. Aucun compte Apple ni nouvelle identité n’est créé."
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · développement")
                    }
                    Section("Connexion de test") {
                        TextField("URL API HTTPS", text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField("Jeton d’accès du compte de test", text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button("Connecter le compte de test") { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            "Le jeton reste dans le coffre sécurisé de cet appareil. Les réponses en attente ne sont jamais corrigées localement."
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
                        LabeledContent("Préparation confirmée", value: "\(path.readinessScore) %")
                        Button("Actualiser la progression", systemImage: "arrow.clockwise") {
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
                        "Choisissez une certification", systemImage: "books.vertical",
                        description: Text("Son parcours sera chargé depuis le serveur.")
                    )
                }
                if !model.queue.isEmpty {
                    Section("Réponses enregistrées") {
                        ForEach(model.queue) { saved in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(saved.lessonId).font(.headline)
                                switch saved.status {
                                case .pendingCorrection:
                                    Label("Correction en attente", systemImage: "clock")
                                    Button("Réessayer la correction") {
                                        Task { await model.retry(saved) }
                                    }
                                    .disabled(model.busy)
                                case .corrected:
                                    if let result = saved.result {
                                        Text("Score confirmé : \(result.scorePct) %")
                                        ForEach(result.results) { item in
                                            Text(item.explanation)
                                        }
                                    }
                                case .failed:
                                    Label(
                                        "Envoi refusé · réponses conservées",
                                        systemImage: "exclamationmark.triangle")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(model.path?.trackName ?? "Parcours")
        }

        private var session: some View {
            Group {
                if let lesson = model.lesson {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(lesson.title).font(.title).bold()
                            Text(
                                "Répondez aux questions, puis envoyez vos réponses pour obtenir la correction du serveur."
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
                                        "Réponses enregistrées. Correction à la reconnexion.",
                                        systemImage: "clock"
                                    )
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    Text("Score confirmé : \(result.scorePct) %").font(.title2)
                                        .bold()
                                    Text("XP confirmés : \(result.rewards.xpEarned)")
                                    ForEach(result.results) { item in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label(
                                                item.correct ? "Réponse correcte" : "À revoir",
                                                systemImage: item.correct
                                                    ? "checkmark.circle" : "book"
                                            )
                                            Text(.init(item.explanation)).textSelection(.enabled)
                                        }
                                    }
                                }
                            } else {
                                Button("Envoyer pour correction") { Task { await model.submit() } }
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
                        "Une session à la fois", systemImage: "book",
                        description: Text("Choisissez une activité dans le parcours.")
                    )
                }
            }
            .navigationTitle("Révision")
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
