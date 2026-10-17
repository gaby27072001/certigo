import CertigoData

import CertigoDomain

import SwiftUI

@main
struct CertigoNativeApp: App {
    @State private var model = NativeModel()

    var body: some Scene {
        WindowGroup {
            NativeRoot(model: model)
                .tint(Color(red: 59 / 255, green: 53 / 255, blue: 242 / 255))
        }
    }
}
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
                            Button("Déconnecter", systemImage: "person.crop.circle.badge.xmark") {
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
                        let node = model.path?.units.flatMap(\.lessons).first(where: { $0.id == id }
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
                                        Text("\(lesson.estMinutes) min").foregroundStyle(.secondary)
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
                                Text("Score confirmé : \(result.scorePct) %").font(.title2).bold()
                                Text("XP confirmés : \(result.rewards.xpEarned)")
                                ForEach(result.results) { item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            item.correct ? "Réponse correcte" : "À revoir",
                                            systemImage: item.correct ? "checkmark.circle" : "book"
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
