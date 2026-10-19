#if canImport(SwiftUI)
    import CertigoDomain
    import SwiftUI

    struct NativeEditorialPilotView: View {
        @Environment(\.dismiss) private var dismiss
        @Bindable var model: NativeModel
        @State private var issue: String?

        var body: some View {
            NavigationStack {
                Group {
                    if let snapshot = model.editorialPilot {
                        pilotContent(snapshot)
                    } else if issue != nil {
                        ContentUnavailableView(
                            "Le pilote n’est pas disponible",
                            systemImage: "book.closed",
                            description: Text(issue ?? "Réessayez lorsque le réseau sera disponible.")
                        )
                        .overlay(alignment: .bottom) {
                            Button("Réessayer") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                                .padding()
                        }
                    } else {
                        ProgressView("Chargement du pilote…")
                    }
                }
                .navigationTitle("Pilote éditorial")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
                .task { await load() }
                .alert(
                    "Historique non confirmé",
                    isPresented: Binding(
                        get: { issue != nil && model.editorialPilot != nil },
                        set: { if !$0 { issue = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { issue = nil }
                } message: {
                    Text(issue ?? "")
                }
            }
        }

        @ViewBuilder
        private func pilotContent(_ snapshot: EditorialPilotSnapshot) -> some View {
            List {
                Section {
                    Text(snapshot.pilot.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Label("Apprentissage, pas certification", systemImage: "book")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    LabeledContent("Langue", value: "Français (France)")
                    LabeledContent("Durée estimée", value: "\(snapshot.pilot.estimatedMinutes) min")
                    LabeledContent("Sources consultées le", value: snapshot.pilot.asOf)
                    Text(snapshot.pilot.audience)
                    Text(snapshot.pilot.prerequisites)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Pilote original · brouillon éditorial")
                } footer: {
                    Text(snapshot.pilot.scope)
                }

                if let lastLessonId = model.pilotHistory?.lastLessonId,
                    let lastLesson = snapshot.pilot.lessons.first(where: { $0.id == lastLessonId })
                {
                    Section("Reprendre") {
                        NavigationLink(value: lastLesson.id) {
                            Label(lastLesson.title, systemImage: "arrow.counterclockwise")
                        }
                    }
                }

                Section("Trois leçons") {
                    ForEach(snapshot.pilot.lessons) { lesson in
                        NavigationLink(value: lesson.id) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(lesson.title).font(.headline)
                                Text(lesson.objective)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                if let progress = progress(for: lesson, in: model.pilotHistory) {
                                    Text(progress.markedReadAt.map {
                                        "Déclarée lue · \(date($0))"
                                    } ?? "Consultée · \(date(progress.lastAccessedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { lessonId in
                if let lesson = snapshot.pilot.lessons.first(where: { $0.id == lessonId }) {
                    NativeEditorialPilotLessonView(
                        lesson: lesson,
                        sources: snapshot.pilot.sources,
                        model: model,
                        issue: $issue
                    )
                } else {
                    ContentUnavailableView("Leçon indisponible", systemImage: "book.closed")
                }
            }
        }

        private func progress(
            for lesson: EditorialPilotLesson,
            in history: PilotHistory?
        ) -> PilotLessonProgress? {
            history?.lessons.first(where: { $0.lessonId == lesson.id })
        }

        private func load() async {
            issue = nil
            do {
                try await model.loadEditorialPilot()
            } catch {
                issue = "Le chargement ou la vérification du contenu a échoué. Réessayez."
            }
        }
    }

    private struct NativeEditorialPilotLessonView: View {
        let lesson: EditorialPilotLesson
        let sources: [EditorialPilotSource]
        @Bindable var model: NativeModel
        @Binding var issue: String?
        @State private var accessRecorded = false

        private var progress: PilotLessonProgress? {
            model.pilotHistory?.lessons.first(where: { $0.lessonId == lesson.id })
        }

        var body: some View {
            List {
                Section {
                    Text(lesson.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    NativeLessonAudioControls(
                        content: NativeLessonReadingContent(
                            editorialTitle: lesson.title,
                            objective: lesson.objective,
                            hook: lesson.hook,
                            keyIdeas: lesson.keyIdeas,
                            exampleSituation: lesson.workedExample.situation,
                            exampleSteps: lesson.workedExample.steps,
                            exampleDecision: lesson.workedExample.decision,
                            recap: lesson.recap
                        ),
                        ownerID: model.profile?.id
                    )
                    .id(lesson.id)
                    Text(lesson.objective)
                        .font(.headline)
                    Text(lesson.hook)
                        .foregroundStyle(.secondary)
                    LabeledContent("Durée estimée", value: "\(lesson.estimatedMinutes) min")
                }

                Section("Idées clés") {
                    ForEach(Array(lesson.keyIdeas.enumerated()), id: \.offset) { item in
                        Label(item.element, systemImage: "lightbulb")
                    }
                }

                Section("Exemple résolu") {
                    Text(lesson.workedExample.situation)
                    ForEach(Array(lesson.workedExample.steps.enumerated()), id: \.offset) { item in
                        LabeledContent("\(item.offset + 1)", value: item.element)
                    }
                    Text(lesson.workedExample.decision)
                        .fontWeight(.medium)
                }

                Section("Pratique formative · sans réponse enregistrée") {
                    Text(lesson.practice.prompt)
                    ForEach(Array(lesson.practice.successCriteria.enumerated()), id: \.offset) {
                        item in
                        Label(item.element, systemImage: "checkmark.circle")
                    }
                    Text(lesson.practice.feedback)
                        .foregroundStyle(.secondary)
                }

                Section("À retenir") {
                    Text(lesson.recap)
                }

                Section("Sources et limites") {
                    ForEach(sources.filter { lesson.sourceIDs.contains($0.id) }) { source in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(source.title).font(.headline)
                            Text("Consultée le \(source.checkedOn)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(source.supports)
                            Text(source.limits)
                                .foregroundStyle(.secondary)
                            if let url = URL(string: source.url) {
                                Link("Ouvrir la source", destination: url)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if let markedReadAt = progress?.markedReadAt {
                        Label(
                            "Vous avez déclaré cette leçon lue le \(date(markedReadAt)).",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Button("Marquer comme lue") {
                            Task { await markRead() }
                        }
                        .disabled(model.busy || !accessRecorded)
                        .accessibilityIdentifier("mark-editorial-pilot-lesson-read")
                        Text("Cette déclaration ne mesure ni maîtrise ni résultat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !accessRecorded {
                        Button("Réessayer la synchronisation de la consultation") {
                            Task { await recordAccess() }
                        }
                        .disabled(model.busy)
                    }
                } header: {
                    Text("Votre historique")
                }
            }
            .navigationTitle("Leçon")
            .navigationBarTitleDisplayMode(.inline)
            .task { await recordAccess() }
        }

        private func recordAccess() async {
            issue = nil
            do {
                try await model.accessEditorialPilotLesson(lesson.id)
                accessRecorded = true
            } catch {
                issue = "La consultation n’a pas été synchronisée. Aucune déclaration de lecture n’a été enregistrée."
            }
        }

        private func markRead() async {
            issue = nil
            do {
                try await model.markEditorialPilotLessonRead(lesson.id)
            } catch {
                issue = "La déclaration n’a pas été confirmée par le serveur. Réessayez."
            }
        }
    }

    private func date(_ value: Date) -> String {
        value.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .locale(Locale(identifier: "fr-FR"))
        )
    }
#endif
