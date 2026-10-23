import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeStudyPlanView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @Bindable var model: NativeModel
        let ownerID: String
        let trackID: String
        @State private var targetDate = Date()
        @State private var hasTargetDate = false
        @State private var level: CertigoStudyPlanPreference.InitialLevel = .beginner
        @State private var minutes = 10
        @State private var issue = false

        var body: some View {
            NavigationStack {
                Form {
                    Section(copy.native(.studyPlan)) {
                        Toggle(copy.native(.targetDate), isOn: $hasTargetDate)
                        if hasTargetDate {
                            DatePicker(
                                copy.native(.targetDate), selection: $targetDate,
                                displayedComponents: .date)
                        }
                        Picker(copy.native(.initialLevel), selection: $level) {
                            Text(copy.native(.beginner))
                                .tag(CertigoStudyPlanPreference.InitialLevel.beginner)
                            Text(copy.native(.intermediate))
                                .tag(CertigoStudyPlanPreference.InitialLevel.intermediate)
                            Text(copy.native(.advanced))
                                .tag(CertigoStudyPlanPreference.InitialLevel.advanced)
                        }
                        Stepper(
                            "\(copy.native(.duration)) · \(copy.minutes(minutes))",
                            value: $minutes, in: 1...1440, step: 1)
                        Text(copy.native(.localPlanHint)).foregroundStyle(.secondary)
                    }
                    if issue || model.studyPlanError {
                        Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                    }
                }
                .navigationTitle(copy.native(.studyPlan))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy[.cancel]) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy.native(.save)) {
                            do {
                                let plan = try CertigoStudyPlanPreference(
                                    targetExamDate: hasTargetDate ? targetDate : nil,
                                    initialLevel: level, dailyMinutesGoal: minutes)
                                model.saveStudyPlan(plan, ownerID: ownerID, trackID: trackID)
                                if !model.studyPlanError { dismiss() }
                            } catch { issue = true }
                        }
                        .disabled(
                            model.busy || model.profile?.id != ownerID
                                || model.profile?.activeTrackId != trackID)
                    }
                }
                .onAppear {
                    model.loadStudyPlan()
                    if let plan = model.studyPlan {
                        targetDate = plan.targetExamDate ?? Date()
                        hasTargetDate = plan.targetExamDate != nil
                        level = plan.initialLevel
                        minutes = plan.dailyMinutesGoal
                    }
                }
            }
        }
    }

    struct NativeMockExamView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        @State private var confirmDiscard = false

        var body: some View {
            NativeReadingPage {
                NativeEntryHeading(
                    title: copy.native(.finalAssessment),
                    message: copy.native(.assessmentDisclaimer))
                if let snapshot = model.examSnapshot {
                    NativeCertificationCrest(code: snapshot.exam.trackCode, compact: true)
                    Text(snapshot.exam.trackTitle).font(.title2.bold())
                    if snapshot.exam.items.isEmpty {
                        Text(copy.native(.emptyExam))
                    } else if let result = snapshot.result {
                        NativeReadingSection(
                            title: result.passed
                                ? copy.native(.assessmentPassed) : copy.native(.assessmentReview)
                        ) {
                            NativeReadinessRing(
                                percent: result.pct, title: copy.native(.score),
                                accent: result.passed ? NativePrism.confirmed : NativePrism.pending)
                            Label(
                                snapshot.exam.trackCode,
                                systemImage: result.passed ? "trophy" : "book")
                            LabeledContent(copy.native(.score), value: "\(result.pct) %")
                            LabeledContent(
                                copy.native(.correctCount),
                                value: "\(result.correct) / \(result.total)")
                            Text("\(result.scaledScore) / 1000 · \(result.passingScore)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            ForEach(result.domains, id: \.domainId) { domain in
                                LabeledContent(
                                    domain.name,
                                    value: "\(domain.correct) / \(domain.total) · \(domain.pct) %")
                            }
                            if let strongest = result.domains.max(by: { $0.pct < $1.pct }) {
                                LabeledContent(copy.native(.strongest), value: strongest.name)
                            }
                            Text(copy.native(.assessmentReview)).font(.headline)
                            Text(result.weakConcepts.joined(separator: " · "))
                            LabeledContent(
                                copy.native(.confirmedXP),
                                value: "\(result.rewards.xpEarned)")
                        }
                        ForEach(snapshot.exam.items, id: \.itemId) { item in
                            if let feedback = result.results.first(where: {
                                $0.itemId == item.itemId
                            }) {
                                NativeReadingCard {
                                    Text(.init(item.stem)).font(.headline)
                                    Text(.init(feedback.explanation)).textSelection(.enabled)
                                    LabeledContent(
                                        copy.native(.masteryChange),
                                        value: feedback.masteryDelta.formatted())
                                }
                            }
                        }
                    } else {
                        NativeQuestionProgress(
                            selected: snapshot.exam.items.filter {
                                snapshot.selections[$0.itemId] != nil
                            }.count,
                            total: snapshot.exam.items.count,
                            title: copy.questionCount(
                                selected: snapshot.exam.items.filter {
                                    snapshot.selections[$0.itemId] != nil
                                }.count, total: snapshot.exam.items.count))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(
                                0,
                                snapshot.exam.timeLimitSeconds
                                    - Int(context.date.timeIntervalSince(snapshot.startedAt)))
                            LabeledContent(
                                copy.native(.timeRemaining),
                                value: "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
                            )
                        }
                        if snapshot.submission != nil {
                            Text(copy.native(.pendingExam)).foregroundStyle(.secondary)
                        }
                        ForEach(snapshot.exam.items, id: \.itemId) { item in
                            NativeReadingSection(title: copy.native(.multipleChoice)) {
                                Text(.init(item.stem)).font(.headline)
                                ForEach(Array(item.options.enumerated()), id: \.element.id) {
                                    index, option in
                                    Button {
                                        model.selectExamOption(
                                            itemID: item.itemId, optionID: option.id)
                                    } label: {
                                        NativeAnswerLabel(
                                            text: option.label, index: index,
                                            selected: snapshot.selections[item.itemId] == option.id)
                                    }
                                    .buttonStyle(
                                        NativeChoiceButtonStyle(
                                            isSelected: snapshot.selections[item.itemId]
                                                == option.id)
                                    )
                                    .disabled(snapshot.submission != nil || model.examBusy)
                                    .accessibilityAddTraits(
                                        snapshot.selections[item.itemId] == option.id
                                            ? .isSelected : [])
                                }
                            }
                        }
                        NativePrimaryButton(
                            title: snapshot.submission == nil
                                ? copy.native(.submitExam) : copy.retry,
                            symbol: "paperplane"
                        ) {
                            Task { await model.submitMockExam() }
                        }
                        .disabled(!model.canSubmitMockExam)
                    }
                } else if !model.examBusy {
                    NativePrimaryButton(
                        title: copy.native(.generateExam), symbol: "checkmark.seal"
                    ) {
                        Task { await model.generateMockExam() }
                    }
                    .disabled(model.busy || model.profile?.activeTrackId == nil || model.examError)
                }
                if model.examBusy { ProgressView(copy.loading) }
                if model.examError {
                    Label(
                        model.examUnsupported
                            ? copy.native(.unsupportedExam) : copy.native(.dataFailure),
                        systemImage: "exclamationmark.triangle")
                }
                if model.examSnapshot != nil || model.examError {
                    Button(copy.native(.discardExam), role: .destructive) { confirmDiscard = true }
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.examBusy)
                }
            }
            .navigationTitle(copy.native(.finalAssessment))
            .task { model.restoreMockExam() }
            .confirmationDialog(copy.native(.discardExam), isPresented: $confirmDiscard) {
                Button(copy.native(.discardExam), role: .destructive) { model.discardMockExam() }
            } message: {
                Text(copy.native(.discardExamHint))
            }
        }
    }

    struct NativeNotificationPreferencesView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        let ownerID: String
        @State private var enabled: Bool
        @State private var offset: Int
        @State private var quietStart: Int
        @State private var quietEnd: Int
        @State private var preferredHour: Int
        @State private var maxPerDay: Int
        @State private var streak: Bool
        @State private var quests: Bool
        @State private var leagues: Bool

        init(model: NativeModel, settings: NotificationSettings, ownerID: String) {
            self.model = model
            self.ownerID = ownerID
            _enabled = State(initialValue: settings.enabled)
            _offset = State(initialValue: settings.utcOffsetMinutes)
            _quietStart = State(initialValue: settings.quietHoursStart)
            _quietEnd = State(initialValue: settings.quietHoursEnd)
            _preferredHour = State(initialValue: settings.preferredHour)
            _maxPerDay = State(initialValue: settings.maxPerDay)
            _streak = State(initialValue: settings.streakAlerts)
            _quests = State(initialValue: settings.questAlerts)
            _leagues = State(initialValue: settings.leagueAlerts)
        }

        var body: some View {
            Section(copy[.notifications]) {
                Toggle(copy[.notificationsEnabled], isOn: $enabled)
                Stepper(
                    "\(copy.native(.utcOffset)) · \(offset)", value: $offset, in: -840...840,
                    step: 15)
                Stepper(
                    "\(copy.native(.quietStart)) · \(quietStart):00", value: $quietStart, in: 0...23
                )
                Stepper("\(copy.native(.quietEnd)) · \(quietEnd):00", value: $quietEnd, in: 0...23)
                Stepper(
                    "\(copy[.preferredHour]) · \(preferredHour):00", value: $preferredHour,
                    in: 0...23)
                Stepper("\(copy[.maxPerDay]) · \(maxPerDay)", value: $maxPerDay, in: 0...10)
                Toggle(copy[.streakAlerts], isOn: $streak)
                Toggle(copy[.questAlerts], isOn: $quests)
                Toggle(copy[.leagueAlerts], isOn: $leagues)
                Text(copy.native(.notificationScope)).font(.caption).foregroundStyle(.secondary)
                Button(copy.native(.save)) {
                    let settings = NotificationSettings(
                        enabled: enabled, utcOffsetMinutes: offset, quietHoursStart: quietStart,
                        quietHoursEnd: quietEnd, preferredHour: preferredHour, maxPerDay: maxPerDay,
                        streakAlerts: streak, questAlerts: quests, leagueAlerts: leagues)
                    Task { await model.saveNotificationSettings(settings, ownerID: ownerID) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || model.insightsLoading || model.profile?.id != ownerID)
            }
            .onChange(of: model.notificationSettings) { _, settings in
                guard let settings else { return }
                enabled = settings.enabled
                offset = settings.utcOffsetMinutes
                quietStart = settings.quietHoursStart
                quietEnd = settings.quietHoursEnd
                preferredHour = settings.preferredHour
                maxPerDay = settings.maxPerDay
                streak = settings.streakAlerts
                quests = settings.questAlerts
                leagues = settings.leagueAlerts
            }
        }
    }
#endif
