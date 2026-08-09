import 'package:data/data.dart';

import 'quiz_entry.dart';

// --- Sample graded items (replaced by server grading in P1) ----------------

List<QuizEntry> sampleQuizItems() => <QuizEntry>[
  QuizEntry(
    item: const QuizItem(
      id: 'q-capex-1',
      conceptId: 'c-capex-opex',
      type: ItemType.mcq,
      stem:
          'Une équipe paie ses serveurs Azure uniquement selon la '
          'consommation mensuelle, sans achat initial. De quel modèle de '
          'coût s\'agit-il ?',
      options: <QuizOption>[
        QuizOption(id: 'a', label: 'Capex — dépense d\'investissement'),
        QuizOption(id: 'b', label: 'Opex — dépense de fonctionnement'),
        QuizOption(id: 'c', label: 'Amortissement sur 5 ans'),
        QuizOption(id: 'd', label: 'Licence perpétuelle'),
      ],
    ),
    correctOptionId: 'b',
    explanation:
        'Payer à l\'usage, sans investissement initial, est la '
        'définition de l\'Opex. Le cloud transforme l\'achat d\'actifs '
        '(Capex) en charges variables (Opex).',
  ),
  QuizEntry(
    item: const QuizItem(
      id: 'q-capex-2',
      conceptId: 'c-capex-opex',
      type: ItemType.scenario,
      stem:
          'Quel est l\'avantage principal de l\'Opex pour une startup '
          'dont la charge varie fortement ?',
      options: <QuizOption>[
        QuizOption(id: 'a', label: 'Elle possède physiquement ses serveurs'),
        QuizOption(id: 'b', label: 'Ses coûts sont fixes quoi qu\'il arrive'),
        QuizOption(id: 'c', label: 'La facture suit la demande, à la hausse comme à la baisse'),
        QuizOption(id: 'd', label: 'Elle évite toute facturation cloud'),
      ],
    ),
    correctOptionId: 'c',
    explanation:
        'L\'élasticité des coûts est clé : en Opex, la dépense '
        'monte quand la demande monte et redescend quand elle baisse — '
        'idéal pour une charge imprévisible.',
  ),
  QuizEntry(
    item: const QuizItem(
      id: 'q-capex-3',
      conceptId: 'c-capex-opex',
      type: ItemType.mcq,
      stem:
          'Acheter 50 000 € de serveurs pour son propre datacenter '
          'correspond à…',
      options: <QuizOption>[
        QuizOption(id: 'a', label: 'Du Capex'),
        QuizOption(id: 'b', label: 'De l\'Opex'),
        QuizOption(id: 'c', label: 'Du serverless'),
        QuizOption(id: 'd', label: 'Du pay-as-you-go'),
      ],
    ),
    correctOptionId: 'a',
    explanation:
        'Un gros achat d\'actifs en amont, amorti dans le temps, '
        'est l\'archétype du Capex — l\'opposé du modèle cloud à la demande.',
  ),
];
