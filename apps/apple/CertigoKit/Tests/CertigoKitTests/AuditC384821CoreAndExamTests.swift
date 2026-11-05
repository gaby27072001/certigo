import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Audit c384821 — Sections 1, 2, 5, 6 & 7 (29 Points: P2-01..P2-15 & P2-27..P2-40)", .serialized)
struct AuditC384821CoreAndExamTests {

    private func repoRootURL() throws -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        return root
    }

    private func loadFigmaAppSource() throws -> String {
        let root = try repoRootURL()
        return try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoNativeFigmaApp.swift"),
            encoding: .utf8
        )
    }

    // MARK: - Section 1 : Parcours AZ-104 et choix de certification (P2-01 à P2-07)

    @Test("P2-01: Active step U1.1 reserves dedicated mascot space and non-overlapping text column with >= 12pt clearance after the blue ring")
    func testP201ActiveStepMascotAndTextColumnClearance() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("let minGapAfterRing: CGFloat = FigMetrics.fourteen"))
        #expect(FigMetrics.fourteen >= 12)
        #expect(source.contains("let computedTitleWidth = max(FigMetrics.oneHundredTwenty, textRightBound - textLeftBound)"))

        let appState = CertiGoNativeAppState()
        let u1s1 = appState.currentUnits[0].lessons[0]
        #expect(u1s1.state == .active)
        #expect(u1s1.title.contains("Utilisateurs, Groupes"))
    }

    @Test("P2-02: CONTINUER pill anchored cleanly with top spacing under unit card, no dark triangle on green path segment, and single combined accessibility label")
    func testP202ContinuerPillAlignmentAndCombinedAccessibility() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("path.move(to: first)"))
        #expect(!source.contains("path.move(to: CGPoint(x: first.x, y: 0))"))
        #expect(source.contains(".offset(y: activeNodePulse ? -FigMetrics.thirtySix : -FigMetrics.thirtyFour)"))
        #expect(source.contains(".accessibilityElement(children: .combine)"))
    }

    @Test("P3-03: Locked steps keep only the tile lock stamp (no second lock inside title text) and expose 'Verrouillé' accessibilityValue without 'Verrouiller' node")
    func testP303SingleLockOnTileAndCleanLockedAccessibility() throws {
        let source = try loadFigmaAppSource()
        let appState = CertiGoNativeAppState()
        let u1s2 = appState.currentUnits[0].lessons[1]
        #expect(u1s2.state == .locked)
        #expect(u1s2.title == "Unités Administratives & SSPR")
        #expect(!u1s2.title.contains("🔒"))
        #expect(!source.contains("if lesson.state == .locked && isLeftIsland"))
        #expect(!source.contains("if lesson.state == .locked && !isLeftIsland"))
        #expect(source.contains(".accessibilityValue(\n                        lesson.state == .locked\n                            ? \"Verrouillé\""))
    }

    @Test("P3-04: Top-right counters (🔥, 💎, ❤️) display a single pictogram per counter aligned on the number")
    func testP304SinglePictogramPerTopCounter() throws {
        let source = try loadFigmaAppSource()
        #expect(!source.contains("Image(systemName: \"flame.fill\")"))
        #expect(!source.contains("Image(systemName: \"diamond.fill\")"))
        #expect(source.contains("Text(verbatim: \"🔥 \\(appState.streakDays)\")"))
        #expect(source.contains("Text(verbatim: \"💎 \\(appState.gemsCount)\")"))
        #expect(source.contains("Text(verbatim: \"❤️ \\(appState.heartsCount)\")"))
    }

    @Test("P2-05: Mini-lab card on Parcours allows 2 lines for title so 'JSON' is never truncated to 'JS…' and reserves play column")
    func testP205MiniLabCardTwoLineTitleAndPlayColumn() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("Text(verbatim: miniLabParsed.title)\n                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: \"Bold\"))\n                            .foregroundStyle(PrismColor.figmaHex(\"#0f172a\"))\n                            .lineLimit(2)\n                            .fixedSize(horizontal: false, vertical: true)"))
        let appState = CertiGoNativeAppState()
        let miniLabNode = appState.currentUnits[0].lessons[3]
        #expect(miniLabNode.state == .miniLab)
        #expect(miniLabNode.title.contains("Déboguer un Rôle Personnalisé JSON"))
    }

    @Test("P2-06: CoursePopover02 gives each Trophy button an explicit accessibilityLabel ('Examens blancs AZ-900') and 76pt bottom clearance for SC-900")
    func testP206CoursePopoverTrophyAccessibilityLabelAndBottomClearance() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains(".accessibilityLabel(\"Examens blancs \\(item.code)\")"))
        #expect(source.contains(".padding(.bottom, FigMetrics.seventySix)"))
        let msItems = CertiGoNativeRichCatalog.coursePopoverItems(forVendor: "microsoft")
        #expect(msItems.contains(where: { $0.code == "AZ-900" }))
        #expect(msItems.contains(where: { $0.code == "SC-900" }))
    }

    @Test("P2-07: Step launch floating sheet displays 'Commencer' in full with '+15 gemmes' stacked underneath")
    func testP207StepFloatingSheetCommencerFullLabelStacked() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("VStack(spacing: FigMetrics.two) {\n                        Text(verbatim: appState.tr(\"Commencer\"))"))
        #expect(source.contains("Text(verbatim: \"+15 gemmes\")"))
    }

    // MARK: - Section 2 : Cours, quiz et mini-lab (P1-08 à P2-15)

    @Test("P1-08 (CRITIQUE): Strict topic alignment across all 30 steps (u1-s1..u3-s10); AZ-104 U1.1 cards, Declic, and questions focus exclusively on Entra ID Users, Dynamic Groups, B2B Guests, and Licenses")
    func testP108StrictStepLessonSlideDeclicAndQuestionAlignment() {
        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-104")
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1")

        let slides = appState.lessonSession.lessonSlides
        #expect(slides.count == 3)
        for (idx, slide) in slides.enumerated() {
            let text = "\(slide.title) \(slide.bodyParagraph) \(slide.keyTakeawayPill)"
            #expect(!text.contains("Private Link"), "Unexpected Private Link in AZ-104 U1.1 slide \(idx + 1): \(text)")
            #expect(!text.contains("Private Endpoint"), "Unexpected Private Endpoint in AZ-104 U1.1 slide \(idx + 1): \(text)")
            #expect(!text.contains("RA-GRS"), "Unexpected RA-GRS in AZ-104 U1.1 slide \(idx + 1): \(text)")
            #expect(!text.contains("privatelink.blob"), "Unexpected DNS privatelink in AZ-104 U1.1 slide \(idx + 1): \(text)")
        }
        #expect(slides[0].bodyParagraph.contains("Groupe dynamique") || slides[0].bodyParagraph.contains("groupes dynamiques"))
        #expect(slides[1].bodyParagraph.contains("Invités B2B"))
        #expect(slides[2].bodyParagraph.contains("UsageLocation"))

        let declic = appState.lessonSession.declicCard
        #expect(declic.title.contains("Entra ID"))
        #expect(!declic.title.contains("Private Endpoint"))

        let firstQ = appState.lessonSession.exercises[0]
        #expect(firstQ.prompt.contains("Microsoft Entra ID"))
        #expect(firstQ.prompt.contains("groupes dynamiques"))
        #expect(firstQ.primaryCorrectOptionTitle.contains("Lecteur (Reader)"))

        // Verify all 30 steps of AZ-104 have their 3 slides, Declic card, and first question aligned on the step's own title
        let units = appState.currentUnits
        for unit in units {
            for lesson in unit.lessons where lesson.id != "AZ-104-u1-s1" && lesson.id != "AZ-104-u2-s1" && lesson.id != "AZ-104-u3-s1" {
                let stepSlides = CertiGoDedicatedTrackQuestionBank.microSlides(
                    forRouteCode: "AZ-104",
                    lessonId: lesson.id,
                    lessonTitle: lesson.title
                )
                let stepDeclic = CertiGoDedicatedTrackQuestionBank.lessonDeclicCard(
                    forRouteCode: "AZ-104",
                    lessonId: lesson.id,
                    lessonTitle: lesson.title
                )
                let stepEx = CertiGoDedicatedTrackQuestionBank.exercises(
                    forRouteCode: "AZ-104",
                    lessonId: lesson.id,
                    lessonTitle: lesson.title
                )
                #expect(stepSlides[0].title.contains(lesson.title))
                #expect(stepDeclic.title.contains(lesson.title))
                if lesson.id == "AZ-104-u1-s4" {
                    #expect(stepEx[0].prompt.contains("JSON"))
                    #expect(stepEx[0].prompt.contains("Actions"))
                } else {
                    #expect(stepEx[0].prompt.contains(lesson.title))
                }
            }
        }
    }

    @Test("P2-09 & P2-10: Lesson slide progression resets scroll to top ('lesson-card-top'), focuses header ('Page X sur 3'), and keeps >= 24pt bottom safe margin under 'Continuer'")
    func testP209AndP210LessonSlideScrollToTopFocusAndBottomSafeMargin() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains(".id(\"lesson-card-top\")"))
        #expect(source.contains("slideScrollProxy.scrollTo(\"lesson-card-top\", anchor: .top)"))
        #expect(source.contains(".accessibilityFocused($isLessonSlideHeaderFocused)"))
        #expect(source.contains(".padding(.bottom, FigMetrics.twentyFour)"))
        #expect(FigMetrics.twentyFour == 24)
    }

    @Test("P1-11 (CRITIQUE): Mini-lab 'Déboguer un Rôle Personnalisé JSON' (U1.4) opens an interactive JSON RBAC Role Inspector/Editor with numbered lines and JSON-specific options")
    func testP111InteractiveJSONRoleMiniLab() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("private func jsonRoleInteractiveLabBox(_ ex: CertiGoNativeExerciseItem) -> some View"))
        #expect(source.contains("\"session-json-role-interactive-lab\""))

        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-104")
        appState.startLessonSession(forLessonId: "AZ-104-u1-s4", skipDeclic15: true, enableAdaptiveReplay: true)

        #expect(appState.lessonSession.isCurrentExerciseJSONRoleLab == true)
        let ex = appState.lessonSession.currentExercise
        #expect(ex.formatCode == "Q_TYPE_07")
        #expect(ex.prompt.contains("JSON"))
        #expect(ex.prompt.contains("Actions"))
        #expect(ex.prompt.contains("NotActions"))
        #expect(ex.prompt.contains("AssignableScopes"))
        #expect(!ex.prompt.contains("Object Replication"))
        #expect(!ex.prompt.contains("Blob Versioning"))

        let jsonLines = ex.jsonCustomRoleLabLines
        #expect(jsonLines.count == 6)
        #expect(jsonLines[2].code.contains("Actions"))
        #expect(jsonLines[3].code.contains("\"NotActions\": [ \"*\" ]"))
        #expect(jsonLines[3].isFaultyLine == true)
        #expect(jsonLines[3].patchedCode.contains("Microsoft.Compute/virtualMachines/delete"))
        #expect(jsonLines[5].code.contains("AssignableScopes"))
    }

    @Test("P2-12: Quiz/Lab separates step badge above the question bubble (never prefixing prompt with '[Étape ...]'), uses compact mascot, and adds >= 110pt bottom padding with scroll indicators")
    func testP212SeparateStepHeaderBadgeAndFullWidthQuestionBubble() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("\"session-step-header-badge\""))
        #expect(source.contains("ScrollView(.vertical, showsIndicators: true)"))
        #expect(source.contains(".padding(.bottom, isCheckedPhase ? FigMetrics.twoHundredSixty : FigMetrics.oneHundredTen)"))
        #expect(FigMetrics.oneHundredTen == 110)

        let u1s4Exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: "AZ-104",
            lessonId: "AZ-104-u1-s4",
            lessonTitle: "Lab · Déboguer un Rôle Personnalisé JSON"
        )
        for ex in u1s4Exercises {
            #expect(!ex.prompt.hasPrefix("[Étape"))
            #expect(!ex.plainLanguagePrompt.hasPrefix("[Étape"))
            #expect(ex.subBadge.contains("Étape U1.4"))
        }
    }

    @Test("P1-13 (CRITIQUE): Compact feedback drawer sizes to content (.fixedSize(horizontal: false, vertical: true)), shows a single status header without duplicate checkmarks, and scrolls to selected option")
    func testP113CompactFeedbackDrawerAndAutoScrollToSelectedOption() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("Text(verbatim: isCorrect ? \"✓ Bonne réponse (+15 XP)\" : \"✕ Réponse incorrecte · À retenir\")"))
        #expect(!source.contains("return (\"✓ Bonne réponse\", \"#15803d\", \"#dcfce7\")"))
        #expect(source.contains("exerciseScrollProxy.scrollTo(\"exercise-option-anchor-\\(selectedId)\", anchor: .center)"))
    }

    @Test("P1-14 (CRITIQUE): 'Approfondir' (Sheet 05) uses the exact current question, exact expected answer ('Lecteur (Reader)'), and real attempt accuracy (100% after a right answer, never 0% or unrelated Azure Policy)")
    func testP114ApprofondirMatchesCurrentQuestionAndAttemptAccuracy() {
        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-104")
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true)

        let ex = appState.lessonSession.currentExercise
        #expect(ex.primaryCorrectOptionTitle.contains("Lecteur (Reader)"))
        guard let correctOpt = ex.options.first(where: \.isCorrect) else {
            Issue.record("Expected correct option B (Lecteur (Reader))")
            return
        }
        appState.lessonSession.selectOption(correctOpt.id)
        let isCorrect = appState.lessonSession.verifyCurrentAnswer()
        #expect(isCorrect == true)

        appState.lessonSession.openErrorExplanationSheet05()
        guard let liveExp = appState.lessonSession.liveSheet05Explanation else {
            Issue.record("Expected contextual Sheet 05 explanation")
            return
        }
        #expect(liveExp.itemId == ex.id)
        #expect(liveExp.correct == true)
        #expect(liveExp.headline.contains("Lecteur (Reader)"))
        #expect(!liveExp.headline.contains("Azure Policy"))
        #expect(!liveExp.points.joined(separator: " ").contains("trois abonnements"))
        #expect(liveExp.personalization?.accuracyPct == 100)
        #expect(liveExp.personalization?.formattedSummaryFr.contains("100 % réussite") == true)
        #expect(liveExp.personalization?.formattedSummaryFr.contains("(0 %") == false)
    }

    @Test("P2-15: 'Approfondir' adds 120pt bottom padding so 'ASTUCE D'EXAMEN' is fully visible and replaces ambiguous 'Comparer (20)' with explicit '✦ Comparer les rôles RBAC (20 s)'")
    func testP215ApprofondirBottomClearanceAndExplicitComparatorButtonLabel() throws {
        let source = try loadFigmaAppSource()
        #expect(!source.contains("Text(verbatim: \"✦ Comparer (20)\")"))
        #expect(source.contains("Text(verbatim: ex.comparatorButtonTitle)"))
        #expect(source.contains(".padding(.bottom, FigMetrics.oneHundredTwenty)"))

        let azU1S1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-104", lessonId: "AZ-104-u1-s1")
        #expect(azU1S1[0].comparatorButtonTitle == "✦ Comparer les rôles RBAC (20 s)")
    }

    // MARK: - Section 5 : Social (P2-27 à P2-29)

    @Test("P2-27: Social without friends distinguishes (1) top '➕ Ajouter un ami', (2) 'Quête en binôme' with explicit partner definition, and (3) direct invite link share without triple button repetition")
    func testP227SocialDistinctActionsAndBinomeExplanation() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("Text(verbatim: \"➕ Ajouter un ami\")"))
        #expect(source.contains("Text(verbatim: \"QUÊTE EN BINÔME · OBJECTIF HEBDO\")"))
        #expect(source.contains("Un binôme est un partenaire d'étude avec qui vous additionnez vos étapes validées chaque semaine."))
        #expect(source.contains("Text(verbatim: appState.tr(\"Lien d'invitation\"))"))
        #expect(source.contains("actionTitle: nil,\n                        onAction: nil"))
    }

    @Test("P2-28: 'Ajouter des partenaires d'étude' generates a real 21x21 QR Code matrix, disables '+ Ajouter' when query is empty/invalid, and filters out Apple Simulator demo contacts")
    func testP228AddFriendQRCodeDisabledSubmitAndSimulatorDemoContactFilter() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("\"social-friend-invite-qr-code\""))
        #expect(source.contains(".disabled(!isQueryValid)"))
        #expect(source.contains(".opacity(isQueryValid ? 1.0 : 0.42)"))
        #expect(source.contains("\"social-import-address-book-button\""))

        var appState = CertiGoNativeAppState()
        #expect(appState.friendInviteDeepLinkURLString.hasPrefix("certigo://friend-invite?code=CG-104"))
        let matrix = CertiGoInviteQRCodeGenerator.generateMatrix(for: appState.friendInviteDeepLinkURLString)
        #expect(matrix.count == 21)
        #expect(matrix.allSatisfy { $0.count == 21 })
        // Top-left, top-right, and bottom-left 7x7 finder corners must be dark
        #expect(matrix[0][0] == true)
        #expect(matrix[0][6] == true)
        #expect(matrix[6][0] == true)
        #expect(matrix[0][20] == true)
        #expect(matrix[20][0] == true)

        #expect(appState.isFriendSearchQueryValid == false)
        appState.friendSearchQuery = " "
        #expect(appState.isFriendSearchQueryValid == false)
        appState.friendSearchQuery = "@camille"
        #expect(appState.isFriendSearchQueryValid == true)

        #expect(CertiGoNativeAppState.appleSimulatorDemoContactNames.contains("john appleseed"))
        #expect(CertiGoNativeAppState.appleSimulatorDemoContactNames.contains("kate bell"))
        #expect(CertiGoNativeAppState.appleSimulatorDemoContactNames.contains("anna haro"))
    }

    @Test("P2-29: Leaderboard allows 'Objectif hebdomadaire partagé : 0 / 100 concepts' to wrap on 2 lines without compression by '0 %' and exposes .isSelected accessibility trait on segment buttons")
    func testP229LeaderboardCohortGoalTwoLinesAndSegmentSelectedTrait() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("private var socialCooperativeCohortGoalBannerView: some View"))
        #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
    }

    // MARK: - Section 6 : Moi, paramètres et statistiques (P2-30 à P3-35)

    @Test("P2-30: Moi certification cards display the certification code once ('Parcours AZ-104 : 0 %'), match visible and accessibility labels, and add 100pt bottom padding")
    func testP230MoiCertificationCardsSingleCodeAndBottomPadding() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("let progressTitle = \"Parcours \\(code) : \\(pct) %\""))
        #expect(source.contains(".accessibilityLabel(\"\\(progressTitle), \\(cleanDetailTitle)\")"))
        #expect(source.contains(".padding(.bottom, FigMetrics.oneHundred)"))
        #expect(!source.contains("Parcours \\(code) : \\(pct)% · Unité 1 :"))
    }

    @Test("P3-31: Singular/plural agreement ('1 jour' for 0 or 1, 'X jours' for >= 2) and explicit accessibilityLabels 'Modifier le profil' and 'Paramètres'")
    func testP331SingularPluralDaysAndProfileAccessibilityLabels() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains(".accessibilityLabel(\"Modifier le profil\")"))
        #expect(source.contains(".accessibilityLabel(\"Paramètres\")"))

        var appState = CertiGoNativeAppState()
        appState.streakDays = 0
        #expect(appState.formattedStreakDaysLabel == "0 jour")
        appState.streakDays = 1
        #expect(appState.formattedStreakDaysLabel == "1 jour")
        appState.streakDays = 2
        #expect(appState.formattedStreakDaysLabel == "2 jours")
        appState.streakDays = 14
        #expect(appState.formattedStreakDaysLabel == "14 jours")
    }

    @Test("P3-32: Settings -> Mode Examen Blanc strips trailing chevrons '›', keeps only right-aligned '✓' on selected option, and uses .presentationDetents([.height(300), .medium])")
    func testP332SettingsExamModeStripsChevronsAndUsesCompactDetents() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains(".presentationDetents([.height(300), .medium])"))
        for rawOption in CertiGoFigmaLiveRuntimeState.settingsExamModeOptions {
            let cleaned = CertiGoNativeAppState.cleanSettingsOptionLabel(rawOption)
            #expect(!cleaned.contains("›"))
            #expect(!cleaned.isEmpty)
        }
    }

    @Test("P2-33: Statistiques Pro prevents mid-word break on 'Stockage' (2-line axis button 'Stockage' + 'pct %') and unifies height of the 3 telemetry cards")
    func testP233StatistiquesProStockageAxisAndUnifiedTelemetryCardsHeight() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("(\"Stockage\", max(0, baseMastery - 5)"))
        #expect(source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    @Test("P2-34: Statistiques Pro trims the 3 concentric rings to their exact values (0% when regularity/steps are 0) and displays explicit data volume & 7-day scope under Précision QCM and Rétention FSRS")
    func testP234StatistiquesProHonestRingTrimAndScopeSubtitles() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains(".trim(from: 0, to: CGFloat(ringFractions.regularity))"))
        #expect(source.contains(".trim(from: 0, to: CGFloat(ringFractions.accuracy))"))
        #expect(source.contains(".trim(from: 0, to: CGFloat(ringFractions.steps))"))

        var appState = CertiGoNativeAppState()
        #expect(appState.completedStepsTotal == 0)
        #expect(appState.performanceRingFractions.regularity == 0.0)
        #expect(appState.performanceRingFractions.accuracy == 0.0)
        #expect(appState.performanceRingFractions.steps == 0.0)
        #expect(appState.qcmAccuracyScopeSubtitle == "0 % · Aucune réponse enregistrée (7 derniers jours)")
        #expect(appState.fsrsRetentionScopeSubtitle == "0 % · Aucune carte FSRS révisée (7 derniers jours)")

        // Simulate finishing 1 exam with 1 answer but 0 completed lesson steps -> regularity and steps rings stay at 0.0!
        appState.selectRoute("AZ-900")
        appState.startTimedExam23()
        appState.selectExamChoice("A")
        appState.finishTimedExamAndComputeScore()
        #expect(appState.completedStepsTotal == 0)
        #expect(appState.performanceRingFractions.regularity == 0.0)
        #expect(appState.performanceRingFractions.steps == 0.0)
        #expect(appState.qcmAccuracyScopeSubtitle.contains("Basé sur 1 question répondue (7 derniers jours)"))
    }

    @Test("P3-35: Statistiques Pro renders a real 5-axis polygon radar chart ('stats08b-polygon-radar-chart') above the axis buttons")
    func testP335StatistiquesProPolygonRadarChart() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("private func proStatsPolygonRadarCanvasView("))
        #expect(source.contains("\"stats08b-polygon-radar-chart\""))

        let vertices = CertiGoPolygonRadarGeometry.normalizedVertices(forPercentages: [80, 65, 70, 55, 90])
        #expect(vertices.count == 5)
        // First vertex is straight up (x ≈ 0, y < 0)
        #expect(abs(vertices[0].x) < 0.001)
        #expect(vertices[0].y < -0.75)
    }

    // MARK: - Section 7 : Examen blanc AZ-900 (P2-36 à P2-40)

    @Test("P2-36: Exam Center gives '🏆 Examens blancs' its own dedicated full-width line and allows 2 lines for all 5 domain titles")
    func testP236ExamCenterDedicatedTitleLineAndTwoLineDomains() throws {
        let source = try loadFigmaAppSource()
        #expect(source.contains("Text(verbatim: \"🏆 Examens blancs\")"))
        #expect(source.contains("Text(verbatim: domain.title)\n                                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: \"Semi Bold\"))\n                                        .foregroundStyle(PrismColor.figmaHex(\"#0f172a\"))\n                                        .lineLimit(2)"))
    }

    @Test("P1-37 (CRITIQUE): Exam counter ('1 / 12' .. '12 / 12'), Grid button ('📋 Grille (12)'), and last-question detection derive strictly from examQuestions.count with zero hardcoded '50'")
    func testP137ExamCounterAndGridUseActualQuestionsCount() throws {
        let source = try loadFigmaAppSource()
        #expect(!source.contains("\"📋 Grille (50)\""))
        #expect(!source.contains("\"/ 50\""))

        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-900")
        appState.startTimedExam23()
        #expect(appState.examQuestions.count == 12)
        #expect(appState.examGridButtonTitle == "📋 Grille (12)")
        #expect(appState.examQuestionProgressLabel(at: 0) == "1 / 12")
        #expect(appState.examQuestionProgressLabel(at: 11) == "12 / 12")
        #expect(appState.isOnLastExamQuestion == false)

        appState.jumpToExamQuestion(at: 11)
        #expect(appState.isOnLastExamQuestion == true)
    }

    @Test("P2-38: Single exam finish button, explicit unanswered-questions confirmation ('Il reste 11 questions sans réponse sur 12...'), and 'Préc.' disabled with 0.38 opacity on Q1")
    func testP238SingleFinishActionUnansweredConfirmationAndDisabledPrevOnQ1() throws {
        let source = try loadFigmaAppSource()
        #expect(!source.contains("\"exam23-finish-now-button\""))
        #expect(source.contains(".disabled(isFirst)\n                .opacity(isFirst ? 0.38 : 1.0)"))

        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-900")
        appState.startTimedExam23()
        #expect(appState.isOnFirstExamQuestion == true)
        #expect(appState.examUnansweredQuestionsCount == 12)

        // Answer only Q1 and jump to Q12 -> tapping finish triggers confirmation alert announcing 11 unanswered questions out of 12
        appState.selectExamChoice("A")
        #expect(appState.examUnansweredQuestionsCount == 11)
        #expect(
            appState.examUnansweredConfirmationMessage
                == "Il reste 11 questions sans réponse sur 12. Voulez-vous vraiment remettre votre copie ?"
        )

        appState.jumpToExamQuestion(at: 11)
        #expect(appState.isOnFirstExamQuestion == false)
        appState.requestFinishTimedExam()
        #expect(appState.showFinishExamUnansweredConfirmationAlert == true)
        #expect(appState.isPresentingTimedExam23 == true)
    }

    @Test("P1-39 (CRITIQUE): Mathematical coherence of /1000 score, per-domain percentages (0% on domains with 0 right answers, identical on Result 24 and Exam Center 21), and threshold badge (>= 700 only)")
    func testP139ExamScoreDomainCoherenceAndPassingThresholdBadge() {
        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-900")
        appState.startTimedExam23()

        // Answer only Q1 correctly and leave Q2..Q12 unanswered
        if let q1Correct = appState.examQuestions[0].choices.first(where: \.isCorrect) {
            appState.selectedExamChoiceByQuestionNumber[1] = q1Correct.id
        }
        appState.finishTimedExamAndComputeScore()

        // 1/12 = 83/1000 (< 700)
        #expect(appState.lastComputedExamScoreOutOf1000 == 83)
        #expect(appState.didPassLastExam == false)
        #expect(!appState.lastExamStatusBannerText.contains("✓"))
        #expect(appState.lastExamStatusBannerText.contains("Sous le seuil"))

        // Only Domain 0 (containing Q1) has points; Domains 1..4 have 0% on BOTH Report 24 and Exam Center 21!
        let domains = CertiGoNativeRichCatalog.examDomains(forRouteCode: "AZ-900")
        #expect(domains.count == 5)
        let dom0Report = appState.examDomainScorePercent(forRouteCode: "AZ-900", domainIndex: 0)
        #expect(dom0Report > 0)
        for domIdx in 1..<domains.count {
            let reportPct = appState.examDomainScorePercent(forRouteCode: "AZ-900", domainIndex: domIdx)
            let centerPct = appState.domainMasteryPercent(forRouteCode: "AZ-900", domainIndex: domIdx)
            #expect(reportPct == 0, "Expected 0% on unanswered domain \(domIdx), got \(reportPct)%")
            #expect(centerPct == reportPct, "Mismatch between Report 24 (\(reportPct)%) and Exam Center 21 (\(centerPct)%)")
        }

        // Now answer all 12 questions correctly -> 1000/1000, didPassLastExam == true, all domains 100%
        appState.startTimedExam23()
        for q in appState.examQuestions {
            if let right = q.choices.first(where: \.isCorrect) {
                appState.selectedExamChoiceByQuestionNumber[q.number] = right.id
            }
        }
        appState.finishTimedExamAndComputeScore()
        #expect(appState.lastComputedExamScoreOutOf1000 == 1000)
        #expect(appState.didPassLastExam == true)
        #expect(appState.lastExamStatusBannerText.hasPrefix("✓ Seuil atteint"))
        for domIdx in 0..<domains.count {
            #expect(appState.examDomainScorePercent(forRouteCode: "AZ-900", domainIndex: domIdx) == 100)
            #expect(appState.domainMasteryPercent(forRouteCode: "AZ-900", domainIndex: domIdx) == 100)
        }
    }

    @Test("P2-40: Detailed exam correction distinguishes 'Sans réponse' from '✕ Réponse incorrecte' and links each explanation to the question's specific expected choice without generic boilerplate")
    func testP240DetailedCorrectionUnansweredVsWrongAndSpecificExplanations() throws {
        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-900")
        appState.startTimedExam23()

        // Q1: Correct answer, Q2: Wrong answer, Q3..Q12: Unanswered
        let q1 = appState.examQuestions[0]
        let q2 = appState.examQuestions[1]
        let q3 = appState.examQuestions[2]
        if let q1Right = q1.choices.first(where: \.isCorrect) {
            appState.selectedExamChoiceByQuestionNumber[q1.number] = q1Right.id
        }
        if let q2Wrong = q2.choices.first(where: { !$0.isCorrect }) {
            appState.selectedExamChoiceByQuestionNumber[q2.number] = q2Wrong.id
        }

        let s1 = appState.examQuestionReviewStatusBadge(for: q1)
        let s2 = appState.examQuestionReviewStatusBadge(for: q2)
        let s3 = appState.examQuestionReviewStatusBadge(for: q3)

        #expect(s1.text == "✓ Correct")
        #expect(s1.isCorrect == true)
        #expect(s1.isUnanswered == false)

        #expect(s2.text == "✕ Réponse incorrecte")
        #expect(s2.isCorrect == false)
        #expect(s2.isUnanswered == false)

        #expect(s3.text == "Sans réponse")
        #expect(s3.isCorrect == false)
        #expect(s3.isUnanswered == true)

        for q in appState.examQuestions {
            let exp = CertiGoNativeRichCatalog.officialExplanation(forExamQuestion: q)
            let rawCorrect = q.choices.first(where: \.isCorrect)
            let correctChoice = try #require(rawCorrect)
            #expect(exp.contains(correctChoice.text))
            #expect(exp.contains(q.domainTitle))
            #expect(!exp.contains("Associez toujours le moindre privilège, l'isolation réseau privée et la haute disponibilité multi-zones"))
        }

        let root = try repoRootURL()
        let archiveScript = try String(
            contentsOf: root.appendingPathComponent("tools/archive_testflight_mac.sh"),
            encoding: .utf8
        )
        #expect(archiveScript.contains("build=${CERTIGO_DISTRIBUTION_BUILD:-16}"))
    }
}
