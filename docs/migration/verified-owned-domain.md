# Configuration de domaine possédé et vérifié

Le projet ne possède pas le domaine tiers historique utilisé dans plusieurs
exemples. Aucune surface opérationnelle ne doit le résoudre, le publier, le
mapper ni l'enregistrer. Aucun nouveau domaine n'est choisi par ce document.

## Règles

- Les builds `staging` et `prod` exigent une URL API HTTPS et un
  `VERIFIED_OWNED_API_HOST` distinct, identique au host de l'URL et confirmé par
  l'opérateur.
- Les URL légales, le site public et l'adresse de support viennent de variables
  validées. Une valeur absente, placeholder ou portée par un host non vérifié
  bloque la publication.
- Les identifiants JSON Schema utilisent des URN versionnées. L'ancien
  identifiant du catalogue applicatif reste temporairement un token opaque de
  compatibilité : il ne constitue ni une URL ni une preuve de propriété.
- Le validateur `.github/scripts/validate-domain-policy.mjs` interdit toute
  nouvelle référence opérationnelle et limite l'exception de compatibilité aux
  fichiers de contrat explicitement listés.

## Réalignement de #296

La PR #296 est déjà fusionnée dans `main`. Ses pages publiques, contacts et
gates de release doivent consommer la configuration publique validée de cette
PR. La présente branche ne modifie pas l'ancienne branche et ne réécrit pas son
historique.

## Réalignement requis de #298

La PR draft #298 ne doit pas être fusionnée dans son état actuel. Avant reprise :

1. remplacer tout host canonique codé en dur par un
   `VERIFIED_OWNED_LINK_HOST` sans valeur par défaut exploitable ;
2. garder Universal Links, App Links et Associated Domains désactivés lorsque
   ce host, le Team ID Apple ou l'empreinte Play App Signing ne sont pas vérifiés ;
3. générer AASA et `assetlinks.json` uniquement depuis cette configuration et
   ne publier aucun fichier `.well-known` avant validation TLS et contrôle du
   host ;
4. conserver `certigo://auth/` comme callback natif CIAM tant qu'aucun redirect
   HTTPS possédé et vérifié n'est enregistré ;
5. retirer de l'App ID, du Services ID Apple, de CIAM et des fiches stores toute
   URL ou association héritée du domaine tiers avant activation.

Ces opérations concernent Apple Developer, App Store Connect, Entra External ID,
Google Play et les variables CI. Elles n'autorisent aucune modification DNS,
aucun déploiement et aucune activation depuis cette PR.
