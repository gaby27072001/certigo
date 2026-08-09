import 'package:data/data.dart';

import 'check_outcome.dart';

/// Offline fallback content for the lesson player (P0).
///
/// A complete, original AZ-900 micro-lesson on the shared responsibility model,
/// with two graded checks. Replaced by `lessonRepository.getLesson(...)` once the
/// backend is wired. It lives here (not under `content/`) because it ships *with*
/// its answer key, enabling fully-offline grading via [EmbeddedKeyGrader].
Lesson sampleLesson(String lessonId) => Lesson(
  id: lessonId,
  trackId: 'az-900',
  unitId: 'az900-u-security',
  domainId: 'security',
  title: 'Le modèle de responsabilité partagée',
  estMinutes: 5,
  blocks: const <LessonBlock>[
    LessonBlock(
      type: BlockType.hook,
      conceptId: 'c-shared-responsibility',
      body:
          'Une VM dans le cloud est piratée parce que son mot de passe '
          'était « 1234 ». Qui est responsable : vous, ou Microsoft ?',
    ),
    LessonBlock(
      type: BlockType.concept,
      conceptId: 'c-shared-responsibility',
      title: 'Sécuriser le cloud, à deux',
      body:
          'Dans le cloud, la sécurité est partagée. Microsoft sécurise '
          '« le cloud » : datacenters, matériel, hyperviseur, réseau '
          'physique. Vous sécurisez « ce que vous mettez dans le cloud » : '
          'vos données, vos identités, vos accès et la configuration de vos '
          'services. La frontière exacte dépend du type de service.',
    ),
    LessonBlock(
      type: BlockType.example,
      conceptId: 'c-shared-responsibility',
      body:
          'Sur une VM Azure (IaaS), Microsoft corrige l\'hôte physique et '
          'l\'hyperviseur. Vous, vous appliquez les mises à jour du système '
          'd\'exploitation invité, configurez le pare-feu réseau (NSG) et '
          'imposez des mots de passe forts avec MFA.',
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-shared-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.mcq,
        stem:
            'Sur une machine virtuelle Azure (IaaS), qui applique les '
            'mises à jour de sécurité du système d\'exploitation invité ?',
        options: <QuizOption>[
          QuizOption(id: 'a', label: 'Le client (vous)'),
          QuizOption(id: 'b', label: 'Microsoft, automatiquement'),
          QuizOption(id: 'c', label: 'Personne, une VM se met à jour seule'),
          QuizOption(id: 'd', label: 'L\'hébergeur régional du datacenter'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.concept,
      conceptId: 'c-shared-responsibility',
      title: 'La frontière bouge avec le service',
      body:
          'Plus un service est managé, plus Microsoft en prend en charge. '
          'En IaaS vous gérez l\'OS ; en PaaS la plateforme s\'en occupe ; '
          'en SaaS presque tout est géré pour vous. Mais certaines '
          'responsabilités ne vous quittent jamais.',
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-shared-2',
        conceptId: 'c-shared-responsibility',
        type: ItemType.multi,
        stem:
            'Quelles responsabilités restent TOUJOURS côté client, quel '
            'que soit le modèle (IaaS, PaaS, SaaS) ? Plusieurs réponses.',
        options: <QuizOption>[
          QuizOption(id: 'a', label: 'Les données'),
          QuizOption(id: 'b', label: 'La gestion des identités et des accès'),
          QuizOption(id: 'c', label: 'La sécurité physique des datacenters'),
          QuizOption(id: 'd', label: 'La maintenance du matériel réseau'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-order-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.ordering,
        stem:
            'Remets dans l\'ordre les étapes pour sécuriser une nouvelle '
            'machine virtuelle Azure, de la première à la dernière.',
        options: <QuizOption>[
          QuizOption(id: 's1', label: 'Créer la VM dans un réseau virtuel'),
          QuizOption(id: 's2', label: 'Restreindre les ports entrants avec un NSG'),
          QuizOption(id: 's3', label: 'Activer MFA sur le compte administrateur'),
          QuizOption(id: 's4', label: 'Stocker les secrets dans Key Vault'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-cloze-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.cloze,
        stem:
            'En ____, vous gérez le système d\'exploitation invité, tandis '
            'qu\'en ____ la plateforme s\'en charge à votre place.',
        options: <QuizOption>[
          QuizOption(id: 'w-iaas', label: 'IaaS'),
          QuizOption(id: 'w-paas', label: 'PaaS'),
          QuizOption(id: 'w-saas', label: 'SaaS'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-match-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.matchPairs,
        stem: 'Associe chaque service Azure à son modèle de service.',
        options: <QuizOption>[
          QuizOption(id: 'l1', label: 'Azure Virtual Machines'),
          QuizOption(id: 'l2', label: 'Azure App Service'),
          QuizOption(id: 'l3', label: 'Microsoft 365'),
        ],
        matches: <QuizOption>[
          QuizOption(id: 'r1', label: 'IaaS'),
          QuizOption(id: 'r2', label: 'PaaS'),
          QuizOption(id: 'r3', label: 'SaaS'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-scenario-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.scenario,
        stem:
            'Votre équipe veut publier une application web sans gérer de '
            'serveurs ni de système d\'exploitation, tout en gardant la main '
            'sur le code. Quel modèle de service choisir ?',
        options: <QuizOption>[
          QuizOption(id: 'a', label: 'PaaS (ex. Azure App Service)'),
          QuizOption(id: 'b', label: 'IaaS (ex. machines virtuelles)'),
          QuizOption(id: 'c', label: 'SaaS (ex. Microsoft 365)'),
          QuizOption(id: 'd', label: 'Tout héberger sur site (on-premises)'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.check,
      conceptId: 'c-shared-responsibility',
      check: QuizItem(
        id: 'chk-spot-1',
        conceptId: 'c-shared-responsibility',
        type: ItemType.spotTheIssue,
        stem:
            'Un administrateur sécurise une VM Azure. Quelle action '
            'affaiblit la sécurité au lieu de la renforcer ?',
        options: <QuizOption>[
          QuizOption(
            id: 'a',
            label:
                'Ouvrir le port RDP (3389) à tout '
                'internet (0.0.0.0/0)',
          ),
          QuizOption(id: 'b', label: 'Activer MFA sur le compte administrateur'),
          QuizOption(id: 'c', label: 'Restreindre les accès avec un NSG'),
          QuizOption(id: 'd', label: 'Stocker les secrets dans Key Vault'),
        ],
      ),
    ),
    LessonBlock(
      type: BlockType.recap,
      conceptId: 'c-shared-responsibility',
      body:
          'Microsoft sécurise le cloud ; vous sécurisez ce que vous y '
          'mettez. Vos données et vos identités restent toujours votre '
          'responsabilité — quel que soit le service.',
    ),
  ],
);

/// Answer key for [sampleLesson]'s checks — itemId → correct ids + explanation.
/// Used only by the offline [EmbeddedKeyGrader]; never shipped to production.
Map<String, CheckOutcome> sampleAnswerKey() => const <String, CheckOutcome>{
  'chk-shared-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['a'],
    explanation:
        'En IaaS, la VM vous appartient logiquement : vous êtes '
        'responsable du système d\'exploitation invité, donc de ses '
        'correctifs. Microsoft ne gère que la couche sous la VM (hôte '
        'physique, hyperviseur, réseau du datacenter).',
  ),
  'chk-shared-2': CheckOutcome(
    correct: true,
    correctAnswer: <String>['a', 'b'],
    explanation:
        'Vos données et vos identités/accès restent votre '
        'responsabilité dans tous les modèles. La sécurité physique et le '
        'matériel réseau sont toujours assurés par Microsoft.',
  ),
  'chk-order-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['s1', 's2', 's3', 's4'],
    explanation:
        'On part du socle réseau (créer la VM dans un réseau '
        'virtuel), puis on filtre le trafic entrant (NSG), on durcit '
        'l\'identité d\'administration (MFA) et enfin on protège les secrets '
        '(Key Vault). Chaque étape s\'appuie sur la précédente.',
  ),
  'chk-cloze-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['w-iaas', 'w-paas'],
    explanation:
        'En IaaS, l\'OS invité est à vous : vous le patchez. En '
        'PaaS, la plateforme gère l\'OS et l\'exécution — vous ne fournissez '
        'que votre application. SaaS irait encore plus loin (tout est géré).',
  ),
  'chk-match-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['l1:r1', 'l2:r2', 'l3:r3'],
    explanation:
        'Azure Virtual Machines = IaaS (vous gérez l\'OS). Azure '
        'App Service = PaaS (la plateforme exécute votre code). Microsoft 365 '
        '= SaaS (une application prête à l\'emploi).',
  ),
  'chk-scenario-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['a'],
    explanation:
        'Le PaaS (Azure App Service) exécute votre code sans que '
        'vous gériez serveurs ni système d\'exploitation, tout en vous '
        'laissant la maîtrise de l\'application. L\'IaaS vous laisserait gérer '
        'l\'OS ; le SaaS ne laisse pas déployer son propre code.',
  ),
  'chk-spot-1': CheckOutcome(
    correct: true,
    correctAnswer: <String>['a'],
    explanation:
        'Exposer le port RDP (3389) à 0.0.0.0/0 l\'ouvre au monde '
        'entier et invite les attaques par force brute. On restreint plutôt '
        'l\'accès (NSG, Bastion, IP de confiance). Les autres actions '
        'renforcent bien la sécurité.',
  ),
};
