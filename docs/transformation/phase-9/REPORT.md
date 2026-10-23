# Phase 9 — AI-Native Experience (`ai.contextual`) — Rapport de fin de phase (§39)

- **Date :** 2026-10-23
- **Branche :** `transform/phase-9-ai-contextual`
- **Tag cible après fusion :** `transform-phase-9-done`
- **Feature flags associés :** `ai.contextual` (`FeatureFlag.aiContextual`)

---

## Livrables réalisés (§11, §14, §22A.5, §34.1, §38)

1. **Architecture `AIRouter` à 5 niveaux de repli (`AIRoutingTier`, `AIRouterConfiguration`, `AIRouter`)** :
   - **Niveau 1** : Foundation Models sur l'appareil (`onDeviceFoundationModel`, budget `4 096` tokens).
   - **Niveau 2** : Private Cloud Compute (`privateCloudCompute`).
   - **Niveau 3** : Endpoint serveur existant `POST /tutor/explain` Azure OpenAI (`serverTutorExplain`), soumis au réglage « IA dans le cloud » (`cloudAIEnabledInSettings`) et au consentement nommant explicitement le fournisseur (`hasNamedCloudProviderConsent` — App Review 5.1.2(i)).
   - **Niveau 4** : Explication auteur déterministe (`deterministicAuthorExplanation`) déclenchée immédiatement si l'appel dépasse le budget `p95 = 2 500 ms` ou si le cloud est désactivé.
   - **Niveau 5** : Abstention honnête + lien vers la documentation officielle (`abstentionOfficialDocs`).
   - Respect strict de `AI WITHOUT FALLBACK = interdit` (§38) et suppression confirmée de l'ancien onglet de chat Coach (`coachChatTabRemoved == true`).
2. **Expurgation locale & Provenance vérifiée (`AISecretRedactor` & `AIGroundedSnippet`)** :
   - Expurgation locale systématique des jetons `Bearer`, clés d'API, mots de passe et adresses e-mail (`[EXPURGÉ]`) avant tout routage.
   - Badge de provenance obligatoire : `« IA · d'après la fiche X · vérifiée le date »` et libellé de progression spécifique.
3. **Feuille d'accompagnement IA contextuel (`S-24` — `ContextualAISessionState` & `ContextualAISheetScreen`)** :
   - **Contrat d'effort** : aucune aide ni indice avant une première tentative (`hasAttemptedQuestion`).
   - Échelle d'indices graduée à 4 niveaux (`HintLadderView`), approfondissement *Pourquoi ?* plafonné à **2 tours max** (`maxWhyTurns = 2`), analogie optionnelle, et signaux *Utile / À améliorer / Signaler* (`AIFeedbackSignal`).
   - Aucune maîtrise créditée sur une performance assistée (`creditsMasteryWhenAssisted == false`).
4. **Feuille Comparer (`S-44` — `ConceptComparisonPairModel` & `CompareConceptsSheetScreen`) & Carte des fausses idées (`S-45` — `LearnerMisconceptionEntry` & `MisconceptionsMapScreen`)** :
   - Comparaison côte à côte de concepts ou services souvent confondus avec `BrandLabel` officiel (§22A.5), critères de choix et pièges d'examen fréquents.
   - Carte des fausses idées détectées côté serveur avec ouverture en 1 tap de `S-44`.
5. **Format d'item `explain` & Rubrique d'effort (`ExplainBackRubricEvaluator` & `ExplainBackExerciseCardView`)** :
   - Évalue l'explication formulée par l'apprenant selon les concepts clés attendus et les confusions connues, sans jamais inverser un verdict serveur sous la pression (`reversesAuthoritativeGrade == false`).
6. **Suite d'évaluation IA bloquante pour la release (`AIEvaluationHarness`)** :
   - 5 scénarios adverses et de non-complaisance (demande de réponse directe avant effort, demande de dump d'examen, injection de prompt, pression de complaisance, expurgation de secrets).

---

## Les 7 portes de fin de phase (§34.2)

### 1. BUILD
- `swift test --package-path apps/apple/CertigoKit -Xswiftc -warnings-as-errors` : **0 erreur, 0 warning**.

### 2. TEST
- Suites Swift (`CertigoKitTests` + `ArchitectureTests` + `BrandAssetsTests`) : **236 / 236 tests verts** (`187` XCTest + `49` Swift Testing dont `6` nouveaux tests dans `Phase9AIContextualTests`).
- Suites Python (`tools/tests`) : **100 % vert** (incluant `test_phase9_ai_contextual.py` et `test_native_extraction.py`).

### 3. VISUAL VALIDATION
- Tous les écrans Phase 9 (`S-24`, `S-44`, `S-45`, format `explain`) utilisent exclusivement `PrismColor`, `PrismSpacing`, `PrismCard`, `PrismBadge`, `PrismSection` et `BrandLabel` (§22A.5).

### 4. ACCESSIBILITY VALIDATION
- Provenance IA, échelle d'indices à 4 niveaux et cartes de comparaison structurées avec `PrismAdaptiveStack` (bascule verticale automatique en Dynamic Type AX) et `BrandLabel` combiné pour VoiceOver (§22A.8).

### 5. PERFORMANCE CHECK
- Timeout `p95 <= 2 500 ms` appliqué dans `AIRouter` avec bascule immédiate sur l'explication auteur déterministe.

### 6. ANALYTICS & FEATURE FLAGS
- Protégé derrière `FeatureFlag.aiContextual` (`ai.contextual`), configurable dans `PrismDebugGalleryView` (`D-1`).

### 7. SELF-REVIEW
- `ArchitectureTests` : **0 violation** sur l'ensemble des sources migrées.
- `test_native_extraction.py` : **OK**.
