import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("ContentFondEtFormeQualityTests — Audit Fond & Forme (33 Certifications × 30 Étapes)")
struct ContentFondEtFormeQualityTests {

    private let forbiddenWordBoundaryRegexes: [(token: String, regex: NSRegularExpression)] = {
        let wordTokens = [
            "de Azure", "de OpenAI", "de Anthropic", "de API", "de IA", "de IAM",
            "de identité", "de accès", "de architecture", "de exécution", "de entreprise",
            "le API", "un API", "qu'quelqu"
        ]
        return wordTokens.compactMap { tok in
            let escaped = NSRegularExpression.escapedPattern(for: tok)
            let pat = "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])"
            guard let rx = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return nil }
            return (token: tok, regex: rx)
        }
    }()

    private let forbiddenPunctuationTokens: [String] = [
        "..", ": :", "?.", ", ."
    ]

    private let forbiddenMetaPhrases: [String] = [
        "Cette étape vous prépare à",
        "Dans le cadre de la certification",
        "Au sein de UNITÉ",
        "garantit une fondation conforme aux attentes",
        "valide ta maîtrise de",
        "valide tes compétences opérationnelles sur"
    ]

    private let validTerminalPunctuation: Set<Character> = [".", "!", "?", "»"]

    private func assertZeroElisionOrPunctuationFault(_ text: String, context: String) {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for item in forbiddenWordBoundaryRegexes {
            let hasMatch = item.regex.firstMatch(in: text, options: [], range: range) != nil
            #expect(!hasMatch, "Found '\(item.token)' in \(context): \(text)")
        }
        for token in forbiddenPunctuationTokens {
            if token == ".." {
                let withoutEllipsis = text.replacingOccurrences(of: "...", with: "")
                #expect(!withoutEllipsis.contains(".."), "Found '..' in \(context): \(text)")
            } else {
                #expect(!text.contains(token), "Found '\(token)' in \(context): \(text)")
            }
        }
    }

    private func assertCleanTerminalPunctuation(_ text: String, context: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!trimmed.isEmpty, "Empty text in \(context)")
        if let last = trimmed.last {
            #expect(
                validTerminalPunctuation.contains(last),
                "Missing terminal punctuation in \(context) (ended with '\(last)'): \(trimmed)"
            )
        }
    }

    @Test("1. Zéro faute d'élision française et zéro double ponctuation sur les 33 certifications × 30 étapes")
    func zeroFrenchElisionOrPunctuationFaultsAcross33Tracks30Steps() {
        let allRoutes = CertiGoDedicatedTrackQuestionBank.allSupportedRouteCodes
        #expect(allRoutes.count == 33)

        for routeCode in allRoutes {
            let units = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: routeCode)
            #expect(units.count == 3)

            for unit in units {
                assertZeroElisionOrPunctuationFault(unit.headerTitle, context: "\(routeCode) U\(unit.unitNumber) headerTitle")
                assertZeroElisionOrPunctuationFault(unit.subtitle, context: "\(routeCode) U\(unit.unitNumber) subtitle")
                assertZeroElisionOrPunctuationFault(unit.memoGoldenRule, context: "\(routeCode) U\(unit.unitNumber) memoGoldenRule")

                for lesson in unit.lessons {
                    assertZeroElisionOrPunctuationFault(lesson.title, context: "\(lesson.id) title")
                    assertZeroElisionOrPunctuationFault(lesson.subtitle, context: "\(lesson.id) subtitle")

                    let declic = CertiGoDedicatedTrackQuestionBank.lessonDeclicCard(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    assertZeroElisionOrPunctuationFault(declic.title, context: "\(lesson.id) declic.title")
                    assertZeroElisionOrPunctuationFault(declic.analogy, context: "\(lesson.id) declic.analogy")
                    assertZeroElisionOrPunctuationFault(declic.concreteExample, context: "\(lesson.id) declic.concreteExample")
                    assertZeroElisionOrPunctuationFault(declic.rule, context: "\(lesson.id) declic.rule")
                    for (idx, takeaway) in declic.keyTakeaways.enumerated() {
                        assertZeroElisionOrPunctuationFault(takeaway, context: "\(lesson.id) declic.keyTakeaways[\(idx)]")
                    }

                    let slides = CertiGoDedicatedTrackQuestionBank.microSlides(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title,
                        serviceAssetName: lesson.serviceAssetName
                    )
                    for (sIdx, slide) in slides.enumerated() {
                        assertZeroElisionOrPunctuationFault(slide.title, context: "\(lesson.id) slide[\(sIdx)].title")
                        assertZeroElisionOrPunctuationFault(slide.body, context: "\(lesson.id) slide[\(sIdx)].body")
                        assertZeroElisionOrPunctuationFault(slide.highlight, context: "\(lesson.id) slide[\(sIdx)].highlight")
                    }

                    let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    for ex in exercises {
                        assertZeroElisionOrPunctuationFault(ex.prompt, context: "\(ex.id) prompt")
                        assertZeroElisionOrPunctuationFault(ex.plainPrompt, context: "\(ex.id) plainPrompt")
                        assertZeroElisionOrPunctuationFault(ex.explanation, context: "\(ex.id) explanation")
                        assertZeroElisionOrPunctuationFault(ex.plainExplanation, context: "\(ex.id) plainExplanation")
                        for opt in ex.options {
                            assertZeroElisionOrPunctuationFault(opt.title, context: "\(ex.id) \(opt.badge) title")
                            assertZeroElisionOrPunctuationFault(opt.plainLanguageTitle, context: "\(ex.id) \(opt.badge) plainTitle")
                            assertZeroElisionOrPunctuationFault(opt.whyWrongOrRight, context: "\(ex.id) \(opt.badge) whyWrongOrRight")
                        }
                    }
                }
            }

            let exams = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: routeCode)
            for q in exams {
                assertZeroElisionOrPunctuationFault(q.stem, context: "\(q.id) stem")
                assertZeroElisionOrPunctuationFault(q.plainPrompt, context: "\(q.id) plainPrompt")
                assertZeroElisionOrPunctuationFault(q.explanation, context: "\(q.id) explanation")
                assertZeroElisionOrPunctuationFault(q.plainExplanation, context: "\(q.id) plainExplanation")
                for ch in q.choices {
                    assertZeroElisionOrPunctuationFault(ch.text, context: "\(q.id) \(ch.badge) text")
                    assertZeroElisionOrPunctuationFault(ch.plainLanguageText, context: "\(q.id) \(ch.badge) plainText")
                }
            }
        }
    }

    @Test("2. Zéro troncature ou phrase incomplète : tous les body, analogy, concreteExample, explanation et plainExplanation se terminent par '.', '!', '?' ou '»'")
    func zeroTruncationAndProperTerminalPunctuationAcross33Tracks30Steps() {
        let allRoutes = CertiGoDedicatedTrackQuestionBank.allSupportedRouteCodes
        #expect(allRoutes.count == 33)

        for routeCode in allRoutes {
            let units = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: routeCode)
            for unit in units {
                for lesson in unit.lessons {
                    let declic = CertiGoDedicatedTrackQuestionBank.lessonDeclicCard(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    assertCleanTerminalPunctuation(declic.title, context: "\(lesson.id) declic.title")
                    assertCleanTerminalPunctuation(declic.analogy, context: "\(lesson.id) declic.analogy")
                    assertCleanTerminalPunctuation(declic.concreteExample, context: "\(lesson.id) declic.concreteExample")
                    assertCleanTerminalPunctuation(declic.rule, context: "\(lesson.id) declic.rule")
                    for (idx, takeaway) in declic.keyTakeaways.enumerated() {
                        assertCleanTerminalPunctuation(takeaway, context: "\(lesson.id) declic.keyTakeaways[\(idx)]")
                    }

                    let slides = CertiGoDedicatedTrackQuestionBank.microSlides(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title,
                        serviceAssetName: lesson.serviceAssetName
                    )
                    for (sIdx, slide) in slides.enumerated() {
                        #expect(!slide.title.contains("\n"), "Unexpected newline in slide title \(lesson.id)[\(sIdx)]")
                        assertCleanTerminalPunctuation(slide.body, context: "\(lesson.id) slide[\(sIdx)].body")
                        assertCleanTerminalPunctuation(slide.highlight, context: "\(lesson.id) slide[\(sIdx)].highlight")
                    }

                    let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    for ex in exercises {
                        assertCleanTerminalPunctuation(ex.explanation, context: "\(ex.id) explanation")
                        assertCleanTerminalPunctuation(ex.plainExplanation, context: "\(ex.id) plainExplanation")
                        assertCleanTerminalPunctuation(ex.examTip, context: "\(ex.id) examTip")
                        for opt in ex.options {
                            assertCleanTerminalPunctuation(opt.whyWrongOrRight, context: "\(ex.id) \(opt.badge) whyWrongOrRight")
                        }
                    }
                }
            }
        }
    }

    @Test("3. Équilibre des longueurs des 4 options de réponse (A, B, C, D) : aucune option vide ou d'un seul mot et ratio équilibré sur les 33 parcours × 30 étapes")
    func balancedFourOptionLengthsAcross33Tracks30Steps() {
        let allRoutes = CertiGoDedicatedTrackQuestionBank.allSupportedRouteCodes
        #expect(allRoutes.count == 33)

        func wordCount(_ s: String) -> Int {
            s.split(whereSeparator: \.isWhitespace).count
        }

        for routeCode in allRoutes {
            let units = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: routeCode)
            for unit in units {
                for lesson in unit.lessons {
                    let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    for ex in exercises {
                        #expect(ex.options.count == 4, "Expected 4 options in \(ex.id), got \(ex.options.count)")
                        let techWordCounts = ex.options.map { wordCount($0.title) }
                        let plainWordCounts = ex.options.map { wordCount($0.plainLanguageTitle) }
                        let minTech = techWordCounts.min() ?? 0
                        let maxTech = techWordCounts.max() ?? 0
                        let minPlain = plainWordCounts.min() ?? 0
                        let maxPlain = plainWordCounts.max() ?? 0

                        #expect(minTech >= 6, "Option too short (\(minTech) words) in \(ex.id): \(ex.options.map(\.title))")
                        #expect(minPlain >= 6, "Plain option too short (\(minPlain) words) in \(ex.id): \(ex.plainOptions)")
                        #expect(Double(maxTech) <= Double(max(1, minTech)) * 2.5, "Imbalanced option word counts \(techWordCounts) in \(ex.id)")
                        #expect(Double(maxPlain) <= Double(max(1, minPlain)) * 2.5, "Imbalanced plain option word counts \(plainWordCounts) in \(ex.id)")

                        for opt in ex.options {
                            #expect(!opt.plainLanguageTitle.hasPrefix("À écarter"), "Leaked answer prefix in \(ex.id) \(opt.badge)")
                            #expect(!opt.plainLanguageTitle.hasPrefix("À éviter"), "Leaked answer prefix in \(ex.id) \(opt.badge)")
                            #expect(!opt.plainLanguageTitle.hasPrefix("Option incorrecte"), "Leaked answer prefix in \(ex.id) \(opt.badge)")
                            #expect(!opt.plainLanguageTitle.hasPrefix("Solution recommandée"), "Leaked answer prefix in \(ex.id) \(opt.badge)")
                        }
                    }
                }
            }

            let exams = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: routeCode)
            for q in exams {
                #expect(q.choices.count == 4, "Expected 4 exam choices in \(q.id)")
                let techCounts = q.choices.map { wordCount($0.text) }
                let plainCounts = q.choices.map { wordCount($0.plainLanguageText) }
                let minTech = techCounts.min() ?? 0
                let maxTech = techCounts.max() ?? 0
                let minPlain = plainCounts.min() ?? 0
                let maxPlain = plainCounts.max() ?? 0
                #expect(minTech >= 6, "Exam choice too short in \(q.id): \(q.options)")
                #expect(minPlain >= 6, "Exam plain choice too short in \(q.id): \(q.plainOptions)")
                #expect(Double(maxTech) <= Double(max(1, minTech)) * 2.5, "Imbalanced exam choices \(techCounts) in \(q.id)")
                #expect(Double(maxPlain) <= Double(max(1, minPlain)) * 2.5, "Imbalanced exam plain choices \(plainCounts) in \(q.id)")
            }
        }
    }

    @Test("4. Présence de vraies explications pédagogiques multi-phrases avec respiration ('\\n\\n') et distinction stricte entre Slide 1, Slide 2, Slide 3, Carte Déclic et Explication")
    func richMultiSentencePedagogicalExplanationsAndParagraphBreathingAcross33Tracks30Steps() {
        let allRoutes = CertiGoDedicatedTrackQuestionBank.allSupportedRouteCodes
        #expect(allRoutes.count == 33)

        for routeCode in allRoutes {
            let units = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: routeCode)
            for unit in units {
                for lesson in unit.lessons {
                    let slides = CertiGoDedicatedTrackQuestionBank.microSlides(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title,
                        serviceAssetName: lesson.serviceAssetName
                    )
                    #expect(slides.count == 3)

                    for (sIdx, slide) in slides.enumerated() {
                        #expect(slide.body.count >= 120, "Slide body too short in \(lesson.id) slide[\(sIdx)]: \(slide.body)")
                        #expect(slide.body.contains("\n\n"), "Expected paragraph break '\\n\\n' in \(lesson.id) slide[\(sIdx)].body")
                        for forbidden in forbiddenMetaPhrases {
                            #expect(!slide.body.contains(forbidden), "Found hollow meta phrase '\(forbidden)' in \(lesson.id) slide[\(sIdx)]")
                        }
                    }

                    let declic = CertiGoDedicatedTrackQuestionBank.lessonDeclicCard(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    #expect(declic.analogy.count >= 110, "Declic analogy too short in \(lesson.id)")
                    #expect(declic.analogy.contains("\n\n"), "Expected '\\n\\n' in \(lesson.id) declic.analogy")
                    #expect(declic.keyTakeaways.count == 3, "Expected 3 keyTakeaways in \(lesson.id)")
                    #expect(Set(declic.keyTakeaways).count == 3, "Duplicate keyTakeaways in \(lesson.id)")
                    #expect(declic.concreteExample.count >= 90, "Declic concreteExample too short in \(lesson.id)")
                    #expect(declic.concreteExample.contains("\n\n"), "Expected '\\n\\n' in \(lesson.id) declic.concreteExample")

                    let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
                        forRouteCode: routeCode,
                        lessonId: lesson.id,
                        lessonTitle: lesson.title
                    )
                    let firstEx = exercises[0]
                    #expect(firstEx.explanation.count >= 80, "Explanation too short in \(firstEx.id)")
                    #expect(firstEx.explanation.contains("\n\n"), "Expected '\\n\\n' in \(firstEx.id) explanation")
                    #expect(firstEx.plainExplanation.count >= 80, "PlainExplanation too short in \(firstEx.id)")
                    #expect(firstEx.plainExplanation.contains("\n\n"), "Expected '\\n\\n' in \(firstEx.id) plainExplanation")

                    // Distinctness across Slide 1, Slide 2, Slide 3, Carte Déclic, and Explanation
                    let distinctPedagogicalBlocks: [String] = [
                        slides[0].body,
                        slides[1].body,
                        slides[2].body,
                        declic.analogy,
                        declic.concreteExample,
                        firstEx.explanation,
                        firstEx.plainExplanation
                    ]
                    #expect(
                        Set(distinctPedagogicalBlocks).count == distinctPedagogicalBlocks.count,
                        "Expected 7 distinct pedagogical blocks in \(lesson.id)"
                    )
                }
            }
        }
    }
}
