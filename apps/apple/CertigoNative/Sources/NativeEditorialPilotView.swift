#if canImport(SwiftUI)
    import CertigoDomain
    import SwiftUI

    struct NativeEditorialPilotView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @Bindable var model: NativeModel
        let requestedLessonID: String?
        @State private var issue: String?
        @State private var navigationPath: [String] = []
        @State private var requestedLessonResolutionAttempted = false
        @State private var requestedLessonUnavailable = false

        init(model: NativeModel, requestedLessonID: String? = nil) {
            self.model = model
            self.requestedLessonID = requestedLessonID
        }

        var body: some View {
            NavigationStack(path: $navigationPath) {
                Group {
                    if let snapshot = model.editorialPilot {
                        if requestedLessonUnavailable {
                            ContentUnavailableView(
                                "Linked lesson unavailable",
                                systemImage: "book.closed",
                                description: Text(
                                    "This lesson is not present in the current pilot version."
                                )
                            )
                        } else {
                            pilotContent(snapshot)
                        }
                    } else if issue != nil {
                        ContentUnavailableView(
                            "Editorial pilot unavailable",
                            systemImage: "book.closed",
                            description: Text(
                                issue ?? "Try again when the network is available.")
                        )
                        .overlay(alignment: .bottom) {
                            Button(copy.retry) { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                                .padding()
                        }
                    } else {
                        ProgressView(copy.loading)
                    }
                }
                .navigationTitle("Editorial pilot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy[.done]) { dismiss() }
                    }
                }
                .task { await load() }
                .alert(
                    "History not confirmed",
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
            NativeReadingPage {
                NativeEntryHeading(
                    title: snapshot.pilot.title,
                    message: "Original French draft · learning, not certification.")
                NativeReadingSection(title: "Before you start") {
                    Text(copy.contentLanguageNote)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label("Learning, not certification", systemImage: "book")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    LabeledContent("Content language", value: "French (France)")
                    LabeledContent(
                        "Estimated duration", value: "\(snapshot.pilot.estimatedMinutes) min")
                    LabeledContent("Sources checked on", value: snapshot.pilot.asOf)
                    Text(snapshot.pilot.audience)
                    Text(snapshot.pilot.prerequisites)
                        .foregroundStyle(.secondary)
                    Text(snapshot.pilot.scope).font(.footnote).foregroundStyle(.secondary)
                }

                if let lastLessonId = model.pilotHistory?.lastLessonId,
                    let lastLesson = snapshot.pilot.lessons.first(where: { $0.id == lastLessonId })
                {
                    NativeReadingSection(title: copy.resume) {
                        NavigationLink(value: lastLesson.id) {
                            Label(lastLesson.title, systemImage: "arrow.counterclockwise")
                                .frame(minHeight: 44)
                        }
                    }
                }

                NativeReadingSection(title: "Lessons") {
                    ForEach(snapshot.pilot.lessons) { lesson in
                        NavigationLink(value: lesson.id) {
                            NativeReadingCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(lesson.title).font(.headline).foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary).accessibilityHidden(true)
                                    }
                                    Text(lesson.objective)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let progress = progress(for: lesson, in: model.pilotHistory)
                                    {
                                        Text(
                                            progress.markedReadAt.map {
                                                "Marked as read · \(date($0, locale: copy.language.locale))"
                                            }
                                                ?? "Last opened · \(date(progress.lastAccessedAt, locale: copy.language.locale))"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .buttonStyle(.plain)
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
                    ContentUnavailableView("Lesson unavailable", systemImage: "book.closed")
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
                guard let requestedLessonID,
                    !requestedLessonResolutionAttempted
                else { return }
                requestedLessonResolutionAttempted = true
                guard
                    model.editorialPilot?.pilot.lessons.contains(where: {
                        $0.id == requestedLessonID
                    }) == true
                else {
                    requestedLessonUnavailable = true
                    return
                }
                navigationPath = [requestedLessonID]
            } catch {
                issue = "Content loading or verification failed. Please retry."
            }
        }
    }

    private struct NativeEditorialPilotLessonView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let lesson: EditorialPilotLesson
        let sources: [EditorialPilotSource]
        @Bindable var model: NativeModel
        @Binding var issue: String?
        @State private var accessRecorded = false

        private var progress: PilotLessonProgress? {
            model.pilotHistory?.lessons.first(where: { $0.lessonId == lesson.id })
        }

        var body: some View {
            ScrollViewReader { reader in
                NativeReadingPage {
                    NativeReadingSection(title: "Understand the situation") {
                        Text(lesson.title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("French editorial content · original source language")
                            .font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("Read lesson aloud") {
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
                        }
                        .frame(minHeight: 44)
                        Text(lesson.objective)
                            .font(.headline)
                        Text(lesson.hook)
                            .foregroundStyle(.secondary)
                        LabeledContent(
                            "Estimated duration", value: "\(lesson.estimatedMinutes) min")
                    }
                    .id("editorial-reading-start")

                    NativeReadingSection(title: "Key ideas") {
                        ForEach(Array(lesson.keyIdeas.enumerated()), id: \.offset) { item in
                            Label(item.element, systemImage: "lightbulb")
                        }
                    }

                    NativeReadingSection(title: "Worked example") {
                        NativeReadingCard {
                            Text(lesson.workedExample.situation)
                            ForEach(Array(lesson.workedExample.steps.enumerated()), id: \.offset) {
                                item in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("\(item.offset + 1).").monospacedDigit()
                                    Text(item.element)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            Text(lesson.workedExample.decision)
                                .fontWeight(.medium)
                        }
                    }

                    NativeReadingSection(title: "Self-check · no answer recorded") {
                        Text(lesson.practice.prompt)
                        ForEach(Array(lesson.practice.successCriteria.enumerated()), id: \.offset) {
                            item in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(item.offset + 1).").monospacedDigit()
                                Text(item.element)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Text(lesson.practice.feedback)
                            .foregroundStyle(.secondary)
                    }
                    .id("editorial-practice")

                    NativeReadingSection(title: "Takeaway") {
                        Text(lesson.recap)
                            .font(.headline)
                    }

                    NativeReadingSection(title: "Sources & limits") {
                        ForEach(sources.filter { lesson.sourceIDs.contains($0.id) }) { source in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(source.title).font(.headline)
                                Text("Checked on \(source.checkedOn)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(source.supports)
                                Text(source.limits)
                                    .foregroundStyle(.secondary)
                                if let url = URL(string: source.url) {
                                    Link("Open source", destination: url)
                                        .frame(minHeight: 44)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    NativeReadingSection(title: "Your reading history") {
                        if let markedReadAt = progress?.markedReadAt {
                            Label(
                                "You marked this lesson as read on \(date(markedReadAt, locale: copy.language.locale)).",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.secondary)
                        } else {
                            NativePrimaryButton(title: "Mark as read", symbol: "checkmark") {
                                Task { await markRead() }
                            }
                            .disabled(model.busy || !accessRecorded)
                            .accessibilityIdentifier("mark-editorial-pilot-lesson-read")
                            Text("This declaration does not measure mastery or performance.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if !accessRecorded {
                            Button(copy.retry) {
                                Task { await recordAccess() }
                            }
                            .frame(minHeight: 44)
                            .disabled(model.busy)
                        }
                    }
                    NativeReadingSection(title: "Revisit the lesson") {
                        Button("Read again", systemImage: "text.book.closed") {
                            reader.scrollTo("editorial-reading-start", anchor: .top)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("read-editorial-lesson-again")
                        Button("Revisit formative practice", systemImage: "pencil") {
                            reader.scrollTo("editorial-practice", anchor: .top)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("review-editorial-practice")
                        Text(
                            "Re-reading does not change your history. This exercise submits no answer and awards no score or XP."
                        )
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Lesson")
                .navigationBarTitleDisplayMode(.inline)
                .task { await recordAccess() }
            }
        }

        private func recordAccess() async {
            issue = nil
            do {
                try await model.accessEditorialPilotLesson(lesson.id)
                accessRecorded = true
            } catch {
                issue =
                    "This reading was not synchronized. No mark-as-read declaration was recorded."
            }
        }

        private func markRead() async {
            issue = nil
            do {
                try await model.markEditorialPilotLessonRead(lesson.id)
            } catch {
                issue = "The server did not confirm your declaration. Please retry."
            }
        }
    }

    private func date(_ value: Date, locale: Locale) -> String {
        value.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .locale(locale)
        )
    }
#endif
