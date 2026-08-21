# ADR 0012 — Acquis portables signés et propriété personnelle

- **Statut :** accepté, runtime dormant
- **Date :** 2026-08-21

## Décision

Certigo définit le contrat `certigo.portable-achievement/v1` pour les badges,
compétences, certifications et preuves de complétion. Chaque preuve est :

- détenue durablement par un sujet de type `Person`, dérivé du JWT validé par un
  fournisseur d'identifiant public pseudonyme et jamais fourni dans le corps HTTP ;
- épinglée à `releaseId` et `publicManifestId`, sans référence au manifeste privé ;
- limitée aux identifiants publics, dates nécessaires, empreinte de la preuve source,
  nonce, émetteur et référence de clé ;
- signée sur une sérialisation canonique déterministe incluant l'identifiant et la
  version de clé.

Le contrat n'inclut ni nom, email, employeur, score, métrique d'entreprise, réponse,
clé de correction, ni contenu pédagogique privé. L'identifiant de complétion source
n'est jamais publié : seule son empreinte SHA-256 apparaît. Les réponses utilisateur
n'exposent ni empreinte d'idempotence ni journal d'audit interne ; une révocation
publique se limite à son motif codifié et sa date.

## Runtime et sécurité

`PortableAchievementService` orchestre l'émission, la vérification, l'attestation et
la révocation derrière deux ports :

- `IPortableCompletionEvidenceResolver` résout la complétion du sujet authentifié et
  fournit les claims autoritaires ; le client ne choisit ni acquis, ni date, ni pin ;
- `IPortableAchievementStore` doit garantir atomiquement l'unicité de
  `(person, clientRequestId)` et de la preuve de complétion ;
- `IPortableProofCryptography` fournit la clé courante et conserve la vérification des
  versions historiques après rotation.
- `IPortableSubjectIdProvider` sépare l'identité interne de l'identifiant portable
  pseudonyme publié.
- `IPortableActorContext` impose que l'identité et le type des acteurs d'attestation
  ou de révocation proviennent de l'autorisation validée, jamais du corps HTTP.

Il n'existe volontairement aucun adaptateur Azure, aucune clé locale et aucun secret
de repli dans ce lot. Les adaptateurs par défaut échouent explicitement si le feature
flag est activé sans stockage durable et gestionnaire de clés.

`PORTABLE_ACHIEVEMENTS_ENABLED` vaut `false` par défaut. Tant qu'il reste désactivé,
la surface HTTP répond comme une fonctionnalité indisponible et les acquis legacy
restent l'autorité produit.

## Idempotence, anti-rejeu et audit

Une répétition strictement identique du `clientRequestId` retourne la preuve originale.
La réutilisation du même identifiant avec un autre payload échoue. Une preuve de
complétion déjà consommée ne peut pas émettre un deuxième acquis équivalent.

Une organisation peut ajouter une attestation signée, sans devenir propriétaire.
Elle ne peut ni modifier ni révoquer l'acquis personnel. Seule la plateforme peut
enregistrer une révocation pour `fraud` ou `correction`. La preuve n'est pas supprimée :
la révocation et chaque mutation restent dans le journal d'audit.

## Activation ultérieure

L'activation exige, dans une évolution séparée :

1. un stockage durable implémentant les contraintes atomiques du port ;
2. un signataire à clés gérées, rotation et résolution des anciennes versions ;
3. un fournisseur d'identifiants pseudonymes stables, sans exposer l'identité interne ;
4. une autorisation forte pour l'administration et les organisations ;
5. des tests d'intégration de révocation, concurrence et rotation ;
6. une décision explicite de bascule du flag.
