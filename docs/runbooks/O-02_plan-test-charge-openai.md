# O-02 — Plan de test de charge Azure OpenAI + bump de capacity

| Champ | Valeur |
|---|---|
| **Finding** | O-02 (🔴 Haut) |
| **Constat audit** | L'Azure OpenAI de dev n'a **jamais été load-testé**. Déploiement à **capacity=1 (~1000 TPM)** — dimensionnement inconnu face à une charge réelle. |
| **Impact** | Risque de **429 (throttling)** dès une charge modérée, sans seuil connu. Impossible de dimensionner la prod (Option A de O-01) sans cette donnée. |
| **Cible** | `certigo-openai` — RG `rg-certigo-dev`, région **swedencentral**, déploiement `gpt-5.4-mini` GlobalStandard capacity=1 |

> **Pourquoi ce runbook ?** Avant toute décision d'activation en prod (O-01, Option A) ou tout
> engagement de SLA, il faut **mesurer** le point de rupture (apparition des 429), la latence, et le
> TPM soutenable. Ce runbook fournit un **protocole de test reproductible** + la commande de **bump de
> capacity** une fois la cible connue.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle test** | `Cognitive Services OpenAI User` sur `certigo-openai` (déjà attribué à l'identité dev `55014fa6`) |
| **Rôle bump/metrics** | `Contributor` (ou `Cognitive Services Contributor`) sur `rg-certigo-dev` |
| **Subscription** | `f434ec55-…` (ou la sub hébergeant `rg-certigo-dev`) |
| **Quota régional** | Quota TPM `gpt-5.4-mini` en **swedencentral** (à vérifier, cf étape 4) |
| **Outil** | Python 3.10+ pour `azure-openai-benchmark` (ou Azure Load Testing / k6) |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : le protocole (outil, scénarios TPM, seuils 429), les commandes de mesure
  et de bump, les critères d'arrêt.
- 👤 **Exécuté par vous** : le lancement du benchmark, la lecture des métriques, la décision de la
  capacity cible, puis le bump.

---

## Étape 0 — Confirmer le nom exact du déploiement

```bash
az login
az account set --subscription f434ec55-f342-4948-9298-f99af5216204

az cognitiveservices account deployment list \
  -n certigo-openai -g rg-certigo-dev \
  --query "[].{name:name, model:properties.model.name, sku:sku.name, capacity:sku.capacity}" -o table
# → noter le <NOM_DEPLOIEMENT> exact (probablement 'gpt-5.4-mini') et capacity actuelle (=1).
```

Récupérer aussi l'endpoint :

```bash
az cognitiveservices account show -n certigo-openai -g rg-certigo-dev \
  --query "properties.endpoint" -o tsv
```

---

## Étape 1 — Outil de test

**Recommandé : [`azure-openai-benchmark`](https://github.com/Azure/azure-openai-benchmark)** — conçu
pour OpenAI, mesure **TPM effectif, TTFT, latence e2e, taux 429**, gère la montée en charge et le
back-off.

```bash
pip install azure-openai-benchmark    # ou : git clone https://github.com/Azure/azure-openai-benchmark

# Auth par identité (disableLocalAuth=true → PAS de clé) :
az login   # jeton AAD utilisé par le bench si configuré ; sinon exporter un token OpenAI AAD.
export AZURE_OPENAI_ENDPOINT="https://certigo-openai.openai.azure.com/"
```

**Alternatives** : Azure Load Testing (JMeter managé, intégré au portail) ou **k6** (scriptable) si vous
préférez un outil déjà en place.

---

## Étape 2 — Scénarios de charge (montée progressive)

Profil de prompt **réaliste du tutor** (à ajuster) : ~**800 tokens in** / ~**400 tokens out** par requête.

| Palier | TPM visé | Objectif |
|---|---|---|
| 1 | **500** | Charge nominale basse — doit passer sans 429 |
| 2 | **1000** | ≈ capacity=1 — **point de rupture attendu** |
| 3 | **1500** | Au-dessus de la capacity — 429 attendus |
| 4 | **2000** | Confirmer le plafond |
| 5 | **3000** | Stress — caractériser la dégradation |

Exemple de lancement (adapter les options à la version de l'outil) :

```bash
python -m benchmark.bench load \
  --deployment <NOM_DEPLOIEMENT> \
  --endpoint "$AZURE_OPENAI_ENDPOINT" \
  --context-tokens 800 --max-tokens 400 \
  --rate 500 \                # requêtes/min → ajuster pour viser chaque palier TPM
  --duration 300 \            # 5 min par palier
  --aggregation-window 60
# Répéter en incrémentant --rate pour chaque palier (500→1000→1500→2000→3000 TPM).
```

**Mesurer à chaque palier** : TPM effectif, **taux 429 (%)**, TTFT (P50/P95), latence e2e (P50/P95).

---

## Étape 3 — Seuils de déclenchement & critères

- **Point de rupture** : TPM où les **429 apparissent** (attendu ≈ 1000 TPM à capacity=1).
- **Seuil d'alerte** : **429 > 1 %** au TPM cible visé en usage réel → capacity insuffisante.
- **Latence** : TTFT P95 acceptable pour un usage tutor interactif (fixer un objectif, ex. < 2 s).

**Métriques serveur (croiser avec le bench)** :

```bash
OAI_ID=$(az cognitiveservices account show -n certigo-openai -g rg-certigo-dev --query id -o tsv)

# Taux de 429 côté service
az monitor metrics list --resource "$OAI_ID" \
  --metric "AzureOpenAIRequests" --dimension StatusCode \
  --interval PT1M --output table

# Tokens traités / générés (valider le TPM effectif)
az monitor metrics list --resource "$OAI_ID" \
  --metric "ProcessedPromptTokens,GeneratedTokens" \
  --interval PT1M --output table
```

---

## Étape 4 — Vérifier le quota régional AVANT de bump

```bash
az cognitiveservices account list-usage \
  -n certigo-openai -g rg-certigo-dev -o table
# → repérer l'usage/limite TPM pour gpt-5.4-mini en swedencentral.
```

Si la limite régionale est atteinte : **demander une augmentation de quota** (portail Azure OpenAI →
*Quotas*, ou support) **avant** l'étape 5.

---

## Étape 5 — Bump de capacity (une fois la cible connue)

Déterminez `<N>` d'après le load-test (chaque unité GlobalStandard ≈ 1000 TPM).
Exemple : viser ~5000 TPM → `<N> = 5`.

```bash
az cognitiveservices account deployment update \
  -n certigo-openai -g rg-certigo-dev \
  --deployment-name <NOM_DEPLOIEMENT> \
  --sku-capacity <N>
```

**Vérification** :

```bash
az cognitiveservices account deployment show \
  -n certigo-openai -g rg-certigo-dev \
  --deployment-name <NOM_DEPLOIEMENT> \
  --query "sku" -o json
# Attendu : { "name": "GlobalStandard", "capacity": <N> }
```

Relancer un **palier de validation** au nouveau TPM cible → confirmer **429 < 1 %**.

---

## Rollback

```bash
# Revenir à la capacity initiale (=1) si le bump pose problème (coût/quota) :
az cognitiveservices account deployment update \
  -n certigo-openai -g rg-certigo-dev \
  --deployment-name <NOM_DEPLOIEMENT> \
  --sku-capacity 1
```

Le test de charge lui-même est **non destructif** (aucune écriture de données) ; il consomme du quota
et génère du coût token — le lancer en **fenêtre dev** dédiée.

---

## ✅ Critère de succès

- Point d'apparition des 429 **mesuré** et documenté.
- Capacity cible **déterminée** à partir de la charge prod attendue (marge incluse).
- Après bump : **429 < 1 %** au TPM cible confirmé.

---

## Notes & considérations

- Ce load-test est un **prérequis** à la décision O-01 Option A (activation prod). Sans lui, on ne peut
  pas dimensionner la prod.
- `disableLocalAuth=true` → utiliser l'**auth AAD** (identité) dans le bench, jamais une clé.
- Documenter les résultats (paliers, 429, latences, capacity retenue) pour tracer la décision de
  dimensionnement.
- Envisager une **alerte Azure Monitor** permanente sur `AzureOpenAIRequests` (StatusCode=429) une fois
  la capacity cible en place, pour détecter toute saturation future.
