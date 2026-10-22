import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Environment(\.scenePhase) private var scenePhase
        @Bindable var model: NativeModel
        @Binding var pendingLessonLink: EditorialPilotLessonLink?
        @Binding var pendingWidgetRoute: CertigoWidgetRoute?
        let closeDeveloper: (() -> Void)?
        @State private var widgetController = NativeWidgetSnapshotController()
        @State private var appIconController = NativeAppIconController()
        @State private var selectedTrack: String?
        @State private var selectedLesson: String?
        @State private var savingGoalID: String?
        @State private var navigation = NativeLearningNavigation()
        @State private var columns: NavigationSplitViewVisibility = .automatic
        @State private var compactColumn: NavigationSplitViewColumn = .sidebar
        @State private var showEditorialPilot = false
        @State private var requestedLessonID: String?
        @State private var loadingTrackID: String?
        @State private var loadingPathRequestID: UUID?
        @State private var loadingLessonID: String?
        @State private var loadingLessonRequestID: UUID?
        @State private var downloadTrack: Track?
        @State private var catalogFilter = NativeCatalogFilter()
        @State private var showcaseUniverse: NativeShowcaseUniverse?
        @State private var resumeTrackID: String?
        @State private var showingStudyPlan = false
        @State private var showingWidgetGallery = false

        init(
            model: NativeModel,
            pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil),
            pendingWidgetRoute: Binding<CertigoWidgetRoute?> = .constant(nil),
            closeDeveloper: (() -> Void)? = nil
        ) {
            self.model = model
            self._pendingLessonLink = pendingLessonLink
            self._pendingWidgetRoute = pendingWidgetRoute
            self.closeDeveloper = closeDeveloper
        }

        var body: some View {
            Group {
                if model.requiresDeletionSurface {
                    NavigationStack {
                        NativeAccountDeletionView(model: model)
                            .modifier(NativeDeveloperToolbar(close: closeDeveloper))
                    }
                } else if model.profile == nil {
                    connection
                } else {
                    TabView(selection: $model.selectedTab) {
                        learning
                            .tabItem { Label(copy.learn, systemImage: "book") }
                            .tag(NativeResumeState.Tab.learn)
                        NavigationStack {
                            coach
                        }
                        .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                        .tag(NativeResumeState.Tab.coach)
                        NavigationStack {
                            NativeReadingPage {
                                Picker(copy.social, selection: $navigation.social) {
                                    Text(copy.friends).tag(NativeLearningNavigation.Social.friends)
                                    Text(copy.teams).tag(NativeLearningNavigation.Social.teams)
                                }
                                .pickerStyle(.menu)
                                NativeGoalHero(
                                    title: copy.social,
                                    subtitle: copy.native(.socialUnavailableHint),
                                    theme: NativeTrackTheme(band: 4, symbol: "person.2.fill"),
                                    readinessTitle: copy.native(.readiness))
                                Label(
                                    copy.native(.socialUnavailable), systemImage: "person.2"
                                )
                                .font(.headline).foregroundStyle(.secondary)
                                NativeReadingSection(title: copy.native(.privateLearning)) {
                                    Text(
                                        copy.native(.privateProfileHint)
                                    )
                                    Text(
                                        copy.native(.privateResultsHint)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                NativeReadingSection(
                                    title: navigation.social == .friends
                                        ? copy.native(.friendsInactive)
                                        : copy.native(.teamsInactive)
                                ) {
                                    Text(
                                        navigation.social == .friends
                                            ? copy.native(.friendsPrivacy)
                                            : copy.native(.teamsPrivacy)
                                    )
                                    Text(
                                        copy.native(.sharingConsent)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                Button(copy.native(.returnLearning), systemImage: "book") {
                                    model.selectedTab = .learn
                                }
                                .frame(minHeight: 44)
                            }
                            .navigationTitle(copy.social)
                            .modifier(NativeDeveloperToolbar(close: closeDeveloper))
                        }
                        .tabItem { Label(copy.social, systemImage: "person.2") }
                        .tag(NativeResumeState.Tab.social)
                        NavigationStack {
                            profile.modifier(NativeDeveloperToolbar(close: closeDeveloper))
                        }
                        .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                        .tag(NativeResumeState.Tab.profile)
                    }
                }
            }
            .onChange(of: model.profile?.id, initial: true) { previousOwner, owner in
                if owner == nil || (previousOwner != nil && previousOwner != owner) {
                    appIconController.resetForSignedOut()
                }
                navigation = NativeLearningNavigation(hasGoal: model.profile?.activeTrackId != nil)
                selectedTrack = nil
                selectedLesson = nil
                catalogFilter.clear()
                showcaseUniverse = nil
                showingStudyPlan = false
                resumeTrackID = nil
                columns = .automatic
                compactColumn = .sidebar
                loadingTrackID = nil
                loadingPathRequestID = nil
                loadingLessonID = nil
                loadingLessonRequestID = nil
                if owner == nil { savingGoalID = nil }
            }
            .onChange(of: model.profile?.activeTrackId) { _, _ in
                showingStudyPlan = false
            }
            .onChange(of: pendingWidgetRoute, initial: true) { _, route in
                guard route != nil else { return }
                navigation.learn = .myLearning
                model.selectedTab = .learn
                columns = .all
                compactColumn = .sidebar
                pendingWidgetRoute = nil
            }
            .onChange(of: widgetSnapshotKey, initial: true) { _, _ in
                refreshWidgetSnapshot()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    refreshWidgetSnapshot()
                    appIconController.applicationBecameActive()
                }
            }
            .onDisappear {
                if model.profile == nil { widgetController.clear() }
            }
            .onChange(of: model.restorationRevision) { _, _ in
                selectedTrack = model.path?.trackId ?? model.offlinePack?.trackId
                selectedLesson = model.lesson?.id
                if model.lesson != nil {
                    columns = .detailOnly
                    compactColumn = .detail
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.busy {
                    ProgressView(
                        savingGoalID == nil ? copy.loading : copy.native(.savingGoal)
                    )
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        if reduceTransparency {
                            NativePrism.surface
                        } else {
                            Rectangle().fill(.regularMaterial)
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(NativePrism.edge).frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
            .alert(
                copy.native(.operationUnconfirmed),
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button(copy[.done], role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage?.resolved(using: copy) ?? "")
            }
            .task { await model.restore() }
            .sheet(isPresented: $showEditorialPilot) {
                NativeEditorialPilotView(
                    model: model,
                    requestedLessonID: requestedLessonID
                )
            }
            .sheet(isPresented: $showingStudyPlan) {
                if let ownerID = model.profile?.id, let trackID = model.profile?.activeTrackId {
                    NativeStudyPlanView(model: model, ownerID: ownerID, trackID: trackID)
                }
            }
            .sheet(isPresented: $showingWidgetGallery) {
                NativeWidgetGalleryView(
                    liveSnapshot: widgetController.snapshot,
                    storeLocation: widgetController.store.location,
                    storeError: widgetController.error,
                    language: copy.language,
                    appIconController: appIconController
                )
            }
        }

        private var widgetSnapshotKey: NativeWidgetSnapshotKey {
            NativeWidgetSnapshotKey(
                profile: model.profile,
                tracks: model.tracks,
                notificationPlan: model.notificationPlan,
                notificationSettings: model.notificationSettings,
                studyPlan: model.studyPlan,
                language: copy.language
            )
        }

        private func refreshWidgetSnapshot() {
            widgetController.refresh(
                profile: model.profile,
                tracks: model.tracks,
                notificationPlan: model.notificationPlan,
                notificationSettings: model.notificationSettings,
                studyPlan: model.studyPlan,
                language: copy.language,
                now: .now
            )
            appIconController.synchronize(
                phase: widgetController.snapshot?.phase(at: .now),
                streakDays: model.profile?.streakDays
            )
        }

        private var coach: some View {
            NativeReadingPage {
                NativeGoalHero(
                    title: copy[.coachWorkspaceTitle], subtitle: copy[.coachPromptHint],
                    theme: NativeTrackTheme(band: 0, symbol: "sparkles"),
                    readinessTitle: copy.native(.readiness),
                    code: model.tracks.first(where: {
                        $0.id.lowercased() == model.profile?.activeTrackId?.lowercased()
                    })?.code)
                Text(copy.native(.coachDisclosure))
                    .font(.subheadline).foregroundStyle(.secondary)
                if case .corrected(let result) = model.outcome, let lesson = model.lesson {
                    ForEach(result.results) { item in
                        if let question = lesson.questions.first(where: { $0.id == item.itemId }) {
                            NativeReadingSection(title: lesson.title) {
                                Text(.init(question.stem)).font(.headline)
                                Text(.init(item.explanation)).textSelection(.enabled)
                                tutorContent(for: item.itemId)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        copy[.coachPromptHint], systemImage: "bubble.left.and.bubble.right",
                        description: model.outcome == nil ? nil : Text(coachPhase))
                }
                NativeReadingSection(title: copy.native(.currentContext)) {
                    if let goal = model.profile?.activeTrackId {
                        LabeledContent(copy.native(.confirmedGoal), value: trackTitle(goal))
                    } else {
                        Text(copy.native(.noGoal))
                    }
                    if let lesson = model.lesson {
                        Text(lesson.title).font(.headline)
                        Text(coachPhase)
                    }
                    Text(copy.native(.coachPrivacy))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(copy.native(.chooseContext), systemImage: "book") {
                        showMyLearning()
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle(copy.coach)
            .modifier(NativeDeveloperToolbar(close: closeDeveloper))
        }

        private var coachPhase: String {
            switch model.outcome {
            case .pendingCorrection: copy[.pendingCorrection]
            case .corrected: copy.confirmed
            case nil: copy[.coachPromptHint]
            }
        }

        @ViewBuilder private func tutorContent(for itemID: String) -> some View {
            if let explanation = model.tutorExplanation, explanation.itemId == itemID {
                NativeReadingCard {
                    Text(copy[.coachHeadline]).font(.subheadline).foregroundStyle(.secondary)
                    Text(explanation.headline).font(.headline)
                    Text(copy[.coachKeyPoints]).font(.subheadline.weight(.semibold))
                    ForEach(Array(explanation.points.enumerated()), id: \.offset) { _, point in
                        Text(point).textSelection(.enabled)
                    }
                    Text(explanation.encouragement)
                    Text(copy[.coachRecommendation]).font(.subheadline.weight(.semibold))
                    Text(explanation.recommendation).textSelection(.enabled)
                    Divider()
                    Text(copy[.coachPersonalization]).font(.subheadline.weight(.semibold))
                    LabeledContent(
                        copy.native(.attempts), value: "\(explanation.personalization.attempts)")
                    LabeledContent(
                        copy.native(.errors), value: "\(explanation.personalization.errors)")
                    LabeledContent(
                        copy.native(.accuracy),
                        value: "\(explanation.personalization.accuracyPct) %")
                    LabeledContent(copy.native(.trend), value: explanation.personalization.trend)
                    LabeledContent(
                        copy.native(.recurringErrors),
                        value: copy.native(
                            explanation.personalization.recurringStruggle ? .yes : .no))
                    Text(
                        explanation.source == "grounded"
                            ? copy[.coachSourceGrounded]
                            : explanation.source == "ai"
                                ? copy.native(.sourceAI)
                                : "\(copy.native(.sourceOther)) · \(explanation.source)"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Text(explanation.citedConceptIds.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("confirmed-tutor-explanation")
            }
            if model.isRequestingTutorExplanation {
                ProgressView(copy[.coachExplaining])
            }
            if model.tutorExplanationError != nil {
                Label(copy.native(.tutorFailure), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            let wasWrong: Bool = {
                guard case .corrected(let result) = model.outcome else { return false }
                return result.results.first(where: { $0.itemId == itemID })?.correct == false
            }()
            Button(
                wasWrong ? copy[.whyWasIWrong] : copy[.explainWithCoach],
                systemImage: "bubble.left.and.bubble.right"
            ) {
                Task { await model.requestTutorExplanation(itemId: itemID) }
            }
            .frame(minHeight: 44)
            .disabled(model.busy || model.isRequestingTutorExplanation)
            .buttonStyle(.borderedProminent)
            .tint(NativePrism.tint)
            .accessibilityIdentifier("request-tutor-explanation-\(itemID)")
        }

        private var visibleTracks: [Track] {
            model.tracks.filter {
                navigation.showsTrack(
                    $0.id, activeID: model.profile?.activeTrackId, openedID: selectedTrack)
                    && (navigation.learn != .explore
                        || ((showcaseUniverse?.includes(code: $0.code) ?? true)
                            && catalogFilter.includes(
                                code: $0.code, title: $0.title, summary: $0.summary,
                                available: $0.learningAvailable)))
            }
        }

        private var catalogFamilies: [String] {
            Set(model.tracks.map { NativeCatalogFilter.family(for: $0.code) })
                .filter { !$0.isEmpty }.sorted()
        }

        private var catalogCategories: [NativeRadarCategory] {
            NativeRadarCategory.allCases.filter { category in
                model.tracks.contains {
                    NativeTrackAppearance.group(for: $0.code)?.category == category
                }
            }
        }

        private func universeTitle(_ universe: NativeShowcaseUniverse) -> String {
            switch universe {
            case .azure: "Microsoft Azure"
            case .github: "GitHub & Copilot"
            case .data: "Data & Fabric"
            case .aws: "AWS"
            case .security:
                "\(NativeRadarCategory.cloud.title(copy)) · \(NativeRadarCategory.security.title(copy))"
            }
        }

        private var ecosystemShowcase: some View {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(NativeShowcaseUniverse.allCases, id: \.self) { universe in
                        let tracks = model.tracks.filter { universe.includes(code: $0.code) }
                        if let first = tracks.first {
                            let available = tracks.filter(\.learningAvailable).count
                            Button {
                                catalogFilter.clear()
                                showcaseUniverse = showcaseUniverse == universe ? nil : universe
                            } label: {
                                NativeShowcaseTile(
                                    code: first.code, title: universeTitle(universe),
                                    detail:
                                        "\(tracks.count) · \(copy.native(.collection))\n\(available) · \(copy[.practiceAvailable])",
                                    selected: showcaseUniverse == universe)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(showcaseUniverse == universe ? .isSelected : [])
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("catalog-ecosystem-showcase")
        }

        private var learning: some View {
            NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn)
            {
                List(selection: $selectedTrack) {
                    Section {
                        Picker(copy.learn, selection: $navigation.learn) {
                            Text(copy.myLearning).tag(NativeLearningNavigation.Learn.myLearning)
                            Text(copy.explore).tag(NativeLearningNavigation.Learn.explore)
                        }
                        .pickerStyle(.menu)
                    }
                    if navigation.learn == .myLearning {
                        Section {
                            confirmedGoal
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        Section {
                            NativeMetricGrid {
                                NavigationLink {
                                    NativeReadingPage { smartReview }
                                        .navigationTitle(copy.native(.reviewPractice))
                                } label: {
                                    NativeMetricTile(
                                        title: copy.native(.reviewPractice),
                                        value: copy.native(.continueReview),
                                        symbol: "arrow.triangle.2.circlepath",
                                        accent: NativePrism.confirmed)
                                }
                                .buttonStyle(.plain)
                                NavigationLink {
                                    NativeReadingPage { learningInsights }
                                        .navigationTitle(copy.native(.focusArea))
                                } label: {
                                    NativeMetricTile(
                                        title: copy.native(.focusArea), value: copy.native(.skills),
                                        symbol: "scope", accent: NativePrism.pending)
                                }
                                .buttonStyle(.plain)
                            }
                            if let board = model.questBoard {
                                Text(copy.native(.quests)).font(.headline)
                                questCards(board)
                            }
                        }
                        .listRowBackground(Color.clear)
                        myLearningPlan
                        Section(copy.native(.readiness)) {
                            learningInsights
                        }
                        Section(copy.native(.finalAssessment)) {
                            NavigationLink {
                                NativeMockExamView(model: model)
                            } label: {
                                Label(copy[.startFinalAssessment], systemImage: "checkmark.seal")
                            }
                        }
                    } else {
                        Section {
                            Text(copy.native(.findGoal))
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(copy.native(.catalogHint))
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                        Section { ecosystemShowcase }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        Section(copy.native(.findCertification)) {
                            Picker(copy.native(.codeFamily), selection: $catalogFilter.family) {
                                Text(copy.native(.allFamilies)).tag("")
                                ForEach(catalogFamilies, id: \.self) { family in
                                    Text(family).tag(family)
                                }
                            }
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    Button(copy[.categoryAll]) { catalogFilter.category = nil }
                                        .buttonStyle(.bordered)
                                        .tint(
                                            catalogFilter.category == nil
                                                ? NativePrism.tint : .secondary
                                        )
                                        .accessibilityAddTraits(
                                            catalogFilter.category == nil ? .isSelected : [])
                                    ForEach(catalogCategories, id: \.self) { category in
                                        Button(category.title(copy)) {
                                            catalogFilter.category = category
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(
                                            catalogFilter.category == category
                                                ? NativePrism.tint : .secondary
                                        )
                                        .accessibilityAddTraits(
                                            catalogFilter.category == category ? .isSelected : [])
                                    }
                                }
                                .frame(minHeight: 44)
                                .controlSize(.large)
                                .buttonBorderShape(.capsule)
                            }
                            .scrollIndicators(.hidden)
                            .accessibilityLabel(copy.native(.codeCategory))
                            Toggle(copy.native(.availableOnly), isOn: $catalogFilter.availableOnly)
                            Text(copy.native(.catalogScope))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(
                                "\(copy.native(.loadedResults)) · \(visibleTracks.count) / \(model.tracks.count)"
                            )
                            .font(.subheadline)
                            if catalogFilter.isActive || showcaseUniverse != nil {
                                Button(copy[.clearFilters], systemImage: "xmark.circle") {
                                    catalogFilter.clear()
                                    showcaseUniverse = nil
                                }
                            }
                        }
                    }
                    certificationCollection
                    Section(copy.native(.continueDevice)) {
                        if let lesson = model.lesson,
                            navigation.learn == .explore
                                || lesson.trackId.lowercased()
                                    != model.profile?.activeTrackId?.lowercased()
                        {
                            Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        Button(copy.native(.restoreActivity), systemImage: "internaldrive") {
                            Task { await model.restoreDownloadedActivity() }
                        }
                        .disabled(model.busy)
                        if navigation.learn == .myLearning && model.profile?.activeTrackId == nil {
                            Text(copy.native(.chooseGoalHint))
                            Button(copy.explore) { navigation.learn = .explore }
                        }
                    }
                    Section(copy.native(.guidedReading)) {
                        Button("Assistants IA responsables", systemImage: "text.book.closed") {
                            requestedLessonID = nil
                            showEditorialPilot = true
                        }
                        Text(copy.native(.frenchPilot))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let pendingLessonLink {
                        Section(copy.native(.sharedLesson)) {
                            Text("\(copy.native(.editorialPilot)) · \(pendingLessonLink.lessonID)")
                            Button(
                                copy.native(.openLinkedLesson), systemImage: "arrow.up.right.square"
                            ) {
                                requestedLessonID = pendingLessonLink.lessonID
                                self.pendingLessonLink = nil
                                showEditorialPilot = true
                            }
                            .disabled(model.busy)
                            .accessibilityIdentifier("open-linked-editorial-lesson")
                        }
                    }
                }
                .disabled(
                    model.busy || loadingTrackID != nil || loadingLessonID != nil
                )
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(NativePrism.canvas)
                .navigationTitle(copy.learn)
                .modifier(NativeDeveloperToolbar(close: closeDeveloper))
                .modifier(
                    NativeCatalogSearch(
                        enabled: navigation.learn == .explore, query: $catalogFilter.query))
            } content: {
                path.modifier(NativeDeveloperToolbar(close: closeDeveloper))
            } detail: {
                session.modifier(NativeDeveloperToolbar(close: closeDeveloper))
            }
            .onChange(of: selectedTrack) { _, id in
                if let resumeTrackID, resumeTrackID == id {
                    self.resumeTrackID = nil
                    return
                }
                guard let track = model.tracks.first(where: { $0.id == id }),
                    track.learningAvailable
                else { return }
                guard model.path?.trackId != track.id else { return }
                if model.offlinePack?.trackId == track.id && model.lesson != nil { return }
                selectedLesson = nil
                requestPath(track)
            }
            .onChange(of: selectedLesson) { _, id in
                guard model.lesson?.id != id else { return }
                if let id, model.offlinePack?.lessons.contains(where: { $0.id == id }) == true {
                    Task { await model.openCachedLesson(id) }
                    return
                }
                guard
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == id
                    }
                    )
                else { return }
                requestLesson(node)
            }
            .confirmationDialog(
                copy.native(.downloadQuestionPacks),
                isPresented: Binding(
                    get: { downloadTrack != nil },
                    set: { if !$0 { downloadTrack = nil } })
            ) {
                if let track = downloadTrack {
                    Button(copy.native(.downloadContent)) {
                        downloadTrack = nil
                        Task { await model.downloadQuestionPack(track) }
                    }
                }
            } message: {
                Text(
                    copy.native(.downloadBoundary)
                )
            }
        }

        @ViewBuilder private var certificationCollection: some View {
            Section(
                navigation.learn == .explore ? copy.native(.collection) : copy.native(.yourGoals)
            ) {
                ForEach(visibleTracks) { track in
                    NavigationLink(value: track.id) {
                        NativeCertificationCard(track: track).padding(.vertical, 8)
                    }
                    .disabled(model.busy)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            if model.tracks.isEmpty {
                Text(copy.native(.noCatalog))
            } else if navigation.learn == .explore && visibleTracks.isEmpty {
                Section {
                    ContentUnavailableView(
                        copy[.noMatchingTracks], systemImage: "magnifyingglass",
                        description: Text(copy.native(.noMatchesHint)))
                    Button(copy[.clearFilters]) {
                        catalogFilter.clear()
                        showcaseUniverse = nil
                    }
                }
            }
        }

        @ViewBuilder private var myLearningPlan: some View {
            Section(copy.native(.learningPlan)) {
                if let path = model.path,
                    path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased()
                {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(
                        "\(copy.native(.remainingActivities)) · \(coverage.remainingActivities) / \(coverage.totalActivities)"
                    )
                    .font(.headline)
                    ForEach(path.units) { unit in
                        unitProgress(title: unit.title, lessons: unit.lessons, code: path.trackId)
                        ForEach(Array(unit.lessons.enumerated()), id: \.element.id) {
                            index, lesson in
                            Button {
                                selectedTrack = path.trackId
                                selectedLesson = lesson.id
                                columns = .detailOnly
                                compactColumn = .detail
                            } label: {
                                lessonLabel(
                                    lesson, code: path.trackId, number: index + 1,
                                    isLast: index == unit.lessons.count - 1)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .disabled(!lesson.canOpen || model.busy || loadingLessonID != nil)
                        }
                    }
                    Text(copy.native(.openPlanHint))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(copy.native(.loadGoalHint))
                        .foregroundStyle(.secondary)
                }
            }
            Section(copy.native(.reviewPractice)) {
                smartReview
                Text(copy.native(.readCorrectionHint))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section(copy.native(.goalOverview)) {
                if let goal = model.profile?.activeTrackId,
                    let track = model.tracks.first(where: {
                        $0.id.lowercased() == goal.lowercased()
                    })
                {
                    Button(
                        "\(copy.native(.openOverview)) · \(track.title)",
                        systemImage: "list.bullet.rectangle"
                    ) {
                        selectedTrack = track.id
                        columns = .all
                        compactColumn = .content
                    }
                    Text(copy.native(.overviewHint))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(copy.native(.chooseGoalHint))
                        .foregroundStyle(.secondary)
                }
            }
        }

        private func unitProgress(title: String, lessons: [PathLesson], code: String) -> some View {
            let completed = lessons.filter { $0.status == .completed || $0.status == .mastered }
                .count
            return VStack(alignment: .leading, spacing: 12) {
                HStack {
                    NativeSymbolMedallion(
                        symbol: "square.stack.3d.up.fill", accent: NativePrism.accent(for: code))
                    Text(title).font(.title3.weight(.bold))
                }
                Text(copy.coverageCount(completed: completed, total: lessons.count))
                    .font(.caption).foregroundStyle(.secondary)
                if !lessons.isEmpty {
                    ProgressView(value: Double(completed), total: Double(lessons.count))
                        .tint(NativePrism.accent(for: code))
                }
            }
            .padding(.vertical, 12)
        }

        private func lessonLabel(
            _ lesson: PathLesson, code: String, number: Int, isLast: Bool
        ) -> some View {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().fill(NativePrism.surface)
                    Circle().stroke(NativePrism.accent(for: code).opacity(0.15), lineWidth: 4)
                    if let mastery = lesson.masteryPct {
                        Circle().trim(from: 0, to: CGFloat(min(100, max(0, mastery))) / 100)
                            .stroke(
                                NativePrism.accent(for: code),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    Text(number, format: .number).font(.headline.monospacedDigit())
                        .foregroundStyle(NativePrism.accent(for: code))
                }
                .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(lesson.title).font(.headline).foregroundStyle(.primary)
                    Text("\(copy.minutes(lesson.estMinutes)) · \(activityStatus(lesson.status))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(
                        "\(lesson.nativeMasteryStage.symbol) \(copy[lesson.nativeMasteryStage.copyKey])"
                    )
                    .font(.caption.weight(.semibold)).foregroundStyle(NativePrism.accent(for: code))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(NativePrism.accent(for: code).opacity(0.1), in: Capsule())
                    if !lesson.canOpen {
                        Text(copy.native(.lockedHint)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: lesson.canOpen ? "play.circle.fill" : "lock.circle")
                    .font(.title2).foregroundStyle(NativePrism.accent(for: code))
                    .frame(minWidth: 44, minHeight: 44).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                if !isLast {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(NativePrism.accent(for: code).opacity(0.25))
                            .frame(width: 3, height: geometry.size.height / 2 + 20)
                            .offset(x: 20.5, y: geometry.size.height / 2)
                    }
                    .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
        }

        @ViewBuilder private var smartReview: some View {
            Text(copy[.recommendedReview]).font(.headline)
            if let path = model.path,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased(),
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable == true,
                let recommendation = model.smartReviewRecommendation,
                let node = recommendation.unit.lessons.first(where: { $0.canOpen })
            {
                Text(recommendation.unit.title).font(.title3.weight(.semibold))
                Text(reviewReason(recommendation.reason)).foregroundStyle(.secondary)
                Button(
                    "\(copy[.startReview]) · \(node.title) · \(copy.minutes(node.estMinutes))",
                    systemImage: "arrow.clockwise"
                ) {
                    selectedTrack = path.trackId
                    selectedLesson = node.id
                    columns = .detailOnly
                    compactColumn = .detail
                    if model.lesson?.id == node.id { requestLesson(node) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || loadingLessonID != nil)
            } else {
                Text(copy.native(.noReview)).foregroundStyle(.secondary)
            }
            Text(copy.native(.reviewEvidence)).font(.caption).foregroundStyle(.secondary)
            Button(copy.native(.refreshHistory), systemImage: "arrow.clockwise") {
                Task { await model.refreshHistory() }
            }
            .disabled(model.historyLoading || model.busy)
        }

        private func reviewReason(_ reason: SmartReviewRecommendation.Reason) -> String {
            switch reason {
            case .lowestScore(let score): "\(copy.native(.lowestScore)) · \(score) %"
            case .recurringErrors: copy.native(.recurringErrors)
            case .notYetAttempted: copy[.reviewReasonContinue]
            case .nextUnlockedUnit: copy.native(.continueReview)
            }
        }

        @ViewBuilder private var learningInsights: some View {
            if let path = model.path,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased()
            {
                LabeledContent(copy.native(.readiness), value: "\(path.readinessScore) %")
                Text(copy.native(.readinessHint)).font(.caption).foregroundStyle(.secondary)
                let remaining = NativeLearningDuration.total(
                    path.units.flatMap(\.lessons).filter {
                        $0.status != .completed && $0.status != .mastered
                    }.map(\.estMinutes))
                if let remaining {
                    LabeledContent(
                        copy.native(.remainingLearning), value: "\(copy.minutes(remaining))")
                } else {
                    Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                }
                Text(copy.native(.skills)).font(.headline)
                if let domains = path.domains, !domains.isEmpty {
                    ForEach(domains, id: \.id) { domain in
                        if let band = try? SkillBand.resolved(percent: domain.score) {
                            LabeledContent(domain.name, value: "\(domain.score) %")
                                .foregroundStyle(domainScoreColor(band))
                        } else {
                            Label(
                                copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                        }
                    }
                    if let weakest = domains.filter({ (0...100).contains($0.score) })
                        .min(by: { $0.score < $1.score })
                    {
                        Text("\(copy.native(.focusArea)) · \(weakest.name)").font(.headline)
                        if let recommendation = model.recommendations?.items.first(where: {
                            $0.domainId == weakest.id
                        }) {
                            recommendationAction(recommendation)
                        }
                    }
                }
                Text(copy.native(.domainMasteryUnavailable))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(copy.native(.loadGoalHint)).foregroundStyle(.secondary)
            }
            Text(copy.native(.review)).font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(MasteryStage.allCases, id: \.self) { stage in
                        Text("\(stage.symbol) \(copy[stage.copyKey])")
                            .font(.caption)
                    }
                }
            }
            Text(copy.native(.readinessHint)).font(.caption).foregroundStyle(.secondary)
            if let recommendations = model.recommendations {
                let reviews = recommendations.items.filter { $0.kind == "review" }
                LabeledContent(copy.native(.reviewRecommendations), value: "\(reviews.count)")
                ForEach(Array(reviews.enumerated()), id: \.offset) { _, item in
                    recommendationAction(item)
                    LabeledContent(copy.native(.reviewRisk), value: "\(item.forgettingRiskPct) %")
                }
            }
            Text(copy.native(.reviewTimingUnavailable)).font(.caption).foregroundStyle(.secondary)
            if model.insightsLoading { ProgressView(copy.loading) }
            if !model.insightFailures.isEmpty {
                Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
            }
            Button(copy.native(.refreshData), systemImage: "arrow.clockwise") {
                Task { await model.refreshLearningInsights() }
            }
            .frame(minHeight: 44)
            .disabled(model.busy || model.insightsLoading)
        }

        private func domainScoreColor(_ band: SkillBand) -> Color {
            switch band {
            case .strong: NativePrism.confirmed
            case .developing: NativePrism.pending
            case .weak: Color(uiColor: .systemRed)
            }
        }

        private func recommendationNode(_ recommendation: RecommendationItem) -> PathLesson? {
            guard let path = model.path, let recommendations = model.recommendations,
                path.trackId == recommendations.trackId,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased(),
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable == true
            else { return nil }
            if let lessonID = recommendation.lessonId {
                return path.units.flatMap(\.lessons).first { $0.id == lessonID && $0.canOpen }
            }
            if let unitID = recommendation.unitId {
                return path.units.first(where: { $0.id == unitID })?.lessons.first { $0.canOpen }
            }
            return nil
        }

        @ViewBuilder private func recommendationAction(_ recommendation: RecommendationItem)
            -> some View
        {
            Text(recommendation.title).font(.headline)
            Text(recommendation.reason).foregroundStyle(.secondary)
            Text("\(copy.native(.duration)) · \(copy.minutes(recommendation.estMinutes))")
                .font(.caption).foregroundStyle(.secondary)
            if let node = recommendationNode(recommendation) {
                Button("\(copy.startSession) · \(node.title)", systemImage: "play.circle") {
                    selectedTrack = model.path?.trackId
                    selectedLesson = node.id
                    columns = .detailOnly
                    compactColumn = .detail
                    if model.lesson?.id == node.id { requestLesson(node) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || loadingLessonID != nil)
            }
        }

        private var confirmedGoal: some View {
            VStack(alignment: .leading, spacing: 16) {
                activityStrip
                if let goalID = model.profile?.activeTrackId {
                    NativeGoalHero(
                        title: model.tracks.first(where: {
                            $0.id.lowercased() == goalID.lowercased()
                        })?.title ?? goalID,
                        subtitle: copy.confirmed,
                        theme: NativeTrackTheme(
                            code: model.tracks.first(where: {
                                $0.id.lowercased() == goalID.lowercased()
                            })?.code ?? ""),
                        readiness: model.path.flatMap {
                            $0.trackId.lowercased() == goalID.lowercased()
                                ? $0.readinessScore : nil
                        },
                        readinessTitle: copy.native(.readiness),
                        code: model.tracks.first(where: {
                            $0.id.lowercased() == goalID.lowercased()
                        })?.code)
                    Text(copy.native(.nextSession)).font(.headline)
                    if let plan = model.studyPlan {
                        if let target = plan.targetExamDate {
                            LabeledContent(
                                copy.native(.targetDate),
                                value: target.formatted(date: .abbreviated, time: .omitted))
                        }
                        Text("\(copy.native(.studyPlan)) · \(copy.minutes(plan.dailyMinutesGoal))")
                            .font(.subheadline)
                        switch plan.initialLevel {
                        case .beginner: Text("\(copy[.initialLevel]) · \(copy[.levelBeginner])")
                        case .intermediate:
                            Text("\(copy[.initialLevel]) · \(copy[.levelIntermediate])")
                        case .advanced: Text("\(copy[.initialLevel]) · \(copy[.levelAdvanced])")
                        }
                    }
                    if let track = model.tracks.first(where: {
                        $0.id.lowercased() == goalID.lowercased()
                    }) {
                        if !track.learningAvailable {
                            NativePracticeBadge(available: false)
                            Text(copy[.practiceUnavailableNote])
                                .font(.subheadline)
                        } else if let lesson = model.lesson,
                            lesson.trackId.lowercased() == goalID.lowercased()
                        {
                            let destination = NativeActivityDestination(
                                lessonID: lesson.id, title: lesson.title)
                            NativePrimaryButton(
                                title: destination.actionTitle(copy.resume), symbol: "play.circle"
                            ) {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(copy.native(.savedActivityHint))
                                .font(.caption).foregroundStyle(.secondary)
                        } else if let recommendation = model.recommendations?.items.first(where: {
                            recommendationNode($0) != nil
                        }), let next = recommendationNode(recommendation) {
                            NativePrimaryButton(
                                title:
                                    "\(copy.startSession) · \(next.title) · \(copy.minutes(next.estMinutes))",
                                symbol: "play.circle"
                            ) {
                                selectedTrack = track.id
                                selectedLesson = next.id
                                columns = .detailOnly
                                compactColumn = .detail
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                        } else if let path = model.path,
                            path.trackId.lowercased() == goalID.lowercased(),
                            let next = path.units.flatMap(\.lessons).first(where: {
                                $0.status == .inProgress || $0.status == .available
                            })
                        {
                            let destination = NativeActivityDestination(
                                lessonID: next.id, title: next.title)
                            NativePrimaryButton(
                                title:
                                    "\(destination.actionTitle(copy.startSession)) · \(copy.minutes(next.estMinutes))",
                                symbol: "play.circle"
                            ) {
                                selectedTrack = path.trackId
                                selectedLesson = destination.lessonID
                                columns = .detailOnly
                                compactColumn = .detail
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(copy.native(.nextAvailableHint))
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            NativePrimaryButton(
                                title: "\(copy.startSession) · \(track.title)",
                                symbol: "arrow.right"
                            ) {
                                selectedTrack = track.id
                                columns = .all
                                compactColumn = .content
                            }
                            .disabled(
                                !track.learningAvailable || model.busy || loadingTrackID != nil)
                        }
                    }
                    Button(copy.native(.studyPlan), systemImage: "calendar") {
                        showingStudyPlan = true
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                    if let path = model.path,
                        path.trackId.lowercased() == goalID.lowercased()
                    {
                        LabeledContent(
                            copy.native(.readiness),
                            value: "\(path.readinessScore) %"
                        )
                        .font(.subheadline)
                        Text(copy.native(.readinessHint))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(copy.native(.loadGoalHint))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    NativeEntryHeading(
                        title: copy.native(.findGoal),
                        message: copy.native(.noGoal))
                    NativePrimaryButton(title: copy.explore, symbol: "books.vertical") {
                        navigation.learn = .explore
                    }
                }
            }
            .accessibilityIdentifier("confirmed-learning-goal")
        }

        private func resumeCurrentActivity(_ lesson: Lesson) {
            if selectedTrack != lesson.trackId { resumeTrackID = lesson.trackId }
            selectedTrack = lesson.trackId
            selectedLesson = lesson.id
            columns = .detailOnly
            compactColumn = .detail
        }

        private func showMyLearning() {
            navigation.learn = .myLearning
            model.selectedTab = .learn
            columns = .all
            compactColumn = .sidebar
        }

        private func requestPath(_ track: Track) {
            let requestID = UUID()
            loadingTrackID = track.id
            loadingPathRequestID = requestID
            Task {
                await model.loadPath(track)
                guard loadingPathRequestID == requestID else { return }
                loadingTrackID = nil
                loadingPathRequestID = nil
            }
        }

        private func requestLesson(_ node: PathLesson) {
            let requestID = UUID()
            loadingLessonID = node.id
            loadingLessonRequestID = requestID
            Task {
                await model.loadLesson(node)
                guard loadingLessonRequestID == requestID else { return }
                loadingLessonID = nil
                loadingLessonRequestID = nil
            }
        }

        private var profile: some View {
            NativeReadingPage {
                if let profile = model.profile {
                    NativeEntryHeading(
                        title: profile.displayName,
                        message: copy.myLearning)
                    NativeReadingSection(title: copy.native(.confirmedLearning)) {
                        activityMetrics
                        if let goal = profile.activeTrackId {
                            if let track = model.tracks.first(where: {
                                $0.id.lowercased() == goal.lowercased()
                            }) {
                                NativeCertificationCrest(code: track.code)
                            }
                            LabeledContent(
                                copy.native(.confirmedGoal),
                                value: model.tracks.first(where: {
                                    $0.id.lowercased() == goal.lowercased()
                                })?.title ?? goal)
                        } else {
                            Text(copy.native(.noGoal))
                        }
                    }
                }
                NativeReadingSection(title: copy.native(.yourAccount)) {
                    Button {
                        showingWidgetGallery = true
                    } label: {
                        Label(
                            CertigoWidgetCopy(language: copy.language).galleryTitle,
                            systemImage: "square.grid.2x2"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    NavigationLink {
                        NativeReadingPage {
                            learningInsights
                            rewards
                        }
                        .navigationTitle(copy.native(.skills))
                    } label: {
                        Label(copy.native(.skills), systemImage: "chart.bar")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        progressHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    Divider()
                    NavigationLink {
                        Form {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section(copy.native(.studyPlan)) {
                                Button(copy.native(.studyPlan), systemImage: "calendar") {
                                    showingStudyPlan = true
                                }
                                .disabled(model.profile?.activeTrackId == nil)
                            }
                            NavigationLink(copy[.notifications]) {
                                Form {
                                    if let settings = model.notificationSettings,
                                        let ownerID = model.profile?.id
                                    {
                                        NativeNotificationPreferencesView(
                                            model: model, settings: settings, ownerID: ownerID)
                                    } else {
                                        Text(copy.native(.planNotLoaded))
                                    }
                                    if model.insightFailures.contains("notifications") {
                                        Label(
                                            copy.native(.dataFailure),
                                            systemImage: "exclamationmark.triangle")
                                    }
                                    if let plan = model.notificationPlan {
                                        Section(plan.localDate) {
                                            ForEach(plan.notifications, id: \.dedupeKey) { item in
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(item.title).font(.headline)
                                                    Text(item.body)
                                                    Text(
                                                        item.scheduledUtc,
                                                        format: .dateTime.year().month().day()
                                                            .hour().minute())
                                                }
                                            }
                                        }
                                    }
                                    Button(copy.native(.refreshData)) {
                                        Task { await model.refreshLearningInsights() }
                                    }
                                    .disabled(model.insightsLoading || model.busy)
                                    if model.insightsLoading { ProgressView(copy.loading) }
                                }
                                .navigationTitle(copy[.notifications])
                            }
                            Section(copy.native(.account)) {
                                NavigationLink(copy.accountDeletion) {
                                    NativeAccountDeletionView(model: model)
                                }
                                Section(copy.native(.accessibility)) {
                                    Text(copy.native(.accessibilityHint))
                                        .foregroundStyle(.secondary)
                                }
                                Section(copy.native(.privacy)) {
                                    Text(copy.native(.privacyHint))
                                    Text(copy.native(.coachPrivacy))
                                        .foregroundStyle(.secondary)
                                }
                                .disabled(model.busy)
                            }
                            Section(connectionSectionTitle) {
                                Text(connectionDescription)
                                Button(
                                    copy[.signOut], systemImage: "person.crop.circle.badge.xmark"
                                ) {
                                    Task { await model.disconnect() }
                                }
                                .disabled(model.busy)
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            .navigationTitle(copy.profile)
        }

        @ViewBuilder private var rewards: some View {
            Text(copy.native(.rewards)).font(.title2.bold())
            activityMetrics
            if let board = model.questBoard {
                Text(copy.native(.quests)).font(.headline)
                Text(board.date).font(.caption).foregroundStyle(.secondary)
                questCards(board)
            }
            if let board = model.achievementBoard {
                Text(copy.native(.achievements)).font(.headline)
                LabeledContent(copy.confirmed, value: "\(board.unlocked) / \(board.total)")
                NativeMetricGrid {
                    ForEach(board.achievements, id: \.id) { achievement in
                        NativeReadingCard {
                            if achievement.threshold > 0 {
                                NativeReadinessRing(
                                    percent: Int(
                                        min(
                                            1,
                                            max(
                                                0,
                                                Double(achievement.progress)
                                                    / Double(achievement.threshold))) * 100),
                                    title: achievement.name, accent: NativePrism.confirmed)
                            } else {
                                NativeSymbolMedallion(
                                    symbol: achievement.unlocked ? "medal.fill" : "seal",
                                    accent: NativePrism.confirmed)
                                Text(achievement.name).font(.headline)
                            }
                            Text(achievement.description).font(.subheadline)
                            Text("\(achievement.progress) / \(achievement.threshold)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        private func questCards(_ board: QuestBoard) -> some View {
            NativeMetricGrid {
                ForEach(board.quests, id: \.id) { quest in
                    NativeReadingCard {
                        NativeSymbolMedallion(
                            symbol: quest.completed ? "checkmark.seal.fill" : "flag.fill",
                            accent: NativePrism.pending)
                        Text(quest.title).font(.headline)
                        Text("\(quest.current) / \(quest.target)").monospacedDigit()
                        if quest.target > 0 {
                            ProgressView(
                                value: Double(min(quest.current, quest.target)),
                                total: Double(quest.target)
                            ).tint(NativePrism.pending)
                        }
                        if quest.completed {
                            Label(copy.confirmed, systemImage: "checkmark.circle")
                        }
                    }
                }
            }
        }

        @ViewBuilder private var activityMetrics: some View {
            if let profile = model.profile {
                NativeMetricGrid {
                    NativeMetricTile(
                        title: copy.native(.confirmedXP), value: "\(profile.xp)",
                        symbol: "bolt.fill", accent: NativePrism.pending)
                    if let streak = profile.streakDays {
                        NativeMetricTile(
                            title: copy.native(.streak), value: "\(streak)",
                            symbol: "flame.fill", accent: NativePrism.accent(band: 2))
                    }

                    if let level = profile.level {
                        NativeMetricTile(
                            title: copy.native(.level), value: "\(level)",
                            symbol: "mountain.2.fill")
                    }
                    if let target = profile.dailyGoalXp, let earned = profile.dailyXpEarned,
                        target > 0
                    {
                        NativeReadingCard {
                            NativeReadinessRing(
                                percent: Int(min(1, max(0, Double(earned) / Double(target))) * 100),
                                title: copy.native(.dailyGoal), accent: NativePrism.confirmed)
                            Text("\(earned) / \(target)").font(.subheadline).monospacedDigit()
                        }
                    }
                }
                .accessibilityIdentifier("confirmed-activity-bento")
            }
        }

        @ViewBuilder private var activityStrip: some View {
            if let profile = model.profile {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        Label("\(profile.xp)", systemImage: "bolt.fill")
                            .accessibilityLabel("\(copy.native(.confirmedXP)) · \(profile.xp)")
                        if let streak = profile.streakDays {
                            Label("\(streak)", systemImage: "flame.fill")
                                .accessibilityLabel("\(copy.native(.streak)) · \(streak)")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            "\(copy.native(.confirmedXP)) · \(profile.xp)", systemImage: "bolt.fill"
                        )
                        if let streak = profile.streakDays {
                            Label("\(copy.native(.streak)) · \(streak)", systemImage: "flame.fill")
                        }
                    }
                }
                .font(.headline).foregroundStyle(NativePrism.pending)
                .symbolRenderingMode(.hierarchical)
            }
        }

        private var connectionSectionTitle: String {
            #if DEBUG
                copy.native(.developmentConnection)
            #else
                copy.native(.microsoftAccount)
            #endif
        }

        private var connectionDescription: String {
            #if DEBUG
                copy.native(.testConnectorHint)
            #else
                copy.native(.microsoftConnected)
            #endif
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        NativeEntryHeading(
                            title: copy.native(.connectWorkspace),
                            message:
                                copy.native(.developmentScope)
                        )
                        Text(
                            copy.native(.connectorBoundary)
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · \(copy.native(.development))")
                    }
                    .scrollContentBackground(.hidden)
                    .background(NativePrism.canvas)
                    Section(copy.native(.testConnection)) {
                        TextField(copy.native(.apiEndpoint), text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField(copy.native(.testToken), text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button(copy.native(.connectTest)) { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            copy.native(.tokenStorageHint)
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
                .modifier(NativeDeveloperToolbar(close: closeDeveloper))
            }
        }

        private var path: some View {
            List(selection: $selectedLesson) {
                pathLearningSections
                if let track = model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
                }) {
                    Section(copy.native(.goalOverview)) {
                        if !track.learningAvailable {
                            NativeCertificationCrest(code: track.code)
                        }
                        Text(track.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(track.summary)
                        NativeContentLanguageBadges(languages: track.languages ?? [])
                        if let group = NativeTrackAppearance.group(for: track.code) {
                            LabeledContent(
                                copy.native(.codeGroup),
                                value: NativeCatalogFilter.family(for: track.code))
                            LabeledContent(
                                copy.native(.codeCategory), value: group.category.title(copy))
                        }
                        NativePracticeBadge(available: track.learningAvailable)
                        if !track.learningAvailable {
                            Text(copy[.practiceUnavailableNote])
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(copy.native(.catalogFormats))
                        Text(copy.native(.radarLimits))
                            .font(.caption).foregroundStyle(.secondary)
                        if let lesson = model.lesson, lesson.trackId == track.id,
                            let manifest = lesson.publicManifestId
                        {
                            LabeledContent(copy.native(.publicVersion), value: manifest)
                        }
                    }
                    if track.learningAvailable {
                        Section(copy.native(.offlinePack)) {
                            Button(
                                copy.native(.downloadPack), systemImage: "arrow.down.circle"
                            ) {
                                downloadTrack = track
                            }
                            .disabled(model.busy)
                            if let pack = model.offlinePack, pack.trackId == track.id {
                                Text(copy.native(.downloadedBoundary))
                                    .font(.footnote).foregroundStyle(.secondary)
                                ForEach(pack.lessons, id: \.id) { lesson in
                                    NavigationLink(value: lesson.id) {
                                        Label(lesson.title, systemImage: "internaldrive")
                                    }
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                }
                savedAnswers
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(NativePrism.canvas)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .navigationTitle(
                model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
                })?.code ?? copy.native(.learningPath)
            )
            .navigationBarTitleDisplayMode(.inline)
        }

        @ViewBuilder private var pathLearningSections: some View {
            if let track = model.tracks.first(where: {
                $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
            }), track.learningAvailable {
                activeGoalSection(track)
            }
            if let path = model.path,
                selectedTrack == nil || selectedTrack == path.trackId,
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable != false
            {
                ForEach(path.units) { unit in
                    Section("\(copy.native(.unit)) · \(unit.title)") {
                        unitProgress(title: unit.title, lessons: unit.lessons, code: path.trackId)
                        ForEach(Array(unit.lessons.enumerated()), id: \.element.id) {
                            index, lesson in
                            NavigationLink(value: lesson.id) {
                                lessonLabel(
                                    lesson, code: path.trackId, number: index + 1,
                                    isLast: index == unit.lessons.count - 1)
                            }
                            .listRowSeparator(.hidden)
                            .disabled(
                                !lesson.canOpen || model.busy || loadingLessonID != nil)
                        }
                    }
                }
                Section(copy.native(.learningPlan)) {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    LabeledContent(
                        copy.native(.activities),
                        value: "\(coverage.completedActivities) / \(coverage.totalActivities)")
                    LabeledContent(
                        copy.native(.remainingActivities),
                        value: "\(coverage.remainingActivities)"
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(copy.native(.activityCoverageHint))
                        .font(.caption).foregroundStyle(.secondary)
                    LabeledContent(
                        copy.native(.readiness), value: "\(path.readinessScore) %")
                    Button(copy.native(.refreshData), systemImage: "arrow.clockwise") {
                        Task { await model.refreshProgress() }
                    }
                    .disabled(model.busy)
                }
                if model.profile?.activeTrackId?.lowercased() == path.trackId.lowercased() {
                    Section(copy.native(.finalAssessment)) {
                        NavigationLink {
                            NativeMockExamView(model: model)
                        } label: {
                            Label(copy[.startFinalAssessment], systemImage: "checkmark.seal")
                        }
                    }
                }
                Section(copy.native(.reviewPractice)) {
                    smartReview
                    if let lesson = model.lesson, lesson.trackId == path.trackId {
                        Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                            resumeCurrentActivity(lesson)
                        }
                        .disabled(model.busy)
                    }
                }
            } else if let selectedTrack,
                let track = model.tracks.first(where: { $0.id == selectedTrack })
            {
                if !track.learningAvailable {
                    Section {
                        Text(copy[.practiceUnavailableNote])
                        Button(copy.explore) { navigation.learn = .explore }
                    }
                } else if loadingTrackID == track.id {
                    Section {
                        ProgressView(copy.loading)
                            .frame(maxWidth: .infinity, minHeight: 88)
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            copy.native(.pathUnavailable),
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                copy.native(.pathRetryHint)
                            )
                        )
                        Button(copy.native(.retryPath), systemImage: "arrow.clockwise") {
                            requestPath(track)
                        }
                        .disabled(model.busy || loadingTrackID != nil)
                    }
                }
            } else {
                ContentUnavailableView(
                    copy.native(.chooseCertification), systemImage: "books.vertical",
                    description: Text(copy.native(.pathServerHint))
                )
            }
        }

        private var progressHistory: some View {
            NativeReadingPage {
                coverageSummary
                NativeReadingSection(title: copy.native(.skills)) {
                    learningInsights
                    rewards
                }
                NativeReadingSection(title: copy.native(.confirmedSessions)) {
                    Text(
                        copy.historyLoaded(
                            count: model.serverHistory.count,
                            hasMore: model.historyNextCursor != nil)
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        copy[.historyEvidenceNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if model.historyLoading {
                        ProgressView(copy.loading)
                    }
                    if let error = model.historyError {
                        Label(
                            error.resolved(using: copy),
                            systemImage: model.historyOffline
                                ? "wifi.slash" : "exclamationmark.triangle"
                        )
                        .accessibilityIdentifier("history-error")
                    }
                    if let refreshedAt = model.historyRefreshedAt {
                        Text(
                            "\(copy.native(.lastLoaded)) · \(refreshedAt.formatted(.dateTime.year().month().day().hour().minute().locale(copy.language.locale)))"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if model.serverHistory.isEmpty && model.historyError == nil {
                            Text(
                                model.historyNextCursor == nil
                                    ? copy[.noHistory]
                                    : copy[.historyPageEmpty]
                            )
                        }
                    } else if !model.historyLoading && model.historyError == nil {
                        Text(copy.native(.unloadedHistory))
                    }
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmed) { item in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.seal")
                                    .font(.subheadline).foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(item.lessonId)).font(.headline)
                                Text(trackTitle(item.trackId)).foregroundStyle(.secondary)
                                Text(
                                    item.submittedAt,
                                    format: .dateTime.year().month().day().hour().minute())
                                Text(
                                    copy.historyScore(
                                        scorePercent: item.scorePct, xp: item.xpEarned,
                                        confirmedOnDevice: false)
                                )
                                Text(
                                    copy[.historyCorrectionNote]
                                )
                                .font(.caption).foregroundStyle(.secondary)
                                if let saved = model.localHistorySubmission(for: item),
                                    saved.status == .pendingCorrection && saved.result == nil
                                {
                                    Button(copy.native(.retrieveCorrection)) {
                                        Task { await model.retry(saved) }
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                    Button(copy.native(.refreshHistory), systemImage: "arrow.clockwise") {
                        Task { await model.refreshHistory() }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.historyLoading)
                    if model.historyNeedsSignIn && model.canReconnectHistory {
                        Button(copy.native(.signInAgain), systemImage: "person.crop.circle") {
                            Task { await model.reconnectHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.historyLoading)
                    }
                    if model.historyNextCursor != nil {
                        Button(copy.native(.loadMore), systemImage: "chevron.down") {
                            Task { await model.loadMoreHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.historyLoading)
                    }
                }
                NativeReadingSection(title: copy.native(.localDevice)) {
                    Text(
                        copy[.historyLocalDatesNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmedOnDevice) { saved in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.circle")
                                    .foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(saved.lessonId)).font(.headline)
                                Text(
                                    saved.submission.startedAt,
                                    format: .dateTime.year().month().day())
                                if let result = saved.result {
                                    Text(
                                        copy.historyScore(
                                            scorePercent: result.scorePct,
                                            xp: result.rewards.xpEarned, confirmedOnDevice: true)
                                    )
                                }
                                Text(
                                    copy[.historyLocalAcknowledgement]
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(presentation.onDevice) { saved in
                            savedAnswer(saved)
                        }
                        if presentation.onDevice.isEmpty && presentation.confirmedOnDevice.isEmpty {
                            Text(copy[.historyNoAdditional])
                        }
                    } else if model.historyError != nil {
                        Text(
                            copy[.historyLocalUnverified]
                        )
                    }
                    if model.lesson != nil {
                        Label(
                            model.outcome == nil
                                ? copy[.historyCurrentLocal] : copy[.historyCurrentSubmitted],
                            systemImage: "doc.text")
                        Button(copy.resume, systemImage: "play.circle") {
                            model.selectedTab = .learn
                            columns = .detailOnly
                            compactColumn = .detail
                        }
                        .frame(minHeight: 44)
                    }
                }
                NativeReadingSection(title: copy.native(.readiness)) {
                    if let profile = model.profile {
                        LabeledContent(copy.native(.confirmedXP), value: "\(profile.xp)")
                    }
                    if let path = model.path {
                        Text(path.trackName)
                        LabeledContent(copy.native(.readiness), value: "\(path.readinessScore) %")
                    }
                    Text(
                        copy[.historyNoBalanceChange]
                    )
                    Text(
                        copy[.historyReadinessNote]
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    if model.path == nil {
                        Text(
                            copy[.historyReadinessUnknown]
                        )
                    }
                }
            }
            .navigationTitle(copy.progressAndHistory)
            .task {
                if !model.historyAttempted { await model.refreshHistory() }
            }
        }

        private var coverageSummary: some View {
            NativeReadingSection(title: copy.native(.activityCoverage)) {
                if let path = model.path {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(path.trackName).font(.headline)
                    LabeledContent(
                        copy.native(.completedActivities),
                        value: copy.coverageCount(
                            completed: coverage.completedActivities, total: coverage.totalActivities
                        ))
                    LabeledContent(
                        copy.native(.completedUnits),
                        value: copy.coverageCount(
                            completed: coverage.completedUnits, total: coverage.totalUnits))
                    Text(
                        copy[.historyCoverageSnapshot]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(
                        copy[.historyCoverageUnknown]
                    )
                }
                if let lesson = model.lesson {
                    let selectedCount = lesson.questions.filter {
                        model.selections[$0.id] != nil
                    }.count
                    Text(lesson.title).font(.headline)
                    LabeledContent(
                        copy.native(.localAnswers),
                        value: copy.questionCount(
                            selected: selectedCount, total: lesson.questions.count))
                    Text(
                        copy[.historySelectionNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    copy[.historyGoalUnchanged]
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }

        private func activityStatus(_ status: NodeStatus) -> String {
            switch status {
            case .locked: copy.native(.lockedActivity)
            case .available: copy.native(.availableActivity)
            case .inProgress: copy[.masteryLearning]
            case .completed: copy.native(.completedActivity)
            case .mastered: copy[.masteryMastered]
            }
        }

        @ViewBuilder private var savedAnswers: some View {
            if !model.queue.isEmpty {
                Section(copy[.historySavedAnswers]) {
                    ForEach(model.queue) { saved in
                        savedAnswer(saved)
                    }
                }
            }
        }

        private func savedAnswer(_ saved: SavedSubmission) -> some View {
            NativeReadingCard {
                Text(lessonTitle(saved.lessonId)).font(.headline)
                switch saved.status {
                case .pendingCorrection:
                    Label(copy[.pendingCorrection], systemImage: "clock")
                        .foregroundStyle(NativePrism.pending)
                    Button(copy.retry) {
                        Task { await model.retry(saved) }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                case .corrected:
                    if let result = saved.result {
                        Text(copy.confirmedScore(result.scorePct))
                        ForEach(result.results) { item in
                            Text(item.explanation)
                        }
                    }
                case .failed:
                    Label(
                        copy[.historySubmissionRejected],
                        systemImage: "exclamationmark.triangle")
                    Text(
                        copy[.historyLocalStatusNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        private func trackTitle(_ id: String) -> String {
            model.tracks.first(where: { $0.id.lowercased() == id.lowercased() })?.title ?? id
        }

        private func lessonTitle(_ id: String) -> String {
            if let lesson = model.lesson, lesson.id == id { return lesson.title }
            if let lesson = model.path?.units.flatMap(\.lessons).first(where: { $0.id == id }) {
                return lesson.title
            }
            return model.offlinePack?.lessons.first(where: { $0.id == id })?.title ?? id
        }

        @ViewBuilder private func activeGoalSection(_ track: Track) -> some View {
            let state = NativeActiveGoalPresentation(
                targetID: track.id, confirmedID: model.profile?.activeTrackId,
                savingID: savingGoalID, busy: model.busy)
            Section(copy.native(.activeGoal)) {
                NativeCertificationCrest(code: track.code, compact: true)
                Label(state.status(copy), systemImage: state.symbol)
                    .accessibilityIdentifier("active-goal-status")
                if let current = model.profile?.activeTrackId,
                    current.lowercased() != track.id.lowercased()
                {
                    Text(
                        "\(copy.native(.goalConfirmed)) · \(model.tracks.first(where: { $0.id == current })?.title ?? current)"
                    )
                    .foregroundStyle(.secondary)
                }
                if model.profile?.activeTrackId?.lowercased() == track.id.lowercased() {
                    NativePrimaryButton(title: copy.myLearning, symbol: "book") {
                        showMyLearning()
                    }
                    .disabled(model.busy)
                    .accessibilityIdentifier("open-confirmed-learning-goal")
                } else {
                    NativePrimaryButton(title: state.action(copy), symbol: "scope") {
                        savingGoalID = track.id
                        Task {
                            await model.chooseActiveTrack(track)
                            savingGoalID = nil
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(!state.canChoose)
                    .accessibilityIdentifier("choose-active-goal")
                }
            }
        }

        private var session: some View {
            Group {
                if let track = model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.lesson?.trackId)
                }), !track.learningAvailable {
                    ContentUnavailableView(
                        copy[.practiceUnavailable], systemImage: "book.closed",
                        description: Text(copy[.practiceUnavailableNote])
                    )
                } else if let lesson = model.lesson,
                    selectedTrack == nil || selectedTrack == lesson.trackId,
                    selectedLesson == nil || selectedLesson == lesson.id
                {
                    ScrollViewReader { reader in
                        NativeReadingPage {
                            Text(lesson.title).font(.title).bold()
                                .accessibilityAddTraits(.isHeader)
                                .id("session-reading-start")
                            if let track = model.tracks.first(where: { $0.id == lesson.trackId }) {
                                NativeCertificationCrest(code: track.code, compact: true)
                            }
                            learningCycle
                            NativeQuestionProgress(
                                selected: lesson.questions.filter { model.selections[$0.id] != nil }
                                    .count,
                                total: lesson.questions.count,
                                title: copy.questionCount(
                                    selected: lesson.questions.filter {
                                        model.selections[$0.id] != nil
                                    }.count,
                                    total: lesson.questions.count))
                            if let node = model.path?.units.flatMap(\.lessons).first(where: {
                                $0.id == lesson.id
                            }) {
                                LabeledContent(
                                    copy.native(.duration),
                                    value: "\(copy.minutes(node.estMinutes))")
                            }
                            Label(copy.native(.understandStage), systemImage: "text.book.closed")
                                .font(.subheadline).foregroundStyle(NativePrism.tint)
                            DisclosureGroup(copy.native(.readAloud)) {
                                NativeLessonAudioControls(
                                    content: NativeLessonReadingContent(
                                        lessonTitle: lesson.title,
                                        blocks: lesson.blocks.map {
                                            (type: $0.type, title: $0.title, body: $0.body)
                                        }),
                                    ownerID: model.profile?.id
                                )
                                .id(lesson.id)
                            }
                            .frame(minHeight: 44)
                            Text(
                                copy.native(.answerInstruction)
                            )
                            .foregroundStyle(.secondary)
                            ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                                if let title = block.title {
                                    Text(title).font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                if let body = block.body {
                                    Text(.init(body)).textSelection(.enabled)
                                }
                                if let code = block.code {
                                    ScrollView(.horizontal) {
                                        Text(code).font(.body.monospaced()).textSelection(.enabled)
                                    }
                                    .padding(16)
                                    .background(
                                        NativePrism.surface,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                if let question = block.check {
                                    questionView(question)
                                }
                            }
                            if let outcome = model.outcome {
                                switch outcome {
                                case .pendingCorrection:
                                    NativeReadingCard {
                                        Label(
                                            copy[.pendingCorrection],
                                            systemImage: "clock"
                                        )
                                        .font(.headline).foregroundStyle(NativePrism.pending)
                                        Text(
                                            copy.native(.pendingCorrectionHint)
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    NativeReadingSection(title: copy.native(.confirmedResult)) {
                                        NativeReadinessRing(
                                            percent: result.scorePct, title: copy.native(.score),
                                            accent: NativePrism.confirmed)
                                        Label(
                                            copy.confirmed, systemImage: "checkmark.seal"
                                        )
                                        .foregroundStyle(NativePrism.confirmed)
                                        LabeledContent(
                                            copy.native(.score), value: "\(result.scorePct) %")
                                        LabeledContent(
                                            copy.native(.earned),
                                            value: "\(result.rewards.xpEarned)")
                                        if let reviewDate = result.nextReviewDueAt {
                                            LabeledContent(
                                                copy.native(.nextReview),
                                                value: reviewDate.formatted(
                                                    date: .abbreviated, time: .shortened))
                                        }
                                    }
                                    ForEach(result.results) { item in
                                        NativeReadingCard {
                                            Label(
                                                item.correct
                                                    ? copy.native(.answerCorrect)
                                                    : copy.native(.reviewNeeded),
                                                systemImage: item.correct
                                                    ? "checkmark.circle" : "book"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(
                                                item.correct
                                                    ? NativePrism.confirmed : NativePrism.pending)
                                            if let question = lesson.blocks.compactMap(\.check)
                                                .first(where: { $0.id == item.itemId })
                                            {
                                                Text(.init(question.stem)).font(.headline)
                                            }
                                            Text(.init(item.explanation)).textSelection(.enabled)
                                            if let question = lesson.questions.first(where: {
                                                $0.id == item.itemId
                                            }), let selected = model.selections[item.itemId],
                                                let option = question.options.first(where: {
                                                    $0.id == selected
                                                })
                                            {
                                                LabeledContent(
                                                    copy.native(.selectedAnswer),
                                                    value: option.label)
                                                if let correct = item.correctAnswer {
                                                    Text(
                                                        "\(copy.native(.correctAnswer)) · "
                                                            + question.options.filter {
                                                                correct.contains($0.id)
                                                            }.map(\.label).joined(separator: " · "))
                                                }
                                            }
                                            LabeledContent(
                                                copy.native(.masteryChange),
                                                value: item.masteryDelta.formatted(
                                                    .number.precision(.fractionLength(0...3))
                                                        .locale(copy.language.locale)))
                                            tutorContent(for: item.itemId)
                                        }
                                    }
                                    NativeReadingSection(title: copy[.continueLearning]) {
                                        Button(
                                            copy.native(.readAgain), systemImage: "text.book.closed"
                                        ) {
                                            reader.scrollTo("session-reading-start", anchor: .top)
                                        }
                                        .frame(minHeight: 44)
                                        .accessibilityIdentifier("read-confirmed-lesson-again")
                                        if let node = model.path?.units.flatMap(\.lessons).first(
                                            where: {
                                                $0.id == lesson.id && $0.canOpen
                                            }), model.path?.trackId == lesson.trackId
                                        {
                                            let destination = NativeActivityDestination(
                                                lessonID: lesson.id, title: lesson.title)
                                            NativePrimaryButton(
                                                title: destination.actionTitle(copy.practiceAgain),
                                                symbol: "arrow.clockwise"
                                            ) {
                                                requestLesson(node)
                                            }
                                            .disabled(model.busy || loadingLessonID != nil)
                                            Text(
                                                copy.native(.newAttemptHint)
                                            )
                                            .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text(
                                                copy.native(.practiceAgainHint)
                                            )
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            if model.outcome == nil {
                                NativePrimaryButton(
                                    title: copy.submitAnswer, symbol: "paperplane"
                                ) {
                                    Task { await model.submit() }
                                }
                                .disabled(!model.canSubmit)
                                .accessibilityIdentifier("submit-for-correction")
                                .padding(16)
                                .frame(maxWidth: 700)
                                .frame(maxWidth: .infinity)
                                .background(NativePrism.surface)
                            }
                        }
                    }
                } else if let selectedLesson,
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == selectedLesson
                    })
                {
                    if loadingLessonID == node.id {
                        ProgressView(copy.loading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                copy.native(.lessonUnavailable),
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    copy.native(.lessonLoadFailure)
                                )
                            )
                            Button(copy.retry, systemImage: "arrow.clockwise") {
                                requestLesson(node)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        copy.native(.oneSession), systemImage: "book",
                        description: Text(copy.native(.chooseActivity))
                    )
                }
            }
            .navigationTitle(copy.startSession)
        }

        private var learningCycle: some View {
            let phases: [AppInterfaceCopy.NativeLabel] = [
                .learnStage, .understandStage, .recallApplyStage, .feedbackStage, .masterStage,
            ]
            let active = model.outcome == nil ? 2 : 3
            return ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        Text(copy.native(phase))
                            .font(.subheadline.weight(index == active ? .semibold : .regular))
                            .foregroundStyle(index == active ? NativePrism.tint : .secondary)
                            .accessibilityAddTraits(index == active ? .isSelected : [])
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }

        private func questionView(_ question: QuizItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(copy.native(.questionType)) · \(copy.native(.multipleChoice))")
                    .font(.caption).foregroundStyle(.secondary)
                Text(.init(question.stem)).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        model.select(option, question: question)
                    } label: {
                        NativeAnswerLabel(
                            text: option.label, index: index,
                            selected: model.selections[question.id] == option.id
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(
                        NativeChoiceButtonStyle(
                            isSelected: model.selections[question.id] == option.id)
                    )
                    .disabled(model.outcome != nil || model.busy)
                    .accessibilityAddTraits(
                        model.selections[question.id] == option.id ? .isSelected : []
                    )
                    .accessibilityValue(
                        model.selections[question.id] == option.id
                            ? copy.native(.selected) : copy.native(.notSelected))
                }
            }
            .onAppear { model.questionAppeared(question.id) }
        }
    }
#endif
