# Migration vers un domaine public possédé

Le domaine possédé est `certigo-app.com`, avec l'apex comme origine canonique.
Sa zone est gérée par Wix, mais le domaine n'est pas encore attribué à un site et
l'hébergement HTTPS cible n'est pas choisi. Les pages légales et les fonctions
applicatives liées au web restent donc désactivées tant que DNS, TLS, contenus
publics et dépendances Apple ne sont pas prouvés.

## Contrat de configuration

Les valeurs suivantes sont des variables non secrètes de GitHub Environments.
Elles ne doivent jamais être inscrites dans un fichier `*.bicepparam` de
staging ou de production.

| Variable | Valeur fail-closed | Condition d'activation |
|---|---|---|
| `PUBLIC_WEB_ORIGIN` | chaîne vide | origine HTTPS canonique, sans chemin, port, query, fragment, identifiants ou point DNS terminal |
| `PUBLIC_DOMAIN_VERIFIED` | `false` | `true` uniquement après preuve de contrôle DNS et validation TLS |
| `APPLE_CIAM_DOMAIN_RECONFIGURED` | `false` | `true` uniquement après mise à jour et test des domaines/return URLs Apple et External ID |

Les valeurs `true` sont littérales et sensibles à la casse. Toute autre valeur
est refusée au lieu d'être convertie implicitement.

Le GitHub Environment `github-pages` fournit les trois variables au builder des
pages légales. Pour ce seul workload, la reconfiguration Apple n'est pas
requise, mais l'origine et la vérification explicite le sont. Les Environments
`staging` et `prod` fournissent les trois variables au writer de paramètres ARM.
L'Environment `beta` et le groupe Codemagic `certigo_mobile_config` fournissent
le même triplet aux releases mobiles. Toute opération staging/prod, rollback
compris, et toute release mobile exigent les trois conditions.

## Garde-fous

- `tools/build_public_pages.mjs` valide le contrat avant de créer `_site`; un
  dispatch sans variables ne produit donc aucun artefact publiable.
- `.github/scripts/write-secure-bicep-parameters.mjs` valide les variables du
  GitHub Environment et les injecte dans le fichier ARM temporaire en mode
  privé.
- `infra/main.bicep` répète les contrôles au plan de déploiement. Tout plan
  staging/prod échoue lorsque le contrat n'est pas prêt, même si la suppression
  de compte reste désactivée.
- `cd-backend.yml` exécute un job de préflight lié à l'Environment cible avant
  tout job qui accède à Azure pour les promotions comme pour les rollbacks, puis
  répète le contrôle dans le job IaC. Les pipelines Android, iOS historique et
  Codemagic appliquent le même gate avant de produire un binaire de release.
- Les outputs `privacyPolicyUrl`, `accountDeletionUrl`,
  `appleAppSiteAssociationUrl` et `assetLinksUrl` restent vides tant que
  `publicDomainActivationReady` vaut `false`.

GitHub Pages n'est acceptable comme origine temporaire que si l'organisation
contrôle réellement l'origine HTTPS, si les chemins publics sont stables et si
les consoles Apple/Google acceptent ces URLs. L'URL Pages de projet actuelle
requiert un préfixe de chemin et n'est donc pas une origine canonique compatible
avec ce contrat : elle reste neutralisée. Le workflow
`publish-verified-public-pages.yml` est le seul chemin d'activation futur ; le
dispatch historique reste bloqué par le builder sans configuration. Le workflow
compare aussi l'origine et le `base_path` retournés par GitHub Pages : toute URL
de projet ou tout alias qui ne sert pas l'origine vérifiée à la racine échoue
avant la création de l'artefact.

## Interface attendue par la PR #298

La PR #298 reste propriétaire des fichiers mobiles et des générateurs
d'association. Lors de sa réconciliation ultérieure, elle doit :

1. consommer uniquement les quatre URLs ARM non vides ou reproduire exactement
   le même gate avant de générer AASA/assetlinks et les redirects ;
2. refuser toute association lorsque `publicDomainActivationReady` est faux ;
3. conserver le feature flag désactivé tant que `certigo-app.com` n'est pas
   entièrement configuré ;
4. ne jamais déduire la possession d'un domaine depuis sa simple présence dans
   une variable.

Cette PR ne génère ni AASA, ni assetlinks, ni configuration mobile et ne modifie
aucun fichier appartenant à #298, notamment pas
`deploy-privacy-policy.yml`.

## Ordre de merge

Cette PR est empilée sur #312. Fusionner #312 d'abord, puis rebaser cette PR sur
`main` avant sa fusion. Aucun dispatch Pages, déploiement Bicep ou changement de
console ne doit être exécuté dans le cadre de ces deux PR.

## Actions humaines après enregistrement du domaine

1. Suivre l'inventaire, le delta DNS Wix et le rollback exacts documentés dans
   [`UNIVERSAL_APP_LINKS.md`](./UNIVERSAL_APP_LINKS.md), puis vérifier ownership,
   résolution publique, certificat et service HTTPS de l'apex.
2. Configurer `PUBLIC_WEB_ORIGIN` dans `github-pages`, `staging`, `prod`, `beta`
   et le groupe Codemagic `certigo_mobile_config`, puis
   passer `PUBLIC_DOMAIN_VERIFIED` à `true` dans chaque Environment après
   validation indépendante.
3. Reconfigurer les domaines et return URLs dans Apple Developer et Microsoft
   Entra External ID, tester le parcours réel, puis passer
   `APPLE_CIAM_DOMAIN_RECONFIGURED` à `true` dans `staging`, `prod`, `beta` et
   Codemagic.
4. Réconcilier #298 avec les outputs ci-dessus, publier et vérifier AASA et
   assetlinks, puis tester Universal Links/App Links et les redirects.
5. Publier les pages légales, vérifier leurs URLs canoniques, puis renseigner
   l'URL de suppression de compte et la politique de confidentialité dans les
   consoles stores.
6. Promouvoir d'abord en staging, exécuter les tests réels, puis promouvoir en
   production après approbation humaine.
