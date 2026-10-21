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
                                copy.native(.unavailable),
                                systemImage: "book.closed",
                                description: Text(
                                    copy.native(.contentLoadFailure)
                                )
                            )
                        } else {
                            pilotContent(snapshot)
                        }
                    } else if issue != nil {
                        ContentUnavailableView(
                            copy.native(.unavailable),
                            systemImage: "book.closed",
                            description: Text(
                                issue ?? copy.native(.contentLoadFailure))
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
                .navigationTitle(copy.native(.editorialPilot))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy[.done]) { dismiss() }
                    }
                }
                .task { await load() }
                .alert(
                    copy.native(.historyUnconfirmed),
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
                    message: copy.native(.originalFrench))
                NativeReadingSection(title: copy.native(.beforeStart)) {
                    Text(copy.contentLanguageNote)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label(copy.native(.learningNotCertification), systemImage: "book")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    NativeContentLanguageBadges(languages: [snapshot.pilot.locale])
                    LabeledContent(
                        copy.native(.duration), value: "\(snapshot.pilot.estimatedMinutes) min")
                    LabeledContent(copy.native(.sourcesChecked), value: snapshot.pilot.asOf)
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

                NativeReadingSection(title: copy.native(.lessons)) {
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
                                                "\(copy.native(.markedRead)) · \(date($0, locale: copy.language.locale))"
                                            }
                                                ?? "\(copy.native(.lastOpened)) · \(date(progress.lastAccessedAt, locale: copy.language.locale))"
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
                    ContentUnavailableView(copy.native(.unavailable), systemImage: "book.closed")
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
                issue = copy.native(.contentLoadFailure)
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
                    NativeReadingSection(title: copy.native(.understandSituation)) {
                        Text(lesson.title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(copy.native(.originalFrench))
                            .font(.caption).foregroundStyle(.secondary)
                        NativeContentLanguageBadges(languages: ["fr-FR"])
                        DisclosureGroup(copy.native(.readAloud)) {
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
                            copy.native(.duration), value: "\(lesson.estimatedMinutes) min")
                    }
                    .id("editorial-reading-start")

                    NativeReadingSection(title: copy.native(.keyIdeas)) {
                        ForEach(Array(lesson.keyIdeas.enumerated()), id: \.offset) { item in
                            Label(item.element, systemImage: "lightbulb")
                        }
                    }

                    NativeReadingSection(title: copy.native(.workedExample)) {
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

                    NativeReadingSection(title: copy.native(.selfCheck)) {
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

                    NativeReadingSection(title: copy.native(.takeaway)) {
                        Text(lesson.recap)
                            .font(.headline)
                    }

                    NativeReadingSection(title: copy.native(.sourcesLimits)) {
                        ForEach(sources.filter { lesson.sourceIDs.contains($0.id) }) { source in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(source.title).font(.headline)
                                Text("\(copy.native(.sourcesChecked)) · \(source.checkedOn)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(source.supports)
                                Text(source.limits)
                                    .foregroundStyle(.secondary)
                                if let url = URL(string: source.url) {
                                    Link(copy.native(.openSource), destination: url)
                                        .frame(minHeight: 44)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    NativeReadingSection(title: copy.native(.readingHistory)) {
                        if let markedReadAt = progress?.markedReadAt {
                            Label(
                                "\(copy.native(.markedRead)) · \(date(markedReadAt, locale: copy.language.locale))",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.secondary)
                        } else {
                            NativePrimaryButton(title: copy.native(.markRead), symbol: "checkmark")
                            {
                                Task { await markRead() }
                            }
                            .disabled(model.busy || !accessRecorded)
                            .accessibilityIdentifier("mark-editorial-pilot-lesson-read")
                            Text(copy.native(.declarationHint))
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
                    NativeReadingSection(title: copy.native(.revisit)) {
                        Button(copy.native(.readAgain), systemImage: "text.book.closed") {
                            reader.scrollTo("editorial-reading-start", anchor: .top)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("read-editorial-lesson-again")
                        Button(copy.native(.formativePractice), systemImage: "pencil") {
                            reader.scrollTo("editorial-practice", anchor: .top)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("review-editorial-practice")
                        Text(copy.native(.noScoreHint))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(copy.native(.lessons))
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
                issue = copy.native(.unsynced)
            }
        }

        private func markRead() async {
            issue = nil
            do {
                try await model.markEditorialPilotLessonRead(lesson.id)
            } catch {
                issue = copy.native(.readNotConfirmed)
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
