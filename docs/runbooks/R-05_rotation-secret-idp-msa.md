# R-05 — Rotation du secret IdP « Microsoft account » + alerte d'expiration J-30

| Champ | Valeur |
|---|---|
| **Finding** | R-05 (🔴 Haut) |
| **Constat audit** | L'IdP « Microsoft account » du flux prod dépend du secret `certigo-ciam-oidc-2026-07` (app `Certigo MSA Login` `df42c145`), qui **expire le 2027-07-01**. |
| **Impact** | À l'expiration → **le bouton « Se connecter avec un compte Microsoft » cesse de fonctionner** en production (échec OIDC). |
| **Cible** | App registration `Certigo MSA Login` (`df42c145`) + user flow `susi_certigo` (`7fdf12ed`) |

> **Pourquoi ce runbook ?** Ce secret joue **deux rôles** : (1) client secret de l'app `df42c145`
> **et** (2) valeur `clientSecret` configurée dans l'IdP OIDC « Microsoft account » du user flow de
> production. Il faut donc **faire tourner le secret des deux côtés de façon coordonnée**, sans
> coupure, puis **outiller une alerte** pour ne plus jamais être surpris par une expiration.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle app** | `Owner` de l'app `df42c145` **ou** `Application Administrator` du tenant CIAM |
| **Rôle External ID** | Droit de modifier les identity providers / user flows (`External ID User Flow Administrator` ou GA) |
| **Tenant cible** | `af721be8-5901-422a-b299-b9c57847b968` |
| **Permissions Graph** | `Application.ReadWrite.All`, `IdentityProvider.ReadWrite.All` |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : la séquence de rotation sans coupure (append → maj IdP → test → purge),
  le script d'alerte J-30, l'évaluation certificat.
- 👤 **Exécuté par vous** : la génération du nouveau secret, la mise à jour de l'IdP, le test de login,
  la suppression de l'ancien secret, le déploiement de l'alerte.

---

## Procédure de rotation (sans coupure de service)

### 1. Connexion au tenant CIAM

```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions
```

### 2. Inventaire de l'existant (identifier le secret courant)

```bash
az ad app credential list --id df42c145 \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
```

> 📌 Notez le `keyId` du secret `certigo-ciam-oidc-2026-07` → il servira à le supprimer à l'étape 6
> (`<ANCIEN_KEY_ID>`).

### 3. Générer un **nouveau** secret (en `--append`, sans supprimer l'ancien)

```bash
az ad app credential reset \
  --id df42c145 \
  --display-name "certigo-ciam-oidc-2027-07" \
  --years 1 \
  --append
```

> ⚠️ `--append` est **essentiel** : sans lui, `az ad app credential reset` **supprime tous les
> secrets existants** et couperait la prod immédiatement. Avec `--append`, l'ancien et le nouveau
> coexistent le temps de la bascule.
>
> 📋 **Copiez immédiatement** la valeur `password` renvoyée (le `<NOUVEAU_SECRET>`) : elle **n'est
> affichée qu'une seule fois**.

### 4. Mettre à jour l'IdP « Microsoft account » avec le nouveau secret

L'IdP OIDC est configuré côté External ID. Deux voies :

**Voie A — Portail (recommandée pour fiabilité)** :
Centre d'administration Entra → **External Identities** → **All identity providers** →
ouvrir « Microsoft account » → remplacer le **Client secret** par `<NOUVEAU_SECRET>` → **Save**.

**Voie B — Microsoft Graph (`az rest`)** :

```bash
# 4a. Retrouver l'id de l'identity provider "Microsoft account"
az rest --url "https://graph.microsoft.com/beta/identity/identityProviders" -o json
# → repérer l'entrée MicrosoftAccount / OIDC liée a df42c145, noter son "id" (<IDP_ID>)

# 4b. Mettre a jour son clientSecret
az rest --method PATCH \
  --url "https://graph.microsoft.com/beta/identity/identityProviders/<IDP_ID>" \
  --headers "Content-Type=application/json" \
  --body '{"clientSecret": "<NOUVEAU_SECRET>"}'
```

> ℹ️ Selon la configuration exacte du flux (identity provider classique vs
> `authenticationEventsFlows`), le chemin Graph peut varier. **En cas de doute, utilisez la Voie A
> (portail)** qui met à jour le bon objet de façon sûre.

### 5. **Tester** le login Microsoft en production (avant de purger l'ancien secret)

1. Ouvrir le parcours de connexion prod (app `Certigo Mobile` / user flow `susi_certigo`).
2. Cliquer **« Se connecter avec un compte Microsoft »**.
3. Vérifier que l'authentification aboutit **sans erreur** (`invalid_client` = secret non pris en compte).

> 🚦 **Ne passez à l'étape 6 que si le test réussit.** Tant que l'ancien secret existe encore, un
> échec ne coupe rien : vous pouvez re-corriger l'IdP.

### 6. Supprimer l'ancien secret (une fois le nouveau validé)

```bash
az ad app credential delete --id df42c145 --key-id <ANCIEN_KEY_ID>
```

### 7. Vérification finale

```bash
az ad app credential list --id df42c145 \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
# Attendu : un SEUL secret "certigo-ciam-oidc-2027-07", exp. ~ +1 an. L'ancien a disparu.
```

✅ **Critère de succès** : login Microsoft fonctionnel **et** un unique secret actif non expiré.

---

## Mise en place de l'alerte d'expiration (J-30)

Objectif : ne plus jamais découvrir l'expiration après coup. Deux dispositifs **complémentaires**.

### Dispositif 1 — Owner de l'app avec e-mail (notifications natives Entra)

Entra envoie automatiquement des e-mails d'expiration de credentials **aux owners de l'application**.
Vérifiez / ajoutez un owner disposant d'une boîte surveillée :

```bash
# Lister les owners actuels
az ad app owner list --id df42c145 --query "[].{upn:userPrincipalName, id:id}" -o table

# Ajouter un owner (objectId d'un utilisateur avec e-mail surveillé)
az ad app owner add --id df42c145 --owner-object-id <OWNER_OBJECT_ID>
```

### Dispositif 2 — Alerte planifiée (GitHub Action cron)

Interroge Graph chaque jour, calcule les jours restants et notifie à **J-30**. Script prêt à copier
(placeholders à compléter). À placer dans un dépôt **outillage/ops** — **pas** dans ce dépôt applicatif
si le périmètre l'exclut ; ici il est fourni **à titre de modèle**.

```yaml
# .github/workflows/ciam-secret-expiry-alert.yml  (MODÈLE — à déployer côté ops)
name: Alerte expiration secret IdP CIAM
on:
  schedule:
    - cron: "0 7 * * *"   # tous les jours 07:00 UTC
  workflow_dispatch: {}
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Login Azure (service principal dédié, lecture seule sur l'app)
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CIAM_CREDENTIALS }}
      - name: Vérifier l'expiration du secret df42c145
        shell: bash
        run: |
          APP_ID="df42c145"
          THRESHOLD_DAYS=30
          END=$(az ad app credential list --id "$APP_ID" \
                --query "sort_by([], &endDateTime)[-1].endDateTime" -o tsv)
          NOW=$(date -u +%s); EXP=$(date -u -d "$END" +%s)
          DAYS=$(( (EXP - NOW) / 86400 ))
          echo "Secret df42c145 expire dans $DAYS jours ($END)"
          if [ "$DAYS" -le "$THRESHOLD_DAYS" ]; then
            curl -H 'Content-Type: application/json' \
                 -d "{\"text\":\"⚠️ Secret IdP CIAM (df42c145) expire dans $DAYS jours ($END). Lancer le runbook R-05.\"}" \
                 "${{ secrets.TEAMS_WEBHOOK_URL }}"
            exit 1
          fi
```

> 🔑 Le service principal `AZURE_CIAM_CREDENTIALS` doit être **en lecture seule** sur l'app
> (`Application.Read.All` suffit). Notification : webhook Teams **ou** e-mail via Azure Communication
> Services (déjà présent dans l'écosystème du projet).

---

## Évaluation : passage à un **certificat** ?

| Question | Réponse |
|---|---|
| L'IdP OIDC External ID accepte-t-il un certificat (`private_key_jwt` / `client_assertion`) ? | ❌ **Non.** Le champ IdP « Microsoft account » attend un **`clientSecret` (chaîne)**. Un certificat ne peut pas y être injecté. |
| Peut-on mettre un certificat sur l'app `df42c145` elle-même ? | Techniquement oui pour l'app, mais **l'IdP du user flow ne l'utiliserait pas** → sans effet sur le finding. |
| **Recommandation** | **Conserver le client secret**, avec **rotation annuelle outillée** (ce runbook) + **alerte J-30**. Réévaluer le certificat **uniquement si** l'IdP est un jour remplacé par une fédération supportant `client_assertion`. |

---

## Rollback

- **Pendant la rotation** : tant que l'ancien secret n'est pas supprimé (étapes 3→5), en cas d'échec
  du test, **remettre l'ancien secret** dans l'IdP (Voie A/B) — aucune coupure.
- **Après suppression accidentelle du bon secret** : `az ad app credential reset --id df42c145
  --append` pour en générer un nouveau, puis mettre à jour l'IdP (étape 4). ⚠️ Un secret **supprimé
  n'est pas récupérable** : il faut en régénérer un et re-propager côté IdP.

---

## Notes & considérations

- Le nommage `certigo-ciam-oidc-<AAAA-MM>` (mois d'expiration) rend l'échéance lisible d'un coup d'œil
  dans `az ad app credential list`.
- Ancrez la rotation dans le calendrier ops à **échéance − 30 jours** (l'alerte J-30 sert de filet).
- Après rotation, mettez à jour toute documentation interne référençant `certigo-ciam-oidc-2026-07`.
- L'audit confirme qu'**aucun** autre secret du tenant n'expire à < 90 jours : R-05 est le seul secret
  à échéance rapprochée côté prod. Les secrets des apps QuickStart (2028) seront de toute façon
  supprimés par le runbook **O-05**.
