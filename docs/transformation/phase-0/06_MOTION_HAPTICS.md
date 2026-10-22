# Phase 0 — Étape 6 : Audit exhaustif des animations, transitions, haptiques et sons

> **Branche auditée :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Périmètre :** 100 % des fichiers Swift de `apps/apple/` (`CertigoNative/Sources/`, `CertigoNative/WidgetExtension/`, `CertigoKit/Sources/`).
> **Règle Phase 0 :** lecture seule stricte — aucun fichier existant modifié.

---

## 1. Légende épistémique et synthèse exécutive

- **VÉRIFIÉ :** constat observé par inspection exhaustive de tous les fichiers `.swift` de `apps/apple/` et vérifié par `tools/tests/test_native_prism_presentation.py:295-296`.
- **INFÉRÉ :** comportement dynamique de `TimelineView` et `AVSpeechSynthesizer` au repos ou lors des changements d'état.
- **NON VÉRIFIABLE :** ressenti haptique réel sur Taptic Engine, latence audio CoreAudio et profil énergétique Instruments Energy Impact (nécessite un iPhone physique + macOS/Xcode).
  - Commande de vérification énergétique sur macOS :
    ```bash
    xcrun xctrace record --template 'Energy Log' \
      --device '<UDID_IPHONE>' \
      --launch -- com.certigo.native.dev
    ```

### Synthèse globale par primitive recherchée dans `apps/apple/` (**VÉRIFIÉ**)

| Primitive / API recherchée | Occurrences dans `apps/apple/` | Statut actuel |
|---|---|---|
| `Animation.timingCurve(...)` (définition de token) | **1** (`CertigoNativeApp.swift:3183`) | `NativePrism.feedback` (240 ms) |
| `.animation(_:value:)` | **2** (`CertigoNativeApp.swift:3805`, `:4116`) | Utilisés avec respect de `accessibilityReduceMotion` |
| `withAnimation` | **0** | Aucun usage |
| `.transition` / `.contentTransition` | **0** | Aucun usage |
| `matchedGeometryEffect` | **0** | Aucun usage |
| `PhaseAnimator` / `KeyframeAnimator` | **0** | Aucun usage |
| `.symbolEffect` | **0** | Aucun usage |
| `TimelineView` | **1** (`CertigoNativeApp.swift:2915`) | Minuteur d'examen blanc (cadence 1 s) |
| `.sensoryFeedback` | **0** | **Totalement absent** |
| `UIFeedbackGenerator` (`UIImpact*`, `UINotification*`, `UISelection*`) | **0** | **Totalement absent** |
| `CoreHaptics` (`CHHapticEngine`, `CHHapticPattern`) | **0** | **Totalement absent** |
| Effets sonores (`AudioServicesPlaySystemSound`, `AVAudioPlayer`, `AVAudioEngine`) | **0** | **Totalement absent** |
| Synthèse vocale (`AVSpeechSynthesizer` / `AVSpeechUtterance`) | **1 classe** (`CertigoNativeApp.swift:8244-8445`) | Lecture à voix haute (`NativeLessonAudioControls` / `NativeLessonSpeech`) |

---

## 2. Inventaire exhaustif des occurrences d'animations et de temporisation dans `apps/apple/` (**VÉRIFIÉ**)

| # | Catégorie | `fichier:ligne` | Extrait exact | But fonctionnel | Durée & courbe exactes | Respect de `accessibilityReduceMotion` | Observations & conformité §25 |
|---|---|---|---|---|---|---|---|
| M-01 | Définition de courbe (`Animation`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3183` | `static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)` | Jeton unique d'animation dans `NativePrism` (aligné sur `PrismMotion.base` 240 ms et `PrismMotion.standard` `Cubic(0.23, 1.0, 0.32, 1.0)` de Flutter) | **0,24 s** (`240 ms`), courbe de Bézier cubique `(0.23, 1.0, 0.32, 1.0)` (ease-out fort) | Délégué aux sites d'appel (`M-02`, `M-03`) — aucune fonction `resolve(reduceMotion:)` sur `NativePrism` | Un seul jeton existe au lieu des 4 jetons normatifs `PrismMotionToken` (`quick`, `snappy`, `smooth`, `expressive`, §18 et §25). Sous Reduce Motion, les sites d'appel passent `nil` (coupure sèche) au lieu du fondu d'opacité exigé par le §25. |
| M-02 | Animation de vue (`.animation`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3785, 3805` | `@Environment(\.accessibilityReduceMotion) private var reduceMotion`<br>`...`<br>`.animation(reduceMotion ? nil : NativePrism.feedback, value: percent)` | Dans `NativeReadinessRing` : interpoler la progression de l'arc `Circle().trim(from: 0, to: CGFloat(min(100, max(0, percent))) / 100)` lorsque `percent` change | **0,24 s** `timingCurve(0.23, 1, 0.32, 1)` (ou `nil` si `reduceMotion == true`) | **Oui** (`reduceMotion ? nil : NativePrism.feedback`, vérifié par test statique) | Bonne pratique de base (pas de boucle au repos), mais la résolution `reduceMotion ? nil : ...` est dupliquée manuellement dans la vue au lieu de passer par `PrismMotion.resolve(.snappy, reduceMotion:)`. |
| M-03 | Animation de style de bouton (`.animation`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4095, 4116` | `@Environment(\.accessibilityReduceMotion) private var reduceMotion`<br>`...`<br>`.animation(reduceMotion ? nil : NativePrism.feedback, value: isSelected)` | Dans `NativeChoiceButtonStyle` : animer le changement d'arrière-plan (`tint.opacity(0.1)` vs `surface`) et d'épaisseur/couleur de bordure (`2 pt` vs `1 pt`) lors de la sélection d'une option de QCM | **0,24 s** `timingCurve(0.23, 1, 0.32, 1)` (ou `nil` si `reduceMotion == true`) | **Oui** (`reduceMotion ? nil : NativePrism.feedback`, vérifié par `test_native_prism_presentation.py:296`) | En mode Démo (`NativeDemoRoot.exercise`, `CertigoNativeApp.swift:5096-5140`), les boutons d'option QCM n'utilisent **pas** `NativeChoiceButtonStyle` et n'ont aucune animation de sélection. |
| M-04 | Rafraîchissement périodique (`TimelineView`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:2915-2924` | `TimelineView(.periodic(from: .now, by: 1)) { context in ... LabeledContent(copy.native(.timeRemaining), value: ...) }` | Dans `NativeMockExamView` : rafraîchir chaque seconde le compte à rebours `remaining` de l'examen blanc tant que l'examen n'est pas soumis (`snapshot.result == nil`) | Cadence périodique de **1,0 s** (aucune interpolation visuelle) | **Oui (non applicable au mouvement)** : mise à jour textuelle d'un compteur d'examen blanc | **Attention performance / accessibilité (§20, §25, §30) :**<br>1. La valeur `"\(remaining / 60):\(String(format: "%02d", remaining % 60))"` dans `LabeledContent` (`:2922`) n'applique **pas** `.monospacedDigit()`, ce qui peut faire légèrement osciller la chasse des chiffres chaque seconde.<br>2. La `TimelineView` continue de déclencher un tic par seconde même lorsque `remaining == 0` tant que l'examen n'est pas soumis. |
| M-05 | Défilement programmatique (`ScrollViewReader.scrollTo`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:8109` ; `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:327, 332` | `reader.scrollTo("session-reading-start", anchor: .top)`<br>`reader.scrollTo("editorial-reading-start", anchor: .top)`<br>`reader.scrollTo("editorial-practice", anchor: .top)` | Actions « Relire la leçon » (`readAgain`) et « Revoir la pratique formative » (`formativePractice`) | Saut instantané (**0 s**, appelé hors `withAnimation`) | **Oui** (saut direct sans défilement animé forcé) | Conforme au §28 (aucun auto-défilement animé imposé). |

---

## 3. Inventaire exhaustif de l'haptique et de l'audio dans `apps/apple/` (**VÉRIFIÉ**)

### 3.1 Haptique (`sensoryFeedback`, `UIFeedbackGenerator`, `CoreHaptics`)
- **0 occurrence (VÉRIFIÉ) :** Aucun retour haptique n'est implémenté dans `apps/apple/` (`CertigoNative` comme `CertigoKit`).
  - Par comparaison, l'application Flutter héritée possède `PrismHaptics` (`packages/prism_ui/lib/src/feedback/prism_haptics.dart:49-97`) et `HapticLessonFeedback` (`apps/mobile/lib/features/lesson/application/lesson_feedback.dart`), mais rien n'a été porté côté SwiftUI.

### 3.2 Sons d'interface et synthèse vocale (`AVFoundation`)

| # | Catégorie | `fichier:ligne` | composant / API | Comportement exact observé | Conformité §§26 & 28 |
|---|---|---|---|---|---|
| A-01 | Effets sonores d'interface (`PrismSoundToken`) | — | Aucun (`0` occurrence de `AVAudioPlayer`, `AudioServicesPlaySystemSound`, `AVAudioEngine`) | Aucun son n'est joué lors d'une réponse, d'un Déclic ou d'un jalon. | **Manquant** par rapport au §18 (`PrismSoundToken`) et au §26. |
| A-02 | Lecture vocale de leçon (`AVSpeechSynthesizer`) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:8244-8445` | `NativeLessonAudioControls` (`View`) + `NativeLessonSpeech` (`@Observable final class : NSObject, AVSpeechSynthesizerDelegate`) | - Configure `synthesizer.usesApplicationAudioSession = false` (`:8348`).<br>- Propose le choix explicite d'une voix système (`AVSpeechSynthesisVoice.speechVoices()`) et de 2 vitesses (`0.8 * AVSpeechUtteranceDefaultSpeechRate` et `AVSpeechUtteranceDefaultSpeechRate`, `:8270-8271`).<br>- Refuse de démarrer ou s'arrête immédiatement si VoiceOver est actif (`UIAccessibility.isVoiceOverRunning`, `:8291-8296, 8358, 8401`) pour ne pas entrer en conflit avec le lecteur d'écran.<br>- S'arrête automatiquement sur `.onDisappear`, changement de contenu, changement de `ownerID` ou sortie de `scenePhase == .active` (`:8285-8290`). | Conforme au §28 (« mode audio (lecture des explications) SHOULD ») et bien isolé de VoiceOver. Toutefois, `AVAudioSession` catégorie `.ambient` (respect du commutateur silencieux matériel, §26) n'est pas explicitement configurée (`usesApplicationAudioSession = false` délègue la session au démon système TTS). |

---

## 4. Écarts détaillés vs §§18, 25 et 26 du Master Prompt (**VÉRIFIÉ**)

### 4.1 Ce qui manque par rapport au §25 (`MOTION` & `PrismMotionToken` / `PrismCelebrationLevel`)

| Exigence du Master Prompt (§18, §25) | État actuel dans `apps/apple/` | Action requise (Phase 2 — Fondations `Prism`) |
|---|---|---|
| `public enum PrismMotionToken { case quick, snappy, smooth, expressive }` (§18) | N'existe pas ; seul `NativePrism.feedback` (240 ms cubic) existe (`CertigoNativeApp.swift:3183`) | Créer `PrismMotionToken` dans `apps/apple/CertigoKit/Sources/Prism/` :<br>- `quick` : ~0,15 s ease-out (feedback de sélection, statut)<br>- `snappy` : ressort ~0,3 s sans rebond (passage carte → feedback, apparition d'options)<br>- `smooth` : ressort ~0,45 s (continuité concept → Atlas)<br>- `expressive` : keyframes ≤ 1,2 s (Réfraction niveaux 2–3) |
| Résolution centralisée `PrismMotion.resolve(token, reduceMotion:)` avec variantes Reduce Motion dédiées (§25) | Les 2 sites d'appel font `reduceMotion ? nil : NativePrism.feedback` (`:3805, :4116`), ce qui supprime toute transition au lieu d'appliquer la variante Reduce Motion normative | Implémenter `PrismMotion.resolve(token, reduceMotion:)` :<br>- `quick` → opacité seule<br>- `snappy` → fondu 0,2 s<br>- `smooth` → fondu 0,2 s<br>- `expressive` → fondu + éclat statique ≤ 0,3 s |
| `public enum PrismCelebrationLevel: Int { case tick = 0, pulse = 1, refraction = 2, milestone = 3 }` + `PrismCelebration` touchable pour passer + plafonnement au niveau 1 en **Mode Calme** (§18, §19, §25, §28) | **Totalement absent** (0 niveau de célébration, 0 réglage « Mode Calme ») | Créer `PrismCelebrationLevel` et le composant `PrismCelebration` (interrompable au toucher, plafonné à `.pulse` si Mode Calme est actif, annoncé une seule fois par VoiceOver) |
| Animations de symboles SF Symbols iOS 26+ (`#available`) neutralisées sous Reduce Motion (§22) | **0 occurrence** de `.symbolEffect` ou `.contentTransition(.symbolEffect(.replace))` | Ajouter dans `PrismIcon` (avec garde `#available(iOS 26, *)` et neutralisation `reduceMotion`) : `.symbolEffect(.drawOn)` (jour de Rythme), `.symbolEffect(.variableColor)` (profondeur), `.contentTransition(.symbolEffect(.replace))` (changements d'état) |

### 4.2 Ce qui manque par rapport au §26 (`HAPTICS` & `PrismHapticToken` / `PrismSoundToken`)

| Exigence du Master Prompt (§18, §26, §28) | État actuel dans `apps/apple/` | Action requise (Phase 2 — Fondations `Prism` & Phase 3 — Réglages S-77) |
|---|---|---|
| `public enum PrismHapticToken { case selection, correct, incorrectSoft, warning, declic }` (§18, §26) | **Totalement absent** (0 occurrence dans tout `apps/apple/`) | Implémenter `PrismHapticToken` et son moteur dans `Prism` :<br>- `selection` → `.sensoryFeedback(.selection, trigger:)` (choix d'option, sélection de ligne, jeton posé)<br>- `correct` → `.sensoryFeedback(.success, trigger:)` (réponse correcte, séance terminée)<br>- `incorrectSoft` → `.sensoryFeedback(.impact(weight: .light), trigger:)` (réponse incorrecte — **jamais** `.error`)<br>- `warning` → `.sensoryFeedback(.warning, trigger:)` (action destructive uniquement)<br>- `declic` → Core Haptics (`CHHapticEngine` : deux transitoires courtes, la seconde plus intense) avec repli `.sensoryFeedback(.success, trigger:)` pour les célébrations niveaux 2–3 |
| `public enum PrismSoundToken { case answer, declic, milestone }` + `AVAudioSession` catégorie `.ambient` (≤ 600 ms pour le motif Déclic) (§18, §26) | **Totalement absent** (seul `AVSpeechSynthesizer` existe pour la lecture vocale de leçons) | Créer `PrismSoundToken` et un lecteur audio léger configuré sur `AVAudioSession.sharedInstance().setCategory(.ambient)` (respecte le mode silencieux matériel), couplé 1:1 avec `PrismHapticToken` (« chaque son a une haptique correspondante », §26) |
| Réglages in-app **« Haptique »**, **« Sons »** et **« Mode Calme »** (S-77 `Lecture & accessibilité`, §14, §26, §28) | **Absents** : la section `Section(copy.native(.accessibility))` dans `Réglages` (`CertigoNativeApp.swift:7248-7251`) n'affiche qu'un texte statique `Text(copy.native(.accessibilityHint))` sans aucun `Toggle` | Ajouter dans `Réglages › Lecture & accessibilité` (S-77) les bascules persistées `hapticsEnabled` (défaut `true`), `soundsEnabled` (défaut `true` ou selon préférence) et `calmModeEnabled` (plafonne les célébrations au niveau 1) |