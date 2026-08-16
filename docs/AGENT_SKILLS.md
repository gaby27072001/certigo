# Skills agent de design et d'animation

Certigo versionne un sous-ensemble du bundle
[`emilkowalski/skills`](https://github.com/emilkowalski/skills) comme
referentiel de design et de mouvement pour GitHub Copilot. Ces fichiers sont
des instructions d'agent uniquement : ils n'ajoutent aucune dependance Dart,
Flutter, JavaScript ou runtime.

## Provenance auditee

| Element | Valeur |
|---|---|
| Depot amont | `emilkowalski/skills` |
| Commit inspecte | `78761e1b57f97dce65b983d640c70a68f39e8163` |
| Licence du bundle | MIT, Emil Kowalski, 2026 |
| Notice locale | `.agents/skills/LICENSE.emilkowalski-skills` |
| CLI inspecte | `skills` 1.5.22, licence MIT |
| Integrite du paquet CLI | `sha512-cHiLjwZEawWFvudIqeeMZlvZayTLbRouydMbblyrdiyH7ZLbqUrSrEEr+Tg+X265iztRlVMsyOYRwpD5JxBsvg==` |
| Lock projet | `skills-lock.json` |

L'audit du paquet CLI a confirme l'absence de script d'installation dans
l'archive publiee. La commande `add` clone la source dans un repertoire
temporaire, selectionne les dossiers contenant un `SKILL.md`, copie les fichiers
vers `.agents/skills`, puis enregistre pour chaque skill un hash SHA-256 dans
`skills-lock.json`. Le scope projet est le comportement par defaut ; l'option
globale `-g` ne doit jamais etre utilisee dans Certigo.

`skills` 1.5.22 ne restaure pas un commit Git fourni comme ref directe : il le
traite comme un nom de branche. Les copies auditees sont donc versionnees dans
ce depot, et leurs hashes constituent le controle d'integrite local. Toute mise
a jour doit refaire l'audit de provenance, de licence et du diff avant commit.

## Skills actifs

| Skill | Usage dans Certigo |
|---|---|
| `emil-design-eng` | Principes generaux de finition, hierarchie et feedback |
| `apple-design` | Gestes, ressorts, profondeur, typographie et mouvement reduit |
| `animate` | Grille de decision avant d'ajouter une animation |
| `animation-vocabulary` | Vocabulaire commun pour decrire le mouvement |
| `find-animation-opportunities` | Audit en lecture seule des opportunites utiles |
| `improve-animations` | Audit et plans d'amelioration, sans modification directe |
| `review-animations` | Revue specialisee des changements de mouvement |

Trois skills amont ne sont volontairement pas installes :

- `ask-sonner`, reserve a la bibliotheque React Sonner ;
- `pick-ui-library`, catalogue de dependances web/React ;
- `prototype`, dont le harness impose HTML, CSS et un serveur web.

## Adaptation Flutter et Prism

Les exemples CSS, React, Tailwind, JavaScript et Motion des fichiers amont sont
illustratifs. Dans Certigo :

- utiliser les widgets et animations Flutter existants ;
- reutiliser `PrismMotion` dans
  `packages/prism_ui/lib/src/tokens/prism_motion.dart` plutot que recopier les
  durees ou courbes CSS ;
- respecter `MediaQuery.disableAnimations` aux points d'appel ;
- preferer les composants Prism et les conventions Material 3 deja presentes ;
- ne jamais ajouter une dependance sans validation explicite selon `AGENTS.md` ;
- ne pas modifier l'UI uniquement pour appliquer une recommandation du bundle.

## Installation et mise a jour

La commande auditée et utilisee pour le scope projet est :

```powershell
npx --yes skills@1.5.22 add emilkowalski/skills `
  --skill animate `
  --skill animation-vocabulary `
  --skill apple-design `
  --skill emil-design-eng `
  --skill find-animation-opportunities `
  --skill improve-animations `
  --skill review-animations `
  --agent github-copilot `
  --yes
```

Avant toute mise a jour :

1. verifier la version, l'integrite, la licence et les scripts du paquet `skills` ;
2. inspecter le commit amont et le contenu des skills selectionnes ;
3. executer la commande sans `-g`, puis examiner le diff complet ;
4. normaliser les Markdown en LF comme l'impose `.gitattributes`, puis
   recalculer les hashes si le CLI a produit du CRLF sous Windows ;
5. verifier que seuls `.agents/skills` et `skills-lock.json` ont ete regeneres ;
6. conserver les garde-fous Flutter/Prism de ce document et d'`AGENTS.md`.
