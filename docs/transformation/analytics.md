# Taxonomie Normative Analytics CertiGo (§31, DR-008)

Conformément à `DR-008` et au §31 de `CERTIGO_AGENT.md`, CertiGo utilise uniquement un pipeline interne first-party (`AnalyticsClient` dans `CertigoDomain`, conteneur `events`), **sans aucun SDK publicitaire ni suivi inter-apps**, avec consentement explicite (UE) et zéro donnée personnelle (PII) dans les propriétés.

| Famille | Événement (`snake_case`) | Déclencheur | Propriétés autorisées | Écran | Phase |
|---|---|---|---|---|---|
| Cycle de vie | `app_opened` | Ouverture de l'app | `source` (`icon\|widget\|notification\|intent\|spotlight\|link`) | Global | 3 / 10 |
| Cycle de vie | `onboarding_step_viewed` | Affichage d'une étape d'onboarding | `step` | `S-01`..`S-06` | 10 |
| Cycle de vie | `onboarding_completed` | Fin du premier lancement | `duration_s` | `S-05`/`S-06` | 10 |
| Cycle de vie | `taste_completed` | Situation de découverte validée | `correct`, `duration_s` | `S-02` | 10 |
| Cycle de vie | `account_created` | Sauvegarde du compte | `provider` | `S-05` | 10 |
| Séance | `session_started` | Lancement d'une séance | `length`, `entry` | `S-10` → `S-20` | 4 |
| Séance | `card_viewed` | Affichage d'une carte | `kind`, `concept_id` | `S-21` | 4 |
| Séance | `item_presented` | Présentation d'un exercice | `format`, `concept_id`, `rung`, `difficulty` | `S-22` | 4 |
| Séance | `item_answered` | Validation d'une réponse | `correct`, `confidence`, `latency_ms`, `attempt`, `hint_used` | `S-22` | 4 |
| Séance | `feedback_viewed` | Affichage du panneau de feedback | `dwell_ms`, `variant` | `S-23` | 5 |
| Séance | `skip_test_used` | Test de passage rapide | `passed` | `S-20` | 4 |
| Séance | `session_completed` | Fin de séance | `length`, `duration_s`, `items`, `correct_rate`, `concepts_anchored`, `misconceptions_resolved` | `S-25` | 5 |
| Séance | `session_abandoned` | Fermeture avec sauvegarde | `at_index` | `S-20` | 4 |
| Séance | `item_format_unsupported` | Format futur non pris en charge | `format` | `S-22` | 4 |
| Apprentissage | `concept_state_changed` | Changement d'état de maîtrise (serveur) | `from`, `to`, `concept_id` | `S-40`/`S-43` | 6 |
| Apprentissage | `misconception_detected` | Fausse idée détectée | `id` | `S-45` | 9 |
| Apprentissage | `knowledge_update_viewed` | Mise à jour de fiche consultée | `concept_id` | `S-43` | 6 |
| Rituels | `daily_situation_opened` | Ouverture de la Situation du jour | — | `S-30` | 5 |
| Rituels | `daily_situation_completed` | Validation de la Situation du jour | `correct`, `confidence` | `S-30` | 5 |
| Rituels | `community_distribution_viewed` | Affichage de la distribution anonyme | — | `S-30`/`S-31` | 5 / 8 |
| Rituels | `share_card_created` | Génération d'une carte de partage | `type` | `S-95` | 5 / 8 |
| Rituels | `share_card_shared` | Partage effectif de la carte | `type` | `S-95` | 5 / 8 |
| Objectifs | `goal_set` | Définition d'un objectif ou horizon | `type`, `exam_date_set` | `S-47` | 6 |
| Objectifs | `readiness_viewed` | Consultation de la Préparation | `band` | `S-49` | 6 |
| Objectifs | `mock_exam_started` | Début d'examen blanc | `route` | `S-50`/`S-51` | 5 |
| Objectifs | `mock_exam_completed` | Fin d'examen blanc | `band`, `timed` | `S-52` | 5 |
| Objectifs | `exam_outcome_reported` | Déclaration du résultat réel | `outcome`, `band_at_exam` | `S-53` | 6 |
| Habitude | `rhythm_day_completed` | Journée de rythme validée | — | `S-10`/`S-75` | 7 |
| Habitude | `rhythm_week_completed` | Objectif hebdomadaire atteint | — | `S-10`/`S-75` | 7 |
| Habitude | `reminder_scheduled` | Planification d'un rappel | `time_bucket`, `cue` | `S-75` | 7 / 10 |
| Habitude | `notification_opened` | Ouverture depuis une notification | `type` | Global | 10 |
| Habitude | `notification_permission` | Réponse à l'invitation S-06 | `status` | `S-06` | 10 |
| Social | `squad_created` | Création d'une Squad | — | `S-62` | 8 |
| Social | `squad_joined` | Adhésion à une Squad | `method` | `S-62` | 8 |
| Social | `kudos_sent` | Envoi d'un encouragement 1-tap | — | `S-61`/`S-64` | 8 |
| Social | `challenge_sent` | Envoi d'un défi 5 situations | — | `S-64`/`S-65` | 8 |
| Social | `challenge_completed` | Fin d'un défi 5 situations | `result` | `S-65` | 8 |
| Social | `privacy_setting_changed` | Modification de visibilité sociale | `setting` | `S-60`/`S-78` | 8 / 10 |
| IA | `ai_requested` | Demande d'aide IA contextuelle | `surface`, `route` (`device\|pcc\|server\|author`) | `S-24`/`S-44` | 9 |
| IA | `ai_fallback` | Repli vers le niveau suivant | `from`, `reason` | `S-24` | 9 |
| IA | `ai_feedback` | Signal utile / à améliorer | `helpful` | `S-24` | 9 |
| IA | `ai_reported` | Signalement d'une réponse IA | — | `S-24` | 9 |
| IA | `ai_consent` | Choix de consentement IA cloud | `status` | `S-79` | 9 / 10 |
| iOS | `widget_interaction` | Interaction depuis un widget | `kind` | `W-1`..`W-3` | 10 |
| iOS | `intent_invoked` | Exécution d'un App Intent | `intent` | `AI-1`/`CC-1` | 10 |
| iOS | `live_activity_started` | Démarrage d'une Live Activity | `kind` | `LA-1`..`LA-3` | 10 |
| Monétisation | `paywall_viewed` | Ouverture de CertiGo Pro | `trigger` | `S-73` | 10 |
| Monétisation | `purchase_started` | Début d'achat StoreKit 2 | `product` | `S-73` | 10 |
| Monétisation | `purchase_completed` | Confirmation d'achat StoreKit 2 | `product` | `S-73` | 10 |
| Monétisation | `purchase_cancelled` | Annulation d'achat StoreKit 2 | `product` | `S-73` | 10 |
| Qualité | `error_shown` | Affichage d'un état d'erreur | `code`, `screen` | Global | 11 |
| Qualité | `offline_mode_entered` | Passage en mode hors ligne | — | Global | 4 / 11 |
| Qualité | `content_issue_reported` | Signalement d'une fiche ou question | `item_id` | `S-23` | 5 / 11 |
