import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("CertiGoMultilingualEngine — 100% Multilingual Coverage Across UI, Onboarding, Units, Lessons, Exercises & Mock Exams", .serialized)
struct CertiGoMultilingualEngineTests {

    @Test("All 12 supported language modes and all 8 canonical AppLanguage cases map deterministically and preserve indices 0, 1, 2")
    func twelveSupportedLanguageModesAndAppLanguageMapping() {
        let options = CertiGoFigmaLiveRuntimeState.settingsLanguageOptions
        #expect(options.count == 12)
        #expect(options[0] == "FR + Termes EN  ›")
        #expect(options[1] == "Français intégral  ›")
        #expect(options[2] == "English (US)  ›")
        #expect(options[3] == "Español  ›")
        #expect(options[4] == "Deutsch  ›")
        #expect(options[5] == "Italiano  ›")
        #expect(options[6] == "Português  ›")
        #expect(options[7] == "العربية  ›")
        #expect(options[8] == "日本語  ›")
        #expect(options[9] == "हिन्दी  ›")
        #expect(options[10] == "简体中文  ›")
        #expect(options[11] == "한국어  ›")

        for appLang in AppLanguage.allCases {
            let mapped = CertiGoSupportedLanguage(appLanguage: appLang)
            #expect(mapped.mappedAppLanguage == appLang)
        }
    }

    @Test("Bottom navigation bar tabs, Onboarding 0..9, Spotlight Guided Tour 1..5, and Settings 28 translate 100% across all non-French languages with 0 em/en dashes")
    func uiTabsOnboardingGuidedTourAndSettingsTranslateAcrossAllLanguages() {
        let coreUIStrings: [String] = [
            "Parcours",
            "Examens",
            "✦ IA",
            "Social",
            "Moi",
            "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.",
            "CRÉER MON COMPTE · C'EST PARTI !",
            "J'ai déjà un compte · Se connecter",
            "Qu'est-ce qui t'amène sur CertiGo ?",
            "Quelles certifications veux-tu suivre ?",
            "Reste à la pointe de l'IA",
            "Quel est ton niveau actuel ?",
            "Quand vises-tu ta 1re certification ?",
            "Choisis ton objectif quotidien",
            "Quel est ton meilleur moment ?",
            "Ajoute le Widget CertiGo sur ton iPhone",
            "3,4× plus rapide avec CertiGo",
            "Sauvegarde tes 20 % d'avance",
            "Chapitre 1 : 2 / 10 tampons validés (20 %)",
            "Version simple",
            "Défi Examen",
            "VÉRIFIER",
            "Excellent réflexe !",
            "Pas tout à fait…",
            "Tu n'as plus de cœurs ! 💔 (5 fautes)",
            "Examen Blanc Complet",
            "DÉMARRER L'EXAMEN COMPLET",
            "DOMAINES OFFICIELS",
            "QUÊTE D'ÉQUIPE · OBJECTIF HEBDO",
            "Terminer 15 étapes à deux",
            "Mon Profil",
            "Paramètres",
            "Langue des cours & examens"
        ]

        for lang in CertiGoSupportedLanguage.allCases where !lang.isFrenchVariant {
            for fr in coreUIStrings {
                let translated = CertiGoMultilingualEngine.tr(fr, lang: lang.rawValue)
                #expect(!translated.isEmpty)
                #expect(!translated.contains("\u{2014}"))
                #expect(!translated.contains("\u{2013}"))
                #expect(!CertiGoMultilingualEngine.containsUntranslatedFrenchLeak(translated, lang: lang.rawValue))
                if fr != "Social" && fr != "✦ IA" {
                    #expect(translated != fr)
                }
            }
        }
        #expect(CertiGoMultilingualEngine.tr("✦ IA", lang: CertiGoSupportedLanguage.en.rawValue) == "✦ AI")
        #expect(CertiGoMultilingualEngine.tr("✦ IA", lang: CertiGoSupportedLanguage.de.rawValue) == "✦ KI")

        for lang in CertiGoSupportedLanguage.allCases where !lang.isFrenchVariant {

            // Verify all 5 Spotlight Guided Tour steps localize cleanly
            for stepIdx in 0..<5 {
                let tourStep = CertiGoMultilingualEngine.localizedGuidedTourStep(stepIndex: stepIdx, lang: lang.rawValue)
                #expect(!tourStep.title.isEmpty)
                #expect(!tourStep.body.isEmpty)
                #expect(!tourStep.title.contains("\u{2014}"))
                #expect(!tourStep.body.contains("\u{2014}"))
                #expect(!CertiGoMultilingualEngine.containsUntranslatedFrenchLeak(tourStep.body, lang: lang.rawValue))
            }
        }
    }

    @Test("Switching settingsLanguageIndex dynamically localizes Units 1..3 (30 steps), Lesson Slides, Exercises (Normal + Simple), Mock Exam Questions, and AI Coach across all tracks")
    func switchingLanguageLocalizesUnitsLessonsExercisesExamQuestionsAndAICoach() {
        var appState = CertiGoNativeAppState()
        let sampleRoutes = ["AZ-104", "AZ-900", "SAA-C03", "PCA", "MS-365-COPILOT", "OPENAI-PRO", "ANTHROPIC-CLAUDE", "HARVEY-LEGAL"]

        // Test Mode 1 (Français intégral) replaces English Cloud terms with French terminology
        appState.selectSettingsOption(for: .language, index: CertiGoSupportedLanguage.frFull.rawValue)
        let frFullSample = appState.tr("Déployer un Private Endpoint avec Load Balancer et Key Vault")
        #expect(frFullSample.contains("Point de terminaison privé"))
        #expect(frFullSample.contains("Équilibreur de charge"))
        #expect(frFullSample.contains("Coffre de clés"))

        // Test non-French languages (English=2, Español=3, Deutsch=4, Italiano=5, Português=6, العربية=7, 日本語=8, हिन्दी=9, 简体中文=10, 한국어=11)
        for langIdx in 2..<CertiGoSupportedLanguage.allCases.count {
            appState.selectSettingsOption(for: .language, index: langIdx)
            #expect(appState.settingsLanguageIndex == langIdx)

            for route in sampleRoutes {
                appState.selectRoute(route)
                let units = appState.currentUnits
                #expect(units.count == 3)
                #expect(units.flatMap(\.lessons).count == 30)

                // Unit headers and 10 steps per unit must be localized (no raw "UNITÉ " prefix in non-French)
                for unit in units {
                    #expect(!unit.headerTitle.hasPrefix("UNITÉ "))
                    #expect(!unit.headerTitle.contains("\u{2014}"))
                    #expect(!unit.memoGoldenRule.contains("\u{2014}"))
                    for lesson in unit.lessons {
                        #expect(!lesson.title.isEmpty)
                        #expect(!lesson.subtitle.isEmpty)
                        #expect(!lesson.title.contains("\u{2014}"))
                        #expect(!lesson.subtitle.contains("\u{2014}"))
                    }
                }

                // Start a lesson session and verify slides + exercises (normal & plainLanguage)
                appState.startLessonSession()
                for slide in appState.lessonSession.lessonSlides {
                    #expect(!slide.title.isEmpty)
                    #expect(!slide.bodyParagraph.isEmpty)
                    #expect(!slide.stepBadge.hasPrefix("ÉTAPE "))
                    #expect(!slide.bodyParagraph.contains("\u{2014}"))
                }

                for ex in appState.lessonSession.exercises {
                    #expect(!ex.prompt.isEmpty)
                    #expect(!ex.plainLanguagePrompt.isEmpty)
                    #expect(!CertiGoMultilingualEngine.containsUntranslatedFrenchLeak(ex.prompt, lang: langIdx))
                    #expect(!ex.prompt.contains("\u{2014}"))
                    #expect(!ex.plainLanguagePrompt.contains("\u{2014}"))
                    for opt in ex.options {
                        #expect(!opt.title.isEmpty)
                        #expect(!opt.plainLanguageTitle.isEmpty)
                        #expect(!opt.title.contains("\u{2014}"))
                    }
                }

                // Verify Mock Exam Question localization (normal + plainLanguage + choices)
                let examQ = appState.currentExamQuestion
                #expect(!examQ.stem.isEmpty)
                #expect(!examQ.plainLanguageStem.isEmpty)
                #expect(!CertiGoMultilingualEngine.containsUntranslatedFrenchLeak(examQ.stem, lang: langIdx))
                #expect(!examQ.stem.contains("\u{2014}"))
                #expect(!examQ.caseStudyBadge.hasPrefix("ÉTUDE DE CAS"))
                for choice in examQ.choices {
                    #expect(!choice.text.isEmpty)
                    #expect(!choice.plainLanguageText.isEmpty)
                    #expect(!choice.text.contains("\u{2014}"))
                }

                // Verify AI Coach suggestions & fallback reply
                let suggestions = CertiGoMultilingualEngine.localizedAICoachSuggestions(routeCode: route, lang: langIdx)
                #expect(suggestions.count == 4)
                #expect(!suggestions[0].title.contains("Explique-moi"))
                let fallback = CertiGoMultilingualEngine.localizedAICoachFallbackReply(
                    routeCode: route,
                    userQuestion: "RBAC vs Policy",
                    lang: langIdx
                )
                #expect(!fallback.reply.isEmpty)
                #expect(fallback.suggestions.count == 3)
            }
        }

        // Verify persistence of settingsLanguageIndex in CertiGoPersistedUserDatabase
        appState.selectSettingsOption(for: .language, index: CertiGoSupportedLanguage.es.rawValue)
        let db = appState.buildPersistedDatabase()
        #expect(db.settingsLanguageIndex == CertiGoSupportedLanguage.es.rawValue)
        var restoredState = CertiGoNativeAppState()
        restoredState.applyPersistedDatabase(db)
        #expect(restoredState.settingsLanguageIndex == CertiGoSupportedLanguage.es.rawValue)
        #expect(restoredState.activeLanguage == .es)
    }
}
