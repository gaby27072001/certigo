# Universal Links iOS et Android App Links

Statut : **domaine possédé configuré, feature flag désactivé et associations non publiées**.

Le host canonique minimal est l'apex `certigo-app.com`. Le domaine est enregistré,
vérifié et sa zone DNS est contrôlée via Wix. Aucun sous-domaine n'est prévu pour
les Universal Links/App Links. Cette PR ne modifie ni DNS, ni Wix, ni Azure, ni
console Apple/Google et ne déploie aucun fichier.

Le domaine `certigo.app` est tiers et non contrôlé. Il est explicitement interdit
par les gardes Dart, Gradle et Python. Il ne doit servir ni d'origine, ni d'exemple,
ni de valeur de build.

## Contrat des routes préparé

| Chemin HTTPS | Route interne | Authentification |
|---|---|---|
| `/learn/{trackId}/{lessonId}` | `/lesson/{trackId}/{lessonId}` | requise |
| `/assignments/{id}` | `/assignments/{id}` | requise |
| `/achievements/{id}` | `/achievements/{id}` | requise |
| `/account-deletion` | `/account-deletion` | publique |

Le parseur refuse HTTP, les ports explicites, les userinfo, les domaines suffixés,
les query strings, les fragments et les chemins non déclarés. Une destination
protégée est convertie en route interne validée avant d'être conservée pendant
l'authentification.

Le callback OIDC `certigo://auth/` reste indépendant et inchangé. Il ne dépend
d'aucun domaine HTTPS.

## Configuration préparée, activation fermée

- Android déclare `certigo-app.com`, mais l'association ne peut être vérifiée
  avant la publication HTTPS de `assetlinks.json`.
- iOS déclare `certigo-app.com` dans `Runner.entitlements`, mais n'assigne pas
  encore ce fichier à `CODE_SIGN_ENTITLEMENTS`.
- Dart utilise `CERTIGO_HTTPS_LINKS_HOST=certigo-app.com`, refuse tout autre
  host et conserve `CERTIGO_HTTPS_LINKS_ENABLED=false` par défaut.
- Les gates de domaine public conservent leurs valeurs d'activation vides/fausses.
- Aucun fallback GitHub Pages n'est traité comme origine d'Universal/App Link.

Le domaine tiers historique reste interdit, y compris ses sous-domaines. Le
runtime, Gradle et le générateur refusent tout host autre que l'apex canonique.

## Génération locale des fichiers d'association

Le générateur exige le host canonique et refuse tout sous-domaine, autre domaine
ou placeholder `.invalid`. Il nécessite toujours les identifiants de signature
vérifiés ; aucun fichier avec identifiant factice ne doit être publié.

```powershell
python tools\generate_link_associations.py `
  --confirmed-domain certigo-app.com `
  --apple-team-id <APPLE_TEAM_ID_VERIFIE> `
  --android-sha256 <SHA256_PLAY_APP_SIGNING_VERIFIE> `
  --output-dir build\link-associations
```

Les sorties locales sont placées sous
`<output-dir>\certigo-app.com\.well-known\`. Elles ne sont ni publiées ni
déployées par la commande. Les URLs finales doivent être exactement :

- `https://certigo-app.com/.well-known/apple-app-site-association`
- `https://certigo-app.com/.well-known/assetlinks.json`

Les réponses doivent être HTTPS 200, sans redirection, sans authentification,
avec le contenu JSON attendu et un certificat public valide pour l'apex.

## État DNS Wix à préserver

Inventaire confirmé avant cette PR :

| Nom | Type | TTL | Valeur |
|---|---|---:|---|
| `certigo-app.com` | `A` | 1 h | `185.230.63.171` |
| `certigo-app.com` | `A` | 1 h | `185.230.63.186` |
| `certigo-app.com` | `A` | 1 h | `185.230.63.107` |
| `www.certigo-app.com` | `CNAME` | 1 h | `initial.wixdns.net` |
| zone | `NS` | 1 j | `ns12.wixdns.net`, `ns13.wixdns.net` |

Aucun TXT n'était visible. Le domaine Wix est « non attribué à un site ». Ces
valeurs sont l'état initial et ne doivent pas être supprimées ou remplacées tant
que la cible d'hébergement HTTPS de l'apex n'est pas choisie et validée.

## Delta DNS à appliquer après choix de l'hébergement

1. Obtenir de l'hébergeur la valeur exacte d'ownership (`TXT` si demandée) et
   les cibles exactes de l'apex (`A`, `AAAA` ou `ALIAS` selon ce que Wix accepte).
2. Ajouter d'abord le TXT d'ownership fourni, sans inventer sa valeur, puis
   vérifier sa résolution publique.
3. Une fois la cible prête, remplacer uniquement les trois `A` Wix de l'apex par
   les enregistrements fournis par l'hébergeur. Ne pas modifier les NS ni le
   `CNAME` `www`, qui n'est pas utilisé par le contrat.
4. Attendre au moins le TTL de 1 h, vérifier la résolution depuis plusieurs
   résolveurs, le certificat HTTPS de l'apex et les deux URLs `.well-known`.
5. En cas d'échec, restaurer les trois `A` Wix ci-dessus, supprimer uniquement
   les enregistrements ajoutés pour la cible abandonnée, attendre le TTL puis
   revalider l'état initial.

Si l'hébergement retenu est finalement un site Wix attribué à l'apex et que les
trois `A` restent la cible documentée par Wix, aucun delta A n'est requis. Il
faut néanmoins prouver que Wix sert sans redirection les deux fichiers
`.well-known` avec les bons contenus et types de réponse.

## Checklist manuelle d'activation

- [x] Enregistrer `certigo-app.com` et vérifier le contrôle de sa zone DNS Wix.
- [x] Fixer l'origine canonique à l'apex `https://certigo-app.com`.
- [ ] Choisir la cible d'hébergement HTTPS et appliquer le delta DNS approuvé.
- [ ] Vérifier ownership, DNS public et certificat HTTPS de l'apex.
- [ ] Préparer une page web utile pour chaque route.
- [ ] Générer AASA et `assetlinks.json` avec les identifiants de signature vérifiés.
- [ ] Publier et valider les deux fichiers sans redirection.
- [ ] Activer Associated Domains et régénérer les profils Apple seulement après approbation.
- [ ] Tester les quatre routes sur appareils physiques iOS et Android distribués.
- [ ] Activer `CERTIGO_HTTPS_LINKS_ENABLED=true` seulement après ces preuves.
- [ ] Conserver la PR en draft jusqu'à preuve de fonctionnement et revue explicite.

Aucune action DNS, console, déploiement ou fusion ne fait partie de cette PR.
