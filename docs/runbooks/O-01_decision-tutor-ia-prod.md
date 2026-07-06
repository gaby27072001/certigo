# O-01 — Note de décision : activer le Tutor IA en production ? (ADR)

| Champ | Valeur |
|---|---|
| **Finding** | O-01 (🔴 Haut — **décision requise**) |
| **Constat audit** | Le Tutor IA est **désactivé en prod** (`TUTOR_LLM_ENABLED=False`) ; **aucune** ressource Azure OpenAI n'est provisionnée en prod. La feature n'existe qu'en **dev**. |
| **Nature** | Ce document n'est **pas** un runbook d'exécution mais une **note de décision (ADR)** à valider par les responsables produit/technique. |
| **Statut** | ✅ **Décidé — Option B (repli déterministe, Phase 0)** le 2026-07-06 — voir [`docs/adr/ADR-O-01-ai-tutor-prod.md`](../adr/ADR-O-01-ai-tutor-prod.md) |

> **Pourquoi ce document ?** Il faut **trancher officiellement** : soit on investit pour amener le
> tutor en prod (Option A), soit on **acte** le mode « grounded-only » comme choix assumé (Option B).
> Laisser l'état actuel **implicite** est un risque de gouvernance (feature à moitié déployée, non
> documentée). Cette note pose les deux options, leurs conséquences, et une **recommandation
> argumentée**.

---

## Contexte technique (issu de l'audit)

- **Prod** : `TUTOR_LLM_ENABLED=False`. Aucune ressource `Microsoft.CognitiveServices` (OpenAI) en prod.
  Identité prod `61d948e4` **sans** rôle OpenAI. Réseau prod **verrouillé** (`publicNetworkAccess=Disabled`
  sur Key Vault / Cosmos / Storage).
- **Dev** : ressource `certigo-openai` (`rg-certigo-dev`, **swedencentral**), 1 déploiement
  `gpt-5.4-mini` GlobalStandard **capacity=1 (~1000 TPM)**, **jamais load-testé** (cf O-02),
  `publicNetworkAccess=Enabled`, `disableLocalAuth=true`, identité dev `55014fa6` = `Cognitive Services
  OpenAI User`.
- **Dérive IaC** : la ressource OpenAI dev a été **créée à la main** (hors Bicep/IaC — cf drift §G de
  l'audit). Aucune définition d'infrastructure ne la décrit.
- **Public cible produit** : application éducative → **données potentiellement de mineurs** (enjeu RGPD
  renforcé si envoi de contenu élève à un LLM).

---

## Option A — Provisionner Azure OpenAI en prod et activer le tutor

**Idée** : amener la feature tutor en production, avec une infrastructure OpenAI prod dédiée.

**Ébauche des étapes (si Option A retenue)** — *à détailler dans un runbook dédié le moment venu* :

1. **Mettre la ressource en IaC** (corrige d'abord le drift §G) : décrire
   `Microsoft.CognitiveServices/accounts` (kind `OpenAI`) dans le Bicep prod, plutôt que création
   manuelle. Sans cela, la prod hériterait de la même dette que le dev.
2. **Provisionner** la ressource OpenAI prod (région à valider : dispo modèle + résidence des données
   UE).
3. **Déployer le modèle** avec une **capacity dimensionnée d'après le load-test O-02** (pas capacity=1).
4. **RBAC** : attribuer `Cognitive Services OpenAI User` à l'identité prod **`61d948e4`** (managed
   identity, pas de clé — cohérent avec `disableLocalAuth=true`).
5. **Réseau** : **private endpoint** + `publicNetworkAccess=Disabled`, pour rester **cohérent avec la
   posture prod** (KV/Cosmos/Storage déjà en privé). Sinon on ouvrirait une brèche réseau dans un env
   par ailleurs verrouillé.
6. **App settings prod** : `TUTOR_LLM_ENABLED=True` + endpoint + (identité).
7. **RGPD / données mineurs** : DPIA, minimisation des données envoyées au LLM, pas de données
   identifiantes d'élève, contractualisation du traitement.
8. **Observabilité & coûts** : alertes 429 / coût, budget mensuel, quotas.

**Bénéfices** : feature pédagogique complète en prod.
**Coûts / risques** : coût OpenAI récurrent ; effort IaC + private endpoint + DPIA ; **prématuré** tant
que O-02 (load-test) n'est pas fait ; surface d'attaque et exposition de données élargies.

---

## Option B — Acter officiellement le mode « grounded-only » en prod

**Idée** : décider que la prod fonctionne **sans LLM** — uniquement contenu pédagogique **statique /
grounded** (déjà en place). Le tutor IA reste une capacité **dev / future**.

**Conséquences** :
- `TUTOR_LLM_ENABLED=False` devient un **choix documenté**, pas un oubli.
- **Aucune** donnée élève n'est envoyée à un LLM → surface RGPD minimale.
- **Zéro coût** OpenAI en prod ; **aucune** ressource supplémentaire à sécuriser.
- Réversible : le chemin A reste ouvert si le besoin est confirmé.

**Coûts / risques** : la valeur « tutor IA » n'est pas offerte aux utilisateurs prod pour l'instant.

---

## ✅ Recommandation

> **Recommandation : Option B (grounded-only) pour la prod pilote / accès contrôlé**, avec un chemin
> de réactivation A **planifié et conditionné**.

**Arguments :**

1. **Le load-test n'est pas fait (O-02).** Activer en prod une capacity=1 non testée exposerait à des
   429 sous charge dès les premiers usages concurrents. On ne met pas en prod une dépendance non
   éprouvée.
2. **Données de mineurs.** Envoyer du contenu élève à un LLM impose DPIA + minimisation. Tant que ce
   cadre n'est pas posé, s'abstenir est la position prudente.
3. **Cohérence de sécurité.** La prod est verrouillée réseau (`publicNet Disabled`). Une OpenAI prod
   **exige** un private endpoint pour ne pas créer d'incohérence — surcoût d'effort non justifié au
   stade pilote.
4. **Dette IaC.** L'OpenAI dev est hors IaC (drift §G). Reproduire ce schéma en prod aggraverait la
   dette. A ne doit être lancé qu'**après** remise en IaC.
5. **Réversibilité.** B ne ferme aucune porte : c'est le choix par défaut le moins coûteux et le plus
   sûr, révisable dès que les conditions de A sont réunies.

**Conditions de bascule vers A (à remplir *avant* d'activer le tutor en prod) :**

- [ ] Load-test O-02 réalisé, capacity/quota cible déterminés.
- [ ] Ressource OpenAI décrite en **IaC** (dev **et** prod).
- [ ] **Private endpoint** + `publicNet Disabled` validés en prod.
- [ ] RBAC `Cognitive Services OpenAI User` sur l'identité prod `61d948e4`.
- [ ] **DPIA / cadre RGPD données mineurs** validé.
- [ ] Alertes coût + 429 en place.

---

## Notes & considérations

- Cette note doit être **datée, décidée et signée** par les responsables (produit + technique + DPO si
  données mineurs). Consigner la décision (A ou B) et la date.
- Si **B** est acté : ajouter un commentaire explicite près de `TUTOR_LLM_ENABLED=False` (côté conf) et
  dans `docs/ETAT_DU_PROJET.md` renvoyant à cette ADR — **hors périmètre de ce lot** (à faire par
  l'équipe applicative, ces fichiers étant traités ailleurs).
- Si **A** est acté : ouvrir un runbook d'implémentation dédié reprenant l'ébauche ci-dessus, **après**
  O-02.
