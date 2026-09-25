# Approuver un changement scellé depuis le Mac (certigo-approve)

> **Statut : en préparation, rien n'est actif.** Le mécanisme ne sera branché qu'après la décision
> de Gabriel sur trois points (moyen de signature, portée, jeton des agents), puis la fusion d'une
> PR « S0 » qui enrôlera sa clé. D'ici là, cette page décrit ce qu'il aura à faire.
> **Invalidé si** la décision retient un autre moyen d'approbation que la signature.

## En bref

Certains fichiers de Certigo sont **scellés** : un workflow qui touche Azure ou des secrets
(`release-android.yml`, `cd-backend.yml`…) et les contrôles de la CI eux-mêmes. Les agents
travaillent avec le compte GitHub de Gabriel : un clic « Approve » sur GitHub ne prouve donc rien,
puisqu'un agent peut cliquer à sa place.

La seule preuve qu'un agent ne peut pas imiter : une **signature faite avec une clé qui ne quitte
jamais le Mac de Gabriel**. Elle est gardée dans la puce sécurisée du Mac, via l'app Secretive, et
demande **Touch ID à chaque signature**.

La signature approuve un changement **exact** : tel fichier passe de tels octets à tels octets,
avant telle date. La CI vérifie la signature avec la clé enregistrée sur `main`, jamais avec une
clé qu'une PR apporterait.

## Étape 1 — une seule fois, sur le Mac (≈ 10 minutes)

1. **Installer Secretive** : `brew install --cask secretive`, ou télécharger l'app sur
   [github.com/maxgoedjen/secretive](https://github.com/maxgoedjen/secretive/releases). L'ouvrir.
2. **Créer la clé** : bouton **+**, nom `certigo-approval`, et activer l'option qui **exige Touch ID**
   (ou l'Apple Watch) à chaque usage. Secretive ne crée que des clés que la puce ne laisse jamais
   sortir, et il affiche une notification à chaque utilisation.
3. **Enregistrer la clé publique** : la fiche de la clé, dans Secretive, indique **Public Key Path**.
   Dans le Terminal, copie ce fichier :
   ```bash
   mkdir -p ~/.ssh && cp "<chemin affiché dans Public Key Path>" ~/.ssh/certigo-approval.pub
   ```
   Il n'y a rien d'autre à configurer : `certigo-approve` trouve tout seul l'agent de Secretive.
4. **Préparer l'outil**, depuis ta copie du dépôt :
   ```bash
   cd ~/Certigo && git switch main && git pull --ff-only
   echo "alias certigo-approve='bash ~/Certigo/tools/certigo-approve.sh'" >> ~/.zshrc && source ~/.zshrc
   certigo-approve cle
   ```
   L'outil affiche l'empreinte `SHA256:…` de ta clé et une ligne commençant par
   `gabriel@certigo-approval`. **Vérifie que l'empreinte est la même que dans Secretive.**
5. **Envoyer la ligne** à l'orchestrateur, dans le chat. Elle ne contient aucun secret. Un agent
   ouvre alors la PR « S0 » qui l'enregistre sur `main`.
6. **Contrôler la PR S0** : son texte affiche l'empreinte enregistrée. Elle doit être **identique**
   à celle de Secretive. Si ce n'est pas le cas, ne la fusionne pas et préviens l'orchestrateur.
7. **Après la fusion** : `certigo-approve verifier` doit répondre « ✅ main porte bien ta clé ».

**Recommandé : une seconde clé de secours**, sur un autre appareil (par exemple un second Mac avec
Secretive), enregistrée dans la même PR S0. Une clé Secretive ne s'exporte pas et ne se sauvegarde
pas : sans clé de secours, perdre le Mac bloquerait tous les changements scellés. La prise en charge
d'une YubiKey reste à confirmer et à tester avec la clé réelle.

## Étape 2 — à chaque changement scellé (≈ 2 minutes)

1. Un agent te prévient : « la PR #N attend ta signature ».
2. Dans le Terminal :
   ```bash
   cd ~/Certigo && git switch main && git pull --ff-only
   certigo-approve N
   ```
3. L'outil télécharge lui-même `main` et la PR depuis GitHub. Il n'utilise rien de ce que l'agent
   aurait préparé. Il montre la liste des fichiers, puis **le diff complet** : lis-le, `q` pour
   quitter.
4. Il affiche exactement ce que tu vas approuver, avec la date d'expiration (14 jours par défaut).
   Tape **`oui`**, puis **Touch ID**. N'accepte Touch ID qu'à ce moment-là.
5. Le bloc signé est copié dans le presse-papiers et enregistré dans
   `~/certigo-approval-pr-N.approval`. **Colle-le en commentaire de la PR #N**, ou envoie-le dans le
   chat. Il ne contient aucun secret.
6. L'agent l'ajoute à la PR. La CI vérifie la signature, puis la fusion suit.

L'outil **refuse de signer**, sans rien faire d'autre, si :

- la PR n'est pas à jour avec `main` : demande à l'agent de la mettre à jour, puis relance ;
- ta copie de l'outil diffère de celle de `main` : fais `git pull --ff-only` ;
- la clé enregistrée sur `main` n'est pas la tienne : **alerte**, préviens l'orchestrateur.

Une signature ne vaut **qu'une fois** et **jusqu'à sa date** : si `main` change un fichier scellé
avant la fusion, ou si la date passe, il faut signer de nouveau. `certigo-approve N --jours 30`
allonge le délai (30 jours au plus).

## Contrôler à tout moment

`certigo-approve verifier` liste les clés enregistrées sur `main` avec leurs empreintes, et
**alerte** si la tienne n'y est plus. Un agent qui remplacerait ta clé serait vu ici.

## Côté agents

Pour transformer le bloc collé par Gabriel en fichier de la PR :

```bash
git fetch origin && git worktree add --detach ../certigo-main origin/main
gh api repos/gchambaud_microsoft/Certigo/issues/<N>/comments --jq '.[-1].body' > approbation.txt
node .github/scripts/import-sealed-approval.mjs --pr <N> --trusted ../certigo-main --input approbation.txt
git add .github/sealed-approvals/pr-<N>.approval && git commit -m "chore : approbation signée de la PR #<N>"
```

La commande rejoue localement le jugement de la CI, contre la clé de `main`. Elle n'ajoute aucune
confiance : c'est la CI qui décide, avec le code de `main`.

## Ce que ça prouve, et ce que ça ne prouve pas

- **Prouvé** : seule une clé enregistrée sur `main` peut approuver. Une PR ne peut pas enregistrer
  sa propre clé : la clé est lue sur `main`, et la remplacer exige une signature de la clé en place.
  La signature couvre les octets exacts avant et après, une date, et ne vaut qu'une fois.
- **Pas couvert** : le jeton des agents a les droits d'administration du dépôt, donc il peut
  modifier la protection de branche (décision de Gabriel, question 3). Et la confiance initiale
  repose sur la comparaison d'empreinte faite à l'étape 1.

## Preuves (2026-09-25)

- Le vérificateur (`.github/scripts/sealed-approval.mjs`) accepte les signatures produites par le
  vrai `ssh-keygen -Y sign` (OpenSSH 10.2, clés ECDSA P-256 et Ed25519), avec les empreintes
  qu'affiche `ssh-keygen`. Il rejette toute altération, une autre clé, un autre espace de noms,
  une date dépassée et un rejeu. Tests : 14/14 sous Node 20.20.2.
- Une signature produite par le vérificateur de test est acceptée par `ssh-keygen -Y verify`. Le
  format est donc le même dans les deux sens.
- `certigo-approve` a été essayé de bout en bout, avec un ssh-agent à la place de Secretive, sous
  **bash 3.2.57**, la version livrée avec macOS, et bash 5.3 : refus sans « oui », signature,
  acceptation par le vérificateur de la CI sur l'arbre réel de la PR, refus d'une PR en retard,
  d'une copie modifiée de l'outil et d'une clé non enregistrée
  (`tools/tests/certigo-approve.test.mjs`, à lancer en local sous Linux ou macOS).
