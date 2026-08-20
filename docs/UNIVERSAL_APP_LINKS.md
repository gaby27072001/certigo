# Universal Links iOS et Android App Links

Statut : **feature flag désactivé et configuration native inerte**.

Cette préparation ne choisit, n'achète, ne configure et ne déploie aucun domaine.
La PR reste en draft. L'activation attend obligatoirement :

1. le choix puis l'achat d'un nouveau domaine par l'utilisateur ;
2. la vérification documentée de sa propriété et de son contrôle DNS ;
3. la confirmation du Team ID Apple et des empreintes Play App Signing ;
4. une validation séparée avant toute modification de console, DNS ou déploiement.

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

## Verrous inactifs

- Android utilise `links-disabled.invalid`.
- iOS utilise `links-disabled.invalid` et n'assigne pas encore
  `Runner.entitlements` à `CODE_SIGN_ENTITLEMENTS`.
- Dart utilise `CERTIGO_HTTPS_LINKS_ENABLED=false` et
  `CERTIGO_HTTPS_LINKS_HOST=links-disabled.invalid` par défaut.
- Aucun fallback GitHub Pages n'est traité comme origine d'Universal/App Link.

Même si le feature flag était activé par erreur, le runtime refuse tout host
`.invalid` ainsi que le domaine tiers interdit.

## Génération locale des fichiers d'association

Le générateur exige un argument nommé `--confirmed-domain`. Il refuse le domaine
tiers interdit, ses sous-domaines et tout placeholder `.invalid`. Son utilisation
n'est permise qu'après achat et vérification explicite du nouveau domaine.

```powershell
python tools\generate_link_associations.py `
  --confirmed-domain <DOMAINE_ACHETE_ET_VERIFIE> `
  --apple-team-id <APPLE_TEAM_ID_VERIFIE> `
  --android-sha256 <SHA256_PLAY_APP_SIGNING_VERIFIE> `
  --output-dir build\link-associations
```

Les sorties locales sont placées sous
`<output-dir>\<domaine>\.well-known\`. Elles ne sont ni publiées ni déployées par
la commande.

## Checklist manuelle, après acquisition du domaine

- [ ] Choisir et acheter un nouveau domaine.
- [ ] Vérifier et consigner la propriété du domaine et le contrôle de sa zone DNS.
- [ ] Confirmer l'origine canonique exacte, sans déduire de host depuis le nom du produit.
- [ ] Préparer une page web utile pour chaque route.
- [ ] Générer AASA et `assetlinks.json` avec les identifiants de signature vérifiés.
- [ ] Faire approuver séparément toute publication des fichiers d'association.
- [ ] Activer Associated Domains et régénérer les profils Apple seulement après approbation.
- [ ] Configurer le host Android/iOS et `CERTIGO_HTTPS_LINKS_HOST` avec la même valeur confirmée.
- [ ] Activer `CERTIGO_HTTPS_LINKS_ENABLED=true` seulement dans une build dédiée validée.
- [ ] Tester les quatre routes sur appareils distribués avec les certificats déclarés.
- [ ] Conserver la PR en draft jusqu'à preuve de fonctionnement et revue explicite.

Aucune action DNS, console, déploiement ou fusion ne fait partie de cette PR.
