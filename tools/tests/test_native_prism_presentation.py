"""Source contracts only: these checks do not render or type-check SwiftUI."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "apps/apple/CertigoNative/Sources"


class NativePrismPresentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = (SOURCES / "CertigoNativeApp.swift").read_text(encoding="utf-8")
        cls.pilot = (SOURCES / "NativeEditorialPilotView.swift").read_text(encoding="utf-8")

    def test_native_palette_uses_the_existing_prism_spectrum(self):
        flutter = (ROOT / "packages/prism_ui/lib/src/tokens/prism_colors.dart").read_text(
            encoding="utf-8"
        )
        for native, dart, extra in (
            ("ink", "spectrumInk", "info"),
            ("glow", "spectrumGlow", "infoGlow"),
        ):
            expected = re.search(rf"{dart} = <Color>\[(.*?)\];", flutter, re.S)[1]
            extra_hex = re.search(rf"\b{extra} = Color\(0xFF([A-F0-9]{{6}})\)", flutter)[1]
            actual = re.search(rf"let {native}: \[UInt32\] = \[(.*?)\]", self.app, re.S)[1]
            self.assertEqual(
                re.findall(r"0xFF([A-F0-9]{6})", expected) + [extra_hex],
                re.findall(r"0x([A-F0-9]{6})", actual),
            )
        self.assertIn("traits.accessibilityContrast == .high", self.app)
        self.assertIn("traits.userInterfaceStyle == .dark", self.app)

    def test_material_is_gated_and_reading_stays_opaque(self):
        primary = self.app.split("struct NativePrimaryButton:", 1)[1].split(
            "struct NativeChoiceButtonStyle:", 1
        )[0]
        self.assertIn("accessibilityReduceTransparency", primary)
        self.assertIn("#available(iOS 26.0, *), !reduceTransparency", primary)
        self.assertIn(".glassProminent", primary)
        self.assertIn(".borderedProminent", primary)
        card = self.app.split("struct NativeReadingCard<", 1)[1].split(
            "struct NativePrimaryButton:", 1
        )[0]
        self.assertIn("NativePrism.surface", card)
        self.assertNotIn("Material", card)
        self.assertNotIn("glass", card.lower())
        self.assertNotIn(".lineLimit(", self.pilot)

    def test_real_actions_and_confirmation_boundaries_remain_wired(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for action in (
            "model.select(option, question: question)", "model.submit()", "model.retry(saved)",
            "model.refreshHistory()", "model.loadMoreHistory()", "model.reconnectHistory()",
            "model.chooseActiveTrack(track)", "model.restoreDownloadedActivity()",
        ):
            self.assertIn(action, root)
        self.assertIn(".disabled(!model.canSubmit)", root)
        self.assertIn(".disabled(model.outcome != nil || model.busy)", root)
        self.assertIn("? .isSelected : []", root)
        self.assertIn("case .pendingCorrection:", root)
        self.assertIn("case .corrected(let result):", root)
        self.assertIn("copy.native(.pendingCorrectionHint)", root)
        self.assertIn("confirmedOnDevice", root)
        self.assertIn("NavigationSplitView", root)
        self.assertIn("compactColumn = .detail", root)

    def test_editorial_actions_use_the_existing_model(self):
        for action in (
            "model.loadEditorialPilot()", "model.accessEditorialPilotLesson(lesson.id)",
            "model.markEditorialPilotLessonRead(lesson.id)",
        ):
            self.assertIn(action, self.pilot)
        self.assertIn(".disabled(model.busy || !accessRecorded)", self.pilot)
        self.assertIn("NativePrimaryButton", self.pilot)

    def test_catalog_uses_real_metadata_and_local_search(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for marker in (
            ".searchable(text: $query", "$catalogFilter.query",
            'Picker(copy.native(.codeFamily)', "copy.native(.availableOnly)",
            "visibleTracks.count", "copy[.noMatchingTracks]",
            "copy[.clearFilters]", "catalogFilter.clear()", "catalogFilter.includes(",
            "copy.native(.catalogScope)",
        ):
            self.assertIn(marker, self.app)
        self.assertIn("onChange(of: model.profile?.id", root)
        self.assertIn("Language badges require explicit catalog metadata", self.app)
        self.assertNotIn("Task { await model.search", root)

    def test_learning_intentions_and_denominators_stay_distinct(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for marker in (
            "copy.native(.nextSession)", "copy.native(.learningPlan)",
            "copy.native(.reviewPractice)", "copy.native(.goalOverview)",
            "copy.native(.activityCoverage)", "copy.native(.confirmedSessions)",
            "copy.native(.readiness)", "coverage.totalActivities",
            "coverage.totalUnits", "lesson.questions.count",
            "copy[.historyReadinessNote]", "copy[.historyReadinessUnknown]",
            "copy.native(.lockedHint)",
        ):
            self.assertIn(marker, root)
        self.assertRegex(root, r"Button\(\s*copy\.native\(\.readAgain\)")
        self.assertIn("title: destination.actionTitle(copy.practiceAgain)", root)
        self.assertIn('case .corrected(let result):', root)
        self.assertIn('reader.scrollTo("session-reading-start"', root)
        self.assertIn("copy.native(.coachPrivacy)", root)
        self.assertIn("await model.requestTutorExplanation(itemId: itemID)", root)
        self.assertIn("copy.native(.sharingConsent)", root)
        self.assertIn('reader.scrollTo("editorial-practice"', self.pilot)

    def test_choice_style_is_shared_not_nested_in_the_primary_button(self):
        primary = self.app.split("struct NativePrimaryButton:", 1)[1].split(
            "struct NativeChoiceButtonStyle:", 1
        )[0]
        # Both structs must be siblings for the unqualified choice-style call sites.
        self.assertEqual(primary.count("{"), primary.count("}"))
        root = self.app.split("private struct NativeRoot:", 1)[1].split(
            "struct NativeLessonAudioControls:", 1
        )[0]
        styles = set(re.findall(r"\.buttonStyle\((\w+Style)\(", root))
        self.assertIn("NativeChoiceButtonStyle", styles)
        for style in styles:
            declaration = re.search(
                rf"^([ ]*)(?:(?:private|fileprivate) )?struct {style}:", self.app, re.M
            )
            self.assertIsNotNone(declaration, style)
            # swift-format indents the file-level SwiftUI conditional by four spaces.
            self.assertEqual(declaration[1], "    ", f"{style} must be file-level")
        self.assertIn("style: .continuous", self.app)
        self.assertIn(".symbolRenderingMode(.hierarchical)", self.app)

    def test_editorial_chrome_is_localized_without_translating_content(self):
        for marker in (
            "NativeContentLanguageBadges(languages: [snapshot.pilot.locale])",
            "copy.native(.readAloud)", "copy.native(.markRead)", "copy.native(.sourcesLimits)",
            "copy.native(.readAgain)", "copy.native(.formativePractice)",
            "copy.native(.historyUnconfirmed)",
            "Text(lesson.hook)", "Text(lesson.practice.prompt)",
            "Text(lesson.practice.feedback)", "Text(source.supports)",
            "Text(source.limits)",
        ):
            self.assertIn(marker, self.pilot)
        for old_label in ('"Marquer comme lue"', '"Écouter la leçon"', '"Fermer"'):
            self.assertNotIn(old_label, self.pilot)
        criteria = self.pilot.split('title: copy.native(.selfCheck)', 1)[1].split(
            'title: copy.native(.takeaway)', 1
        )[0]
        self.assertNotIn("checkmark", criteria)
        self.assertIn("item.offset + 1", criteria)

    def test_busy_material_and_symbol_layers_respect_readability(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        busy = root.split(".safeAreaInset(edge: .bottom)", 1)[1].split(
            ".alert(", 1
        )[0]
        self.assertIn("if reduceTransparency", busy)
        self.assertIn("NativePrism.surface", busy)
        page = self.app.split("struct NativeReadingPage<", 1)[1].split(
            "private struct NativeCatalogSearch:", 1
        )[0]
        self.assertNotIn(".symbolRenderingMode(.hierarchical)", page)
        self.assertIn(".symbolRenderingMode(.monochrome)", self.app)

    def test_resuming_an_activity_never_reloads_it(self):
        resume = self.app.split("private func resumeCurrentActivity(", 1)[1].split(
            "private func requestPath(", 1
        )[0]
        self.assertNotIn("Task", resume)
        self.assertNotIn("await", resume)
        self.assertIn("resumeTrackID = lesson.trackId", resume)
        self.assertIn("selectedLesson = lesson.id", resume)
        self.assertIn("self.resumeTrackID = nil", self.app)

    def test_app_language_preference_is_persisted_and_applied_at_the_root(self):
        for marker in (
            "AppLanguagePreference.load(from: .standard)",
            "$0.save(to: .standard)",
            ".environment(\\.locale, effectiveLanguage.locale)",
            "AppInterfaceCopy(language: effectiveLanguage)",
            "preference.effectiveLanguage(fromPreferredLanguages: preferredLanguages)",
            "preferredLanguages = Locale.preferredLanguages",
            "copy.appLanguage,\n                    selection:",
            "ForEach(AppLanguage.allCases, id: \\.rawValue)",
            "language.nativeDisplayName",
            "language.localizedDisplayName(in: copy.language)",
            "AppLanguagePreference.system.rawValue",
            'accessibilityIdentifier("app-interface-language")',
            "copy.contentLanguageNote",
        ):
            self.assertIn(marker, self.app)
        self.assertIn("NativeAppLanguagePicker()", self.app.split("private struct NativeEntry:", 1)[1].split("#if canImport(UIKit)", 1)[0])
        self.assertIn("Section(copy.appLanguage) { NativeAppLanguagePicker() }", self.app)
        self.assertNotIn('Locale(identifier: "en")', self.app)

    def test_interface_copy_reaches_real_and_demo_navigation_and_actions(self):
        root = self.app.split("private struct NativeRoot:", 1)[1].split(
            "struct NativeLessonAudioControls:", 1
        )[0]
        demo = self.app.split("private struct NativeDemoRoot:", 1)[1].split(
            "private struct NativeDemoSnapshot:", 1
        )[0]
        for value in (
            "copy.learn", "copy.coach", "copy.social", "copy.profile",
            "copy.myLearning", "copy.explore", "copy.friends", "copy.teams",
            "copy.progressAndHistory", "copy.settings", "copy.accountDeletion",
            "copy.resume", "copy.startSession", "copy.practiceAgain", "copy.submitAnswer",
            "copy.retry", "copy.loading", "copy[.pendingCorrection]", "copy.confirmed",
        ):
            self.assertIn(value, root, value)
        for value in (
            "copy.learn", "copy.coach", "copy.social", "copy.profile",
            "copy.myLearning", "copy.explore", "copy.friends", "copy.teams",
            "copy.progressAndHistory", "copy.settings", "copy.resume",
            "copy.submitAnswer", "copy.retry", "copy.pending", "copy.confirmed",
        ):
            self.assertIn(value, demo, value)
        self.assertIn("NativeAppLanguagePicker()", root)
        self.assertIn("NativeAppLanguagePicker()", demo)

    def test_editorial_pilot_inherits_locale_and_content_language_disclosure(self):
        self.assertIn("@Environment(\\.nativeInterfaceCopy) private var copy", self.pilot)
        self.assertIn("Text(copy.contentLanguageNote)", self.pilot)
        self.assertIn('NativeContentLanguageBadges(languages: ["fr-FR"])', self.pilot)
        self.assertIn("Text(lesson.hook)", self.pilot)
        self.assertIn("Text(lesson.practice.prompt)", self.pilot)
        self.assertIn("Text(source.supports)", self.pilot)
        self.assertIn("date(markedReadAt, locale: copy.language.locale)", self.pilot)
        self.assertNotIn("English interface labels", self.pilot)
        self.assertIn("case .pendingCorrection: copy[.pendingCorrection]", self.app)
        self.assertIn("case .corrected: copy.confirmed", self.app)

    def test_radar_code_hints_never_create_catalog_or_release_metadata(self):
        for category in (
            "cloud-hyperscalers", "ai-foundation-models", "apple-mobile",
            "data-analytics", "devops-cloud-native-dev", "cybersecurity-networking",
            "enterprise-delivery",
        ):
            self.assertIn(category, self.app)
        self.assertIn('Picker(copy.native(.codeCategory), selection: $catalogFilter.category)', self.app)
        self.assertIn("model.tracks.contains", self.app)
        self.assertIn("Groups come from codes", self.app)
        self.assertIn("Announced and planned statuses are not supplied", self.app)
        self.assertIn("code == $0 || code.hasPrefix($0 + \"-\")", self.app)
        self.assertNotIn("track.status", self.app)
        self.assertNotIn("track.provider", self.app)

    def test_international_copy_has_eight_explicit_translations_per_native_label(self):
        copy = self.app.split("enum NativeLabel:", 1)[1].split(
            "struct NativeContentLanguageBadges:", 1
        )[0]
        rows = re.findall(r"case \.(\w+):\s*row = \[(.*?)\]", copy, re.S)
        self.assertGreater(len(rows), 100)
        for key, row in rows:
            self.assertEqual(len(re.findall(r'"(?:[^"\\]|\\.)*"', row)), 8, key)
        self.assertIn("precondition(row.count == 8)", copy)
        self.assertIn("category.title(copy)", self.app)
        self.assertIn("prompt: copy[.searchPlaceholder]", self.app)
        self.assertIn("track.languages ?? []", self.app)

    def test_native_copy_call_sites_reference_declared_keys_in_all_build_modes(self):
        native_enum = self.app.split("enum NativeLabel:", 1)[1].split("func native(", 1)[0]
        shared_copy = (
            ROOT / "apps/apple/CertigoKit/Sources/CertigoDomain/AppLanguage.swift"
        ).read_text(encoding="utf-8")
        shared_enum = shared_copy.split("public enum Key:", 1)[1].split("}", 1)[0]

        def cases(declaration):
            return {
                name.strip()
                for group in re.findall(r"\bcase\s+(.*?)(?=\bcase\b|}|\Z)", declaration, re.S)
                for name in group.split(",")
                if name.strip()
            }

        native_keys = cases(native_enum)
        shared_keys = cases(shared_enum)
        self.assertGreater(len(native_keys), 100)
        self.assertIn("done", shared_keys)
        # Inspect source, including SwiftUI/DEBUG/Distribution branches excluded on Linux.
        for path in sorted(SOURCES.glob("*.swift")):
            source = path.read_text(encoding="utf-8")
            for pattern, declared in (
                (r"\bcopy\.native\(\s*\.(\w+)\s*\)", native_keys),
                (r"\bcopy\[\s*\.(\w+)\s*\]", shared_keys),
            ):
                for match in re.finditer(pattern, source):
                    self.assertIn(match[1], declared, f"{path.name}: {match[0]}")

    def test_demo_primary_decisions_reserve_space_above_the_native_tab_bar(self):
        goal = self.app.split("private func goalDetail(", 1)[1].split(
            "private var preparation:", 1
        )[0]
        exercise = self.app.split("private var exercise:", 1)[1].split(
            "private var selectedAnswer:", 1
        )[0]
        for source, action in ((goal, "flow.choose(goal)"), (exercise, "flow.submit()")):
            before, inset = source.split(".safeAreaInset(edge: .bottom)", 1)
            self.assertNotIn(action, before)
            self.assertIn(action, inset)
            self.assertNotIn(".ignoresSafeArea", source)
            self.assertIn(".frame(maxWidth: 680)", inset)
        self.assertIn("flow.phase == .answering", exercise)
        self.assertIn(".disabled(!flow.canSubmit)", exercise)
        self.assertIn('.accessibilityIdentifier("demo-submit")', exercise)

    def test_demo_history_uses_a_compact_localized_navigation_title(self):
        history = self.app.split("private var demoHistory:", 1)[1].split(
            "private struct DemoReadingSection:", 1
        )[0]
        self.assertIn(".navigationTitle(copy.native(.demoHistory))", history)
        self.assertNotIn(".navigationTitle(copy.progressAndHistory)", history)

    def test_connected_goal_and_coach_actions_open_my_learning_not_stale_explore(self):
        helper = self.app.split("private func showMyLearning()", 1)[1].split(
            "private func requestPath(", 1
        )[0]
        for marker in (
            "navigation.learn = .myLearning", "model.selectedTab = .learn",
            "columns = .all", "compactColumn = .sidebar",
        ):
            self.assertIn(marker, helper)
        coach = self.app.split("private var coach: some View", 1)[1].split(
            "private var coachPhase:", 1
        )[0]
        self.assertIn("showMyLearning()", coach)
        self.assertIn("model.outcome == nil ? nil : Text(coachPhase)", coach)
        goal = self.app.split("private func activeGoalSection(", 1)[1].split(
            "private var session:", 1
        )[0]
        self.assertIn("model.profile?.activeTrackId?.lowercased() == track.id.lowercased()", goal)
        self.assertIn("showMyLearning()", goal)
        self.assertIn('.accessibilityIdentifier("open-confirmed-learning-goal")', goal)
        self.assertIn("await model.chooseActiveTrack(track)", goal)
        self.assertIn(".disabled(!state.canChoose)", goal)

    def test_connected_track_uses_code_in_bar_and_full_title_in_reading_content(self):
        path = self.app.split("private var path: some View", 1)[1].split(
            "private var progressHistory:", 1
        )[0]
        self.assertIn("Text(track.title).font(.title2.bold())", path)
        self.assertIn("})?.code ?? copy.native(.learningPath)", path)
        self.assertIn(".navigationBarTitleDisplayMode(.inline)", path)
        self.assertNotIn("selectedTrack.map(trackTitle)", path)

    def test_secondary_messages_resolve_in_the_current_interface_language(self):
        model = (SOURCES / "NativeModel.swift").read_text(encoding="utf-8")
        for name in ("historyError", "tutorExplanationError", "deletionMessage", "errorMessage"):
            self.assertIn(f"var {name}: NativePresentationMessage?", model)
        self.assertIn("case http(Int)", model)
        self.assertIn("copy.requestRejected(httpStatus: status)", model)
        self.assertNotIn('errorMessage = "', model)
        self.assertNotIn('deletionMessage = "', model)
        self.assertIn("message.resolved(using: copy)", self.app)
        self.assertIn("error.resolved(using: copy)", self.app)
        self.assertIn("speech.state.label(copy)", self.app)
        self.assertIn("private(set) var issue: AppInterfaceCopy.Key?", self.app)
        self.assertIn("Text(copy[issue])", self.app)
        self.assertNotIn("return error.localizedDescription", self.app)
        self.assertIn("copy[.deletionCleanupIncomplete]", self.app)
        self.assertIn("copy.deletionProgress(", self.app)
        self.assertIn("copy.historyLoaded(", self.app)
        self.assertIn("copy.historyScore(", self.app)
        self.assertIn("copy.coverageCount(", self.app)
        self.assertIn("copy.questionCount(", self.app)
        self.assertIn("issue: AppInterfaceCopy.NativeLabel?", self.pilot)

    def test_secondary_ui_literals_are_localized_and_source_content_stays_declared(self):
        ui = self.app.split("#if canImport(SwiftUI)", 1)[1]
        # Stored fixtures and persistence raw values are source content, not application chrome.
        before_fixtures, remainder = ui.split("// A demo-only state machine:", 1)
        after_fixtures = remainder.split("private struct NativeAccountDeletionView:", 1)[1]
        for source in (before_fixtures, after_fixtures, self.pilot):
            for literal in re.findall(
                r'(?:Text|Label|Button|Section|Picker|ContentUnavailableView|'
                r'NativeReadingSection|NativeEntryHeading)\(\s*(?:title:\s*)?'
                r'"((?:[^"\\]|\\.)*)"', source
            ):
                if "\\(" in literal:
                    continue
                self.assertIn(
                    literal, {"Certigo", "Assistants IA responsables"},
                    f"Unlocalized application chrome: {literal}",
                )
        self.assertIn('NativeContentLanguageBadges(languages: ["fr"])', self.app)
        self.assertIn("progress.accessibilityLabel(copy)", self.app)
        self.assertIn("flow.activitySummary(copy)", self.app)
        self.assertIn("goal.displayTitle(copy)", self.app)
        self.assertIn("state.status(copy)", self.app)
        self.assertIn("state.action(copy)", self.app)
        self.assertIn("copy.minutes(", self.app)
        self.assertIn("copy.minutes(", self.pilot)

    def test_coach_uses_confirmed_answers_and_displays_complete_server_explanations(self):
        model = (SOURCES / "NativeModel.swift").read_text(encoding="utf-8")
        request = model.split("func requestTutorExplanation(", 1)[1].split(
            "func submit()", 1
        )[0]
        for marker in (
            "case .corrected(let result) = outcome", "submittedRequest.answers.first",
            "selected: answer.selected", "submittedRequest.publicManifestId",
            "tutorRequestGeneration == requestID", "profile?.id == owner",
            "attemptID == attempt", "explanation.itemId == itemId",
        ):
            self.assertIn(marker, request, marker)
        for field in (
            "explanation.headline", "explanation.points", "explanation.encouragement",
            "explanation.recommendation", "explanation.source",
            "explanation.personalization.attempts", "explanation.personalization.accuracyPct",
            "explanation.personalization.recurringStruggle",
        ):
            self.assertIn(field, self.app)
        self.assertIn("model.isRequestingTutorExplanation", self.app)
        self.assertNotIn("AI assistance is not active", self.app)

    def test_review_study_plan_and_assessment_remain_source_honest(self):
        model = (SOURCES / "NativeModel.swift").read_text(encoding="utf-8")
        for marker in (
            "SmartReviewAdvisor.recommend(", "historyPresentation?.confirmedOnDevice",
            "result.validated(for: saved.submission)", "studyPlanPrefix(owner:",
            "snapshot.submission = request", "try examStore(",
            "client.submitMockExam(request)", "examGeneration == requestID",
        ):
            self.assertIn(marker, model)
        self.assertIn("Completed does not mean mastered", self.app)
        self.assertIn("No mastered-domain count is inferred", self.app)
        self.assertIn("model.restoreMockExam()", self.app)
        self.assertIn("model.discardMockExam()", self.app)
        self.assertIn("copy.native(.notificationScope)", self.app)
        self.assertNotIn("UNUserNotificationCenter", self.app)

    def test_summary_only_catalog_entries_keep_details_but_cannot_offer_practice(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        self.assertIn("NavigationLink(value: track.id)", root)
        self.assertIn("NativePracticeBadge(available: track.learningAvailable)", root)
        self.assertIn('accessibilityIdentifier("catalog-practice-availability")', self.app)
        path = root.split("private var path: some View", 1)[1].split(
            "private var progressHistory:", 1
        )[0]
        self.assertIn("Text(track.summary)", path)
        self.assertIn("if track.learningAvailable", path)
        self.assertIn("?.learningAvailable != false", path)
        self.assertIn("copy[.practiceUnavailableNote]", path)
        session = root.split("private var session: some View", 1)[1]
        self.assertLess(
            session.index("!track.learningAvailable"),
            session.index("} else if let lesson = model.lesson"),
        )
        self.assertIn("copy[.practiceUnavailable]", session)
        goal = root.split("private var confirmedGoal:", 1)[1].split(
            "private func resumeCurrentActivity(", 1
        )[0]
        self.assertLess(
            goal.index("if !track.learningAvailable"),
            goal.index("NativePrimaryButton"),
        )


if __name__ == "__main__":
    unittest.main()
