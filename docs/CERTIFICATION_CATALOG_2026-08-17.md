# Catalogue officiel AWS et Google Cloud au 17 août 2026

## Portée et méthode

Ce document fige le registre de découverte Certigo au **17 août 2026**. Il ne contient ni
question, ni réponse, ni copie d'objectif d'examen. Les noms, codes, statuts et liens proviennent
exclusivement des catalogues, pages de certification, guides et annonces des fournisseurs.

Le fichier machine source est
[`catalog/official-certifications-2026-08-17.json`](../catalog/official-certifications-2026-08-17.json).
Il est embarqué dans l'API, validé au démarrage, puis fusionné avec les parcours réellement
publiés. Une certification peut donc être officiellement active alors que son contenu Certigo est
encore `planned`.

Les familles sont des regroupements de navigation Certigo dérivés des intitulés et rôles officiels.
Elles ne prétendent pas constituer une taxonomie publiée par AWS ou Google Cloud.

## Inventaire exact

### AWS Certification — 12 certifications actives

| ID Certigo | Certification et page officielle | Code | Niveau | Famille | Statut au 17/08/2026 | Guide officiel |
|---|---|---:|---|---|---|---|
| `aws-aif-c01` | [AWS Certified AI Practitioner](https://aws.amazon.com/certification/certified-ai-practitioner/) | `AIF-C01` | Foundational | IA | Active | [Guide AIF-C01](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01.html) |
| `aws-clf-c02` | [AWS Certified Cloud Practitioner](https://aws.amazon.com/certification/certified-cloud-practitioner/) | `CLF-C02` | Foundational | Fondamentaux cloud | Active | [Guide CLF-C02](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02.html) |
| `aws-saa-c03` | [AWS Certified Solutions Architect - Associate](https://aws.amazon.com/certification/certified-solutions-architect-associate/) | `SAA-C03` | Associate | Architecture | Active | [Guide SAA-C03](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03.html) |
| `aws-dva-c02` | [AWS Certified Developer - Associate](https://aws.amazon.com/certification/certified-developer-associate/) | `DVA-C02` | Associate | Développement | Active, dernier examen le 30/11/2026 | [Guide DVA-C02](https://docs.aws.amazon.com/aws-certification/latest/developer-associate-02/developer-associate-02.html) |
| `aws-soa-c03` | [AWS Certified CloudOps Engineer - Associate](https://aws.amazon.com/certification/certified-cloudops-engineer-associate/) | `SOA-C03` | Associate | Opérations | Active | [Guide SOA-C03](https://docs.aws.amazon.com/aws-certification/latest/sysops-administrator-associate-03/sysops-administrator-associate-03.html) |
| `aws-dea-c01` | [AWS Certified Data Engineer - Associate](https://aws.amazon.com/certification/certified-data-engineer-associate/) | `DEA-C01` | Associate | Données | Active | [Guide DEA-C01](https://docs.aws.amazon.com/aws-certification/latest/data-engineer-associate-01/data-engineer-associate-01.html) |
| `aws-mla-c01` | [AWS Certified Machine Learning Engineer - Associate](https://aws.amazon.com/certification/certified-machine-learning-engineer-associate/) | `MLA-C01` | Associate | Machine learning | Active, transition linguistique annoncée | [Guide MLA-C01](https://docs.aws.amazon.com/aws-certification/latest/machine-learning-engineer-associate-01/machine-learning-engineer-associate-01.html) |
| `aws-sap-c02` | [AWS Certified Solutions Architect - Professional](https://aws.amazon.com/certification/certified-solutions-architect-professional/) | `SAP-C02` | Professional | Architecture | Active | [Guide SAP-C02](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-professional-02/solutions-architect-professional-02.html) |
| `aws-dop-c02` | [AWS Certified DevOps Engineer - Professional](https://aws.amazon.com/certification/certified-devops-engineer-professional/) | `DOP-C02` | Professional | DevOps | Active | [Guide DOP-C02](https://docs.aws.amazon.com/aws-certification/latest/devops-engineer-professional-02/devops-engineer-professional-02.html) |
| `aws-aip-c01` | [AWS Certified Generative AI Developer - Professional](https://aws.amazon.com/certification/certified-generative-ai-developer-professional/) | `AIP-C01` | Professional | IA générative | Active | [Guide AIP-C01](https://docs.aws.amazon.com/aws-certification/latest/ai-professional-01/ai-professional-01.html) |
| `aws-ans-c01` | [AWS Certified Advanced Networking - Specialty](https://aws.amazon.com/certification/certified-advanced-networking-specialty/) | `ANS-C01` | Specialty | Réseau | Active, dernier examen le 25/08/2026 | [Guide ANS-C01](https://docs.aws.amazon.com/aws-certification/latest/advanced-networking-specialty-01/advanced-networking-specialty-01.html) |
| `aws-scs-c03` | [AWS Certified Security - Specialty](https://aws.amazon.com/certification/certified-security-specialty/) | `SCS-C03` | Specialty | Sécurité | Active | [Guide SCS-C03](https://docs.aws.amazon.com/aws-certification/latest/security-specialty-03/security-specialty-03.html) |

Répartition vérifiée : **2 Foundational, 5 Associate, 3 Professional, 2 Specialty**.

### Google Cloud Certification — 14 certifications actives

Google Cloud ne publie pas de code d'examen public comparable à `AZ-900` ou `SAA-C03` pour ces
certifications. Le champ `code` reste donc vide : Certigo affiche `GCP` comme badge de fournisseur
sans le présenter comme un code officiel.

| ID Certigo | Certification et page officielle | Code public | Niveau | Famille | Statut au 17/08/2026 | Guide officiel vérifié |
|---|---|---|---|---|---|---|
| `gcp-cloud-digital-leader` | [Cloud Digital Leader](https://cloud.google.com/learn/certification/cloud-digital-leader) | Non publié | Foundational | Fondamentaux cloud | Active | [Guide](https://services.google.com/fh/files/misc/cloud_digital_leader_exam_guide_english.pdf) |
| `gcp-generative-ai-leader` | [Generative AI Leader](https://cloud.google.com/learn/certification/generative-ai-leader) | Non publié | Foundational | IA générative | Active | [Guide](https://services.google.com/fh/files/misc/generative_ai_leader_exam_guide_english.pdf) |
| `gcp-associate-cloud-engineer` | [Associate Cloud Engineer](https://cloud.google.com/learn/certification/cloud-engineer) | Non publié | Associate | Opérations | Active | [Guide](https://services.google.com/fh/files/misc/associate_cloud_engineer_exam_guide_english.pdf) |
| `gcp-associate-data-practitioner` | [Associate Data Practitioner](https://cloud.google.com/learn/certification/data-practitioner) | Non publié | Associate | Données | Active | [Guide](https://services.google.com/fh/files/misc/associate_data_practitioner_exam_guide_english.pdf) |
| `gcp-associate-google-workspace-administrator` | [Associate Google Workspace Administrator](https://cloud.google.com/learn/certification/associate-google-workspace-administrator) | Non publié | Associate | Collaboration | Active, examen bêta | [Guide](https://services.google.com/fh/files/misc/associate_google_workspace_administrator_exam_guide_english.pdf) |
| `gcp-professional-cloud-architect` | [Professional Cloud Architect](https://cloud.google.com/learn/certification/cloud-architect) | Non publié | Professional | Architecture | Active | [Guide](https://services.google.com/fh/files/misc/professional_cloud_architect_exam_guide_english.pdf) |
| `gcp-professional-cloud-database-engineer` | [Professional Cloud Database Engineer](https://cloud.google.com/learn/certification/cloud-database-engineer) | Non publié | Professional | Bases de données | Active | [Guide v1.2](https://services.google.com/fh/files/misc/professional_cloud_database_engineer_exam_guide_english.pdf) |
| `gcp-professional-cloud-developer` | [Professional Cloud Developer](https://cloud.google.com/learn/certification/cloud-developer) | Non publié | Professional | Développement | Active | [Guide](https://services.google.com/fh/files/misc/professional_cloud_developer_exam_guide_english.pdf) |
| `gcp-professional-data-engineer` | [Professional Data Engineer](https://cloud.google.com/learn/certification/data-engineer) | Non publié | Professional | Données | Active | [Guide v4.2](https://services.google.com/fh/files/misc/professional_data_engineer_exam_guide_english.pdf) |
| `gcp-professional-cloud-devops-engineer` | [Professional Cloud DevOps Engineer](https://cloud.google.com/learn/certification/cloud-devops-engineer) | Non publié | Professional | DevOps | Active | [Guide](https://services.google.com/fh/files/misc/professional_cloud_devops_engineer_exam_guide_english.pdf) |
| `gcp-professional-cloud-security-engineer` | [Professional Cloud Security Engineer](https://cloud.google.com/learn/certification/cloud-security-engineer) | Non publié | Professional | Sécurité | Active | [Guide](https://services.google.com/fh/files/misc/professional_cloud_security_engineer_exam_guide_english.pdf) |
| `gcp-professional-cloud-network-engineer` | [Professional Cloud Network Engineer](https://cloud.google.com/learn/certification/cloud-network-engineer) | Non publié | Professional | Réseau | Active | [Guide](https://services.google.com/fh/files/misc/professional_cloud_network_engineer_exam_guide_english.pdf) |
| `gcp-professional-machine-learning-engineer` | [Professional Machine Learning Engineer](https://cloud.google.com/learn/certification/machine-learning-engineer) | Non publié | Professional | Machine learning | Active | [Guide](https://services.google.com/fh/files/misc/professional_machine_learning_engineer_exam_guide_english.pdf) |
| `gcp-professional-security-operations-engineer` | [Professional Security Operations Engineer](https://cloud.google.com/learn/certification/security-operations-engineer) | Non publié | Professional | Opérations de sécurité | Active | [Guide](https://services.google.com/fh/files/misc/professional_security_operations_engineer_exam_guide_english.pdf) |

Répartition vérifiée : **2 Foundational, 3 Associate, 9 Professional, aucune Specialty**.

## Métadonnées garanties et volontairement absentes

Les valeurs ci-dessous ne sont conservées que lorsqu'une page officielle les garantit. Une
recommandation d'expérience n'est jamais transformée en prérequis.

| Certification | Durée | Langues officiellement listées | Prérequis formel | Date/version de blueprint |
|---|---:|---|---|---|
| AWS Certified AI Practitioner | Non publiée | Liste complète non archivée | Aucun prérequis formel publié ; l'expérience reste une description du candidat cible | `v1.1`, 30/04/2026 (après `v1.0`, 26/03/2026) |
| AWS Certified Cloud Practitioner | Non publiée | arabe, anglais, indonésien, français, allemand, italien, japonais, coréen, portugais (Brésil), espagnol (Amérique latine et Espagne), chinois simplifié et traditionnel | Aucun prérequis formel publié | Non publiée |
| AWS Certified CloudOps Engineer - Associate | Non publiée | Non archivées sans liste complète vérifiée | Aucun prérequis formel publié ; l'expérience reste une description du candidat cible | `v1.1`, 01/06/2026 (après `v1.0`, 30/09/2025) |
| AWS Certified Data Engineer - Associate | Non publiée | Non archivées sans liste complète vérifiée | Aucun prérequis formel publié ; l'expérience reste une description du candidat cible | `v1.1`, 12/12/2025 |
| AWS Certified Machine Learning Engineer - Associate | Non publiée | anglais, japonais, coréen, chinois simplifié | Aucun prérequis formel publié ; l'expérience reste une description du candidat cible | Non publiée |
| AWS Certified Security - Specialty | Non publiée | Liste complète non archivée | Aucun prérequis formel publié ; l'expérience reste une description du candidat cible | `v1.0`, 26/03/2026 |
| Cloud Digital Leader | 90 min | anglais, français, japonais, portugais, espagnol | Aucun | Non publiée |
| Associate Cloud Engineer | 120 min | anglais, japonais, portugais, espagnol | Aucun ; les 6+ mois indiqués par Google restent une recommandation | Non publiée |
| Professional Cloud DevOps Engineer | 120 min | anglais, japonais | Non publié ; l'expérience indiquée par Google reste une recommandation | Non publiée |
| Professional Security Operations Engineer | Non archivée sans preuve extraite | Non archivées sans preuve extraite | Aucun ; l'expérience indiquée par Google reste une recommandation | Non publiée |
| Professional Data Engineer | Non archivée sans preuve extraite | Non archivées sans preuve extraite | Non archivé | Blueprint `v4.2` |
| Professional Cloud Database Engineer | Non archivée sans preuve extraite | Non archivées sans preuve extraite | Non archivé | Blueprint `v1.2` |
| Toutes les autres entrées | Non archivée sans preuve extraite | Non archivées sans preuve extraite | Aucun prérequis formel archivé | Non publiée |

L'absence d'une valeur signifie « non garantie dans les sources officielles vérifiées », et non
« aucune durée/langue/recommandation n'existe ».

## Transitions observées

- **AWS DVA-C02 → DVA-C03** : le guide DVA-C03 est publié, mais l'inscription n'ouvre que le
  1er décembre 2026. DVA-C02 reste la version active au snapshot, avec un dernier examen le
  30 novembre 2026.
- **AWS MLA-C01 → MLA-C02** : AWS annonce l'ouverture de la bêta anglaise le 1er septembre 2026.
  Le dernier examen MLA-C01 en anglais est annoncé au 28 septembre 2026, tandis que les autres
  langues suivent un calendrier différent. Aucun `retiresOn` global n'est donc inventé.
- **AWS ANS-C01** : reste active le 17 août, mais son dernier examen est le 25 août 2026. Aucun
  remplacement direct n'est officiellement annoncé.
- **AWS SysOps Administrator → CloudOps Engineer** : `SOA-C03` remplace `SOA-C02`. L'ancien nom
  et l'ancien code sont conservés comme alias, sans modifier les certifications déjà acquises.
- **AWS SCS-C02 → SCS-C03** : la version C03 est active ; `SCS-C02` reste un alias historique.
- **Google Professional Workspace Administrator → Associate Google Workspace Administrator** :
  l'ancien examen a été retiré le 31 décembre 2024 ; le catalogue actif contient le remplaçant
  Associate.

Sources officielles de transition :

- [Catalogue des guides AWS](https://docs.aws.amazon.com/aws-certification/latest/examguides/aws-certification-exam-guides.html)
- [Mise à jour MLA-C02](https://aws.amazon.com/blogs/training-and-certification/updates-to-aws-certified-machine-learning-engineer-associate-mla-c02/)
- [Retraits et lancements AWS](https://aws.amazon.com/blogs/training-and-certification/aws-certification-retirements-and-launches/)
- [Portefeuille IA et mise à jour Security AWS](https://aws.amazon.com/blogs/training-and-certification/big-news-aws-expands-ai-certification-portfolio-and-updates-security-certification/)
- [Politique Google des examens retirés](https://support.google.com/cloud-certification/answer/15608994)
- [Politique Google des examens bêta](https://support.google.com/cloud-certification/answer/9750304)
- [Annonce Google Security Operations Engineer](https://cloud.google.com/blog/products/identity-security/prove-your-expertise-with-our-new-secops-engineer-certification)

## Contrat de dépréciation Certigo

1. **Séparer le statut fournisseur du statut contenu.** `status` vaut `active` ou `retired` ;
   `contentStatus` vaut `planned` ou `available`. Une entrée active et planifiée reste visible dans
   le catalogue, mais ne peut pas devenir le parcours actif de l'apprenant.
2. **Ne jamais retirer immédiatement un identifiant.** Lors d'un renommage, l'ID canonique reste
   stable si le blueprint ne change pas. Lors d'un changement de code/blueprint, une nouvelle
   entrée est créée ; l'ancienne conserve ses `aliases`, sa date `retiredOn` et, lorsqu'il existe,
   un `replacedBy` validé.
3. **Respecter la date effective.** Une annonce future utilise `retiresOn` tout en restant
   `active`. Le premier snapshot daté après l'échéance passe l'entrée à `retired`.
4. **Retirer de la découverte, pas de l'historique.** Une entrée retirée sans contenu est masquée.
   Lorsqu'un parcours historique existe, il reste visible et sélectionnable pour préserver la
   progression, comme AI-900. Les IDs et alias restent dans le registre pendant au moins un cycle
   majeur afin de préserver progression, signets et migrations.
5. **Conserver des deep links cohérents.** Les chemins sont construits depuis le provider déclaré
   (`/library/vendor/<provider>/cert/<id>`), jamais depuis un préfixe supposé. Une entrée `planned`
   est non interactive ; aucun lien vers un parcours vide n'est émis.
6. **Tracer chaque mise à jour.** Toute évolution du registre crée un nouveau snapshot daté,
   cite la page officielle prouvant le changement et met à jour les tests de comptage et
   d'unicité.

## Arrivée du contenu par vagues

- Le registre de cette PR est la **vague 0** : 26 métadonnées, zéro question et zéro chapitre AWS
  ou GCP.
- Les contenus originaux restent publiés depuis le dépôt éditorial actif `certigo-content`. Le
  dossier historique `content/` de ce monorepo n'est pas modifié et ne redevient pas une source
  éditoriale.
- Chaque futur parcours reprend exactement l'ID du registre. Dès qu'un track publié porte cet ID,
  `ContentService` fusionne ses compteurs et son résumé avec les métadonnées officielles, puis
  expose `contentStatus: available`.
- Les vagues peuvent être livrées par niveau ou famille sans modifier le contrat mobile. Questions,
  réponses et objectifs détaillés restent hors de ce registre.

## Validation d'exhaustivité

- AWS : catalogue marketing dynamique recoupé avec le
  [catalogue officiel des guides](https://docs.aws.amazon.com/aws-certification/latest/examguides/aws-certification-exam-guides.html),
  soit 12 examens actifs le jour du snapshot. DVA-C03 est documenté mais non encore inscriptible,
  donc exclu.
- Google Cloud : page officielle rendue avec JavaScript, vérifiée à **2 Foundational +
  3 Associate + 9 Professional**, soit 14. L'ancien Professional Workspace Administrator est
  exclu comme retiré.
- Les tests imposent 12 AWS, 14 GCP, l'unicité des IDs/codes, les providers, les niveaux, les
  statuts, les hôtes HTTPS officiels et la séparation `active`/`retired`.
