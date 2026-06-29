# Validation manuelle — Tuteur IA (Azure OpenAI + RBAC)

Ce document décrit comment déployer, vérifier et tester le tuteur IA en production de bout en bout.

---

## 1. Déployer le Bicep mis à jour

```bash
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam \
  --name "certigo-dev-$(date +%Y%m%d%H%M)"
```

Le module `tutorOpenAiRbac` est conditionnel : il s'exécute si `tutorLlmEnabled=true`, `openAiRbacEnabled=true` **et** `tutorOpenAiAccountName` est non-vide.  
Le déploiement requiert des droits **Owner** ou **User Access Administrator** sur la ressource Azure OpenAI (scope rôle-assignment).

---

## 2. Vérifier que le rôle a été accordé

Récupérer le `principalId` de la managed identity du Function App :

```bash
FUNC_APP_NAME=$(az deployment sub show \
  --name certigo-dev \
  --query properties.outputs.functionAppName.value -o tsv)

PRINCIPAL_ID=$(az functionapp identity show \
  --name "$FUNC_APP_NAME" \
  --resource-group rg-certigo-dev \
  --query principalId -o tsv)

echo "Function App principal: $PRINCIPAL_ID"
```

Vérifier l'assignment RBAC sur la ressource OpenAI :

```bash
az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$(az group list --query "[?contains(name,'microlingo')].name" -o tsv)/providers/Microsoft.CognitiveServices/accounts/microlingo-openai" \
  --query "[].{role:roleDefinitionName,principal:principalId,principalType:principalType}" \
  -o table
```

**Attendu :** une ligne `Cognitive Services OpenAI User` avec le `principalId` du Function App.

---

## 3. Tester l'endpoint `/api/tutor/explain`

Obtenir un token (mode dev avec `AUTH_MODE=dev`, un token dev suffit) :

```bash
# Obtenir un token de développement (endpoint /api/auth/dev-token si disponible)
# ou utiliser un token Entra valide si AUTH_MODE=prod

HOST="https://<func-certigo-dev-XXXX>.azurewebsites.net"
TOKEN="<votre-bearer-token>"

curl -s -X POST "$HOST/api/tutor/explain" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"lessonId": "az-900-intro", "questionText": "What is Azure?"}' \
  | jq .
```

---

## 4. Critère de succès

La réponse HTTP doit être **200 OK** avec un corps JSON contenant :

```json
{
  "source": "ai",
  "headline": "...",
  "points": ["...", "..."],
  "encouragement": "..."
}
```

Le champ **`source == "ai"`** confirme que la réponse provient du tuteur LLM (`AzureOpenAiTutorCompletion`), et non du fallback déterministe.

Si `source == "grounded"`, cela indique que le LLM a échoué ou que `TUTOR_LLM_ENABLED=false`.

### Diagnostics en cas d'échec

| Symptôme | Cause probable | Action |
|----------|---------------|--------|
| 401 Unauthorized | Token invalide / expiré | Vérifier `AUTH_MODE` et le token |
| 403 Forbidden sur OpenAI | RBAC manquant | Relancer le déploiement Bicep, vérifier l'assignment (`az role assignment list`) |
| 500 + `TutorCompletionUnavailableException` | Quota/rate-limit OpenAI | Attendre et relancer ; vérifier la souscription Azure OpenAI |
| `source: "grounded"` | `TUTOR_LLM_ENABLED=false` ou exception silencieuse | Vérifier l'app setting `TUTOR_LLM_ENABLED=true` dans le Function App |
