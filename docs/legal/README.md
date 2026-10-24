# Pages légales — contrat de publication

> **Ce fichier n'est pas publié.** `tools/build_public_pages.mjs` lit
> `privacy-policy.md`, `account-deletion.md` et le pilote éditorial public
> `backend/src/Certigo.Infrastructure/Learning/Fixtures/responsible-ai-assistants.json`.
> Les notes opérationnelles écrites dans les deux documents légaux deviendraient
> du contenu public : les mettre ici.

## Cible de production

`https://www.certigo-app.com` est servi par **Azure Static Web Apps** depuis
[#406](https://github.com/gchambaud_microsoft/Certigo/pull/406). Le dépôt
prépare aussi les pages du pilote
`/learn/responsible-ai-assistants/{lessonId}/`, générées à partir du fixture
éditorial. Ce changement prépare leur publication, sans déployer ni modifier
les pages actuellement servies.

GitHub Pages **n'est pas activé** sur le dépôt : `GET repos/.../pages` rend 404,
et `https://gchambaud_microsoft.github.io/Certigo/privacy-policy/` rend 404
(mesuré le 2026-09-08).

## Aucun workflow ne publie la production

Le dépôt porte deux workflows de publication. **Aucun des deux ne peut mettre à
jour le site qui sert réellement les pages**, parce que tous deux déploient vers
GitHub Pages :

| workflow | cible | déclencheur | exécutions |
| --- | --- | --- | --- |
| `.github/workflows/publish-verified-public-pages.yml` | GitHub Pages (`actions/deploy-pages`) | `repository_dispatch` seul | **0 depuis toujours** |
| `.github/workflows/deploy-privacy-policy.yml` | GitHub Pages | `repository_dispatch` seul | 4, **toutes en échec**, dernière le 2026-06-30 |

La commande `gh api ... -f event_type=publish-verified-public-pages` documentée
dans [`../deployment-runbook.md`](../deployment-runbook.md) reste valide en tant
que chemin d'activation *GitHub Pages*, mais elle ne touche pas Azure Static Web
Apps.

**Conséquence : la publication en production est manuelle.** Éditer les
documents légaux ou le fixture éditorial et fusionner la pull request ne change
rien à ce qui est servi.

## Pourquoi il n'y a pas de déclencheur automatique — et pourquoi ne pas en poser

Le réflexe est d'ajouter un `push:` sur `docs/legal/**`, ou un workflow de
déploiement Azure. **Les deux sont bloqués par le scellé des workflows
privilégiés**, décrit dans [`../GOVERNANCE.md`](../GOVERNANCE.md) :

- Un workflow est « privilégié » dès qu'il porte `environment:` **ou** la
  chaîne `secrets.` — la liste de marqueurs est dans
  `.github/scripts/backend-deploy-workflow-policy.mjs`. Se passer d'OIDC et
  utiliser un jeton de déploiement **ne dispense pas** du scellé : la référence
  au secret est elle-même le marqueur. *Aucun workflow qui déploie ne peut être
  non privilégié.*
- Hors `cd-backend.yml`, un workflow privilégié est figé **à l'octet** : ajout et
  modification sont refusés de la même façon. Mesuré le 2026-09-08 en ajoutant
  une seule ligne de commentaire à `deploy-privacy-policy.yml` — le validateur
  rend `changed or new privileged capability is forbidden outside cd-backend.yml`.

Le message d'erreur du validateur recommande une pré-approbation puis une PR de
fusion (voir [`../runbooks/CI_WORKFLOW_CHANGES.md`](../runbooks/CI_WORKFLOW_CHANGES.md)) ;
**elle ne lève pas ce refus-ci**. Elle traite l'empreinte du workflow attendu, pas
la capacité privilégiée : mesuré le 2026-09-23, une montée de version pré-approuvée
de `release-android.yml` reste refusée à la fusion par le scellé.

Ne pas repartir sur cette piste sans lever le scellé lui-même, ce qui est une
décision de posture de sécurité et non un choix d'implémentation.

## Publier, et vérifier

Le déploiement Azure Static Web Apps est fait à la main. La ressource est
`swa-certigo-legal` (groupe `rg-certigo-web`, souscription
`b8952c8c-8f72-469d-99cd-ac906da4e2fc`) ; son domaine `www.certigo-app.com` est
en statut `Ready`. Le jeton de déploiement **n'est pas dans le dépôt** : il se
lit à la demande via `az staticwebapp secrets list`.

Construire **depuis `origin/main`**, jamais depuis un arbre de travail : une
base périmée produit une fausse divergence, puis une publication en retard.

```bash
git worktree add /tmp/pubwt origin/main --detach
cd /tmp/pubwt
PUBLIC_WEB_ORIGIN=https://www.certigo-app.com \
PUBLIC_DOMAIN_VERIFIED=true \
APPLE_CIAM_DOMAIN_RECONFIGURED=true \
  node tools/build_public_pages.mjs --output /tmp/pubsite

npx @azure/static-web-apps-cli deploy /tmp/pubsite \
  --deployment-token "$(az staticwebapp secrets list \
      --name swa-certigo-legal --resource-group rg-certigo-web \
      --query 'properties.apiKey' -o tsv)" \
  --env production
```

La CLI parcourt le **répertoire courant** pour trouver un
`staticwebapp.config.json` : la lancer depuis un dossier contenant des chemins
système illisibles la fait échouer sur `EPERM ... scandir` avant tout envoi.
Se placer dans un répertoire dédié.

Après toute publication, vérifier :

```bash
PUBLIC_WEB_ORIGIN=https://www.certigo-app.com \
PUBLIC_DOMAIN_VERIFIED=true \
APPLE_CIAM_DOMAIN_RECONFIGURED=true \
  npm run check:public-pages
```

La commande rend `0` si chaque route servie correspond au rendu des sources de
la branche courante, et `1` en listant les routes divergentes. Elle ne modifie
rien et n'a besoin d'aucun secret : elle lit les pages publiques en HTTP.

C'est le seul contrôle de dérive disponible. Il n'est pas automatisable dans un
workflow tant que le scellé tient, donc **il doit être lancé à la main après
chaque édition des pages légales**.

Par défaut, le générateur ne produit ni AASA ni réécriture pour
`/.well-known/apple-app-site-association` : cette route doit donc rester absente
jusqu'à la vérification d'un build de production `com.certigo.mobileapp`
capable de traiter les liens du pilote. Après cette preuve seulement, le
générateur peut être exécuté avec
`APPLE_UNIVERSAL_LINKS_COMPATIBLE_BUILD_VERIFIED=true`; il émet alors l'AASA
pour l'identifiant vérifié `FFQPC7NC68.com.certigo.mobileapp`. Le build doit
toujours viser `https://www.certigo-app.com`. Le bundle de développement
`com.certigo.native.dev` n'est pas ajouté à l'AASA et son préfixe n'est pas
supposé.

## État mesuré le 2026-09-08

Les deux routes légales sont **à jour** : `npm run check:public-pages` rend `0`
contre le rendu de `a49caff1`. Elles y ont été portées par une publication
manuelle du 2026-09-08, après une divergence de `/privacy-policy/` qui servait
encore le rendu de `ccbbbd06` (#406) sans le paragraphe sur la collecte de
rapports de plantage introduit par `fbb66b43`
([#374](https://github.com/gchambaud_microsoft/Certigo/pull/374)).

Cet état est invalidé par **toute fusion touchant `docs/legal/*.md` ou
`tools/build_public_pages.mjs`** qui n'est pas suivie d'une publication : c'est
la condition réelle, et non le seul passage du temps. `npm run check:public-pages`
en est la mesure. Ce constat n'est écrit qu'ici : ne pas le recopier ailleurs,
il périmerait en silence.

> La divulgation d'une collecte de données de diagnostic doit être publiée au
> plus tard quand la collecte démarre. La release iOS embarquant le SDK de
> crash reporting ne doit pas partir avant cette publication.
