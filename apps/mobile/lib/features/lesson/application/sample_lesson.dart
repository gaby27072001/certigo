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
          body: 'Une VM dans le cloud est piratée parce que son mot de passe '
              'était « 1234 ». Qui est responsable : vous, ou Microsoft ?',
        ),
        LessonBlock(
          type: BlockType.concept,
          conceptId: 'c-shared-responsibility',
          title: 'Sécuriser le cloud, à deux',
          body: 'Dans le cloud, la sécurité est partagée. Microsoft sécurise '
              '« le cloud » : datacenters, matériel, hyperviseur, réseau '
              'physique. Vous sécurisez « ce que vous mettez dans le cloud » : '
              'vos données, vos identités, vos accès et la configuration de vos '
              'services. La frontière exacte dépend du type de service.',
        ),
        LessonBlock(
          type: BlockType.example,
          conceptId: 'c-shared-responsibility',
          body: 'Sur une VM Azure (IaaS), Microsoft corrige l\'hôte physique et '
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
            stem: 'Sur une machine virtuelle Azure (IaaS), qui applique les '
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
          body: 'Plus un service est managé, plus Microsoft en prend en charge. '
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
            stem: 'Quelles responsabilités restent TOUJOURS côté client, quel '
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
          type: BlockType.recap,
          conceptId: 'c-shared-responsibility',
          body: 'Microsoft sécurise le cloud ; vous sécurisez ce que vous y '
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
        explanation: 'En IaaS, la VM vous appartient logiquement : vous êtes '
            'responsable du système d\'exploitation invité, donc de ses '
            'correctifs. Microsoft ne gère que la couche sous la VM (hôte '
            'physique, hyperviseur, réseau du datacenter).',
      ),
      'chk-shared-2': CheckOutcome(
        correct: true,
        correctAnswer: <String>['a', 'b'],
        explanation: 'Vos données et vos identités/accès restent votre '
            'responsabilité dans tous les modèles. La sécurité physique et le '
            'matériel réseau sont toujours assurés par Microsoft.',
      ),
    };
