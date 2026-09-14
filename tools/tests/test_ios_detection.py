"""Gardes de la détection d'outils de `apps/ios/Scripts/lib-detection.sh`.

## La régression que ces tests ferment

Mesuré sur un vrai MacBook le 2026-09-14. `demarrer.sh` affichait :

    ▸ 1/6  Vérification de la machine
      ✓ macOS 26.6.2 (arm64)
    $

**Fin. Aucun message, aucun code d'erreur visible, prompt rendu.**

La cause tenait en trois lignes, et c'était le garde-fou lui-même :

    if ! command -v xcodebuild >/dev/null 2>&1; then  ...aide...  fi
    XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -n 1 | awk ...)"

Sur un Mac qui n'a que les Command Line Tools, `/usr/bin/xcodebuild` **existe**
— c'est un relais `xcode-select` qui échoue à l'invocation. Donc `command -v`
réussit, l'aide n'est jamais affichée, `2>/dev/null` jette le diagnostic, et
sous `set -euo pipefail` l'affectation ratée fait sortir le script sans un mot.

**Le garde-fou testait l'existence là où il fallait tester l'utilisabilité.**

## Ce que ces tests vérifient, et pourquoi en Python

`tools/tests` est exécuté en CI par `ci-project-state.yml`
(`python -P -m unittest discover -s tools/tests -p "test_*.py"`). Un test bash
posé là ne serait découvert par personne — ce serait remplacer une garde muette
par une autre.

Les cas sont construits avec de faux `xcodebuild` sur le `PATH`, y compris le
relais CLT reproduit à la lettre.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(os.environ.get("CERTIGO_WORKSPACE", Path(__file__).resolve().parents[2]))
LIB = REPO_ROOT / "apps/ios/Scripts/lib-detection.sh"

# Le message exact du relais `xcode-select`, tel qu'il sort sur un Mac qui n'a
# que les Command Line Tools. Reproduit à la lettre : c'est lui que la détection
# doit reconnaître.
MESSAGE_CLT = (
    "xcode-select: error: tool 'xcodebuild' requires Xcode, but active "
    "developer directory '/Library/Developer/CommandLineTools' is a command "
    "line tools instance"
)

BASH = shutil.which("bash") or shutil.which("bash.exe")


@unittest.skipUnless(BASH, "bash est requis pour éprouver un script bash.")
class DetectionXcodeTests(unittest.TestCase):
    """Éprouve `certigo_detecter_xcode` sur les quatre états qu'elle distingue."""

    def setUp(self) -> None:
        self.assertTrue(LIB.is_file(), f"{LIB} est introuvable.")
        self._temp = tempfile.TemporaryDirectory()
        self.faux = Path(self._temp.name)
        self.addCleanup(self._temp.cleanup)

    def _poser_outil(self, nom: str, corps: str) -> None:
        """Pose un faux exécutable dans le répertoire mis en tête de PATH."""
        chemin = self.faux / nom
        chemin.write_text("#!/bin/sh\n" + textwrap.dedent(corps), encoding="utf-8")
        chemin.chmod(0o755)

    def _sonder(self, script: str) -> subprocess.CompletedProcess[str]:
        """Exécute `script` sous `set -euo pipefail`, avec la bibliothèque chargée.

        `set -euo pipefail` est reproduit parce que c'est **sous ce régime** que
        le défaut se manifestait : sans lui, l'affectation ratée n'aurait pas
        fait sortir le script.
        """
        enveloppe = f"""
        set -euo pipefail
        REP="$1"
        # Git Bash sur Windows n'accepte pas un chemin `C:\\...` dans PATH.
        if command -v cygpath >/dev/null 2>&1; then REP="$(cygpath -u "$REP")"; fi
        LIB="$2"
        if command -v cygpath >/dev/null 2>&1; then LIB="$(cygpath -u "$LIB")"; fi
        export PATH="$REP:$PATH"
        # shellcheck source=/dev/null
        . "$LIB"
        {script}
        """
        return subprocess.run(
            [BASH, "-c", textwrap.dedent(enveloppe), "bash", str(self.faux), str(LIB)],
            capture_output=True,
            text=True,
        )

    # ---------------------------------------------------------------- états --

    def test_xcode_absent(self) -> None:
        """Rien sur le PATH : l'état est `absent`, et le script ne sort pas."""
        resultat = self._sonder(
            'certigo_detecter_xcode\nprintf "ETAT=%s\\n" "$CERTIGO_XCODE_ETAT"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=absent", resultat.stdout)

    def test_command_line_tools_seuls(self) -> None:
        """**Le cas qui a cassé.**

        `xcodebuild` existe, `command -v` réussit, et l'invocation échoue. La
        détection doit rendre `clt` — un état distinct d'`absent`, parce que son
        remède est différent — et le script doit **continuer**.
        """
        self._poser_outil("xcodebuild", f"""
            echo "{MESSAGE_CLT}" >&2
            exit 1
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\n'
            'printf "ETAT=%s\\n" "$CERTIGO_XCODE_ETAT"\n'
            'printf "APRES=oui\\n"'
        )
        self.assertEqual(
            0,
            resultat.returncode,
            "La sonde a fait sortir le shell : c'est exactement la régression.\n"
            f"stderr={resultat.stderr}",
        )
        self.assertIn("ETAT=clt", resultat.stdout)
        self.assertIn(
            "APRES=oui",
            resultat.stdout,
            "Le script s'est arrêté après la sonde au lieu de poursuivre.",
        )

    def test_le_diagnostic_est_conserve(self) -> None:
        """`2>/dev/null` avait supprimé la seule ligne qui nommait la cause."""
        self._poser_outil("xcodebuild", f"""
            echo "{MESSAGE_CLT}" >&2
            exit 1
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\nprintf "%s\\n" "$CERTIGO_XCODE_DIAG"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("requires Xcode", resultat.stdout)
        self.assertIn("CommandLineTools", resultat.stdout)

    def test_xcode_utilisable(self) -> None:
        """Le cas nominal rend la version, et rien d'autre."""
        self._poser_outil("xcodebuild", """
            echo "Xcode 26.6"
            echo "Build version 17F99"
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\n'
            'printf "ETAT=%s VERSION=%s\\n" "$CERTIGO_XCODE_ETAT" "$CERTIGO_XCODE_VERSION"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=ok VERSION=26.6", resultat.stdout)

    def test_echec_non_reconnu_reste_distinct(self) -> None:
        """Un échec d'une autre cause ne doit pas être déguisé en `clt`.

        Une licence non acceptée, par exemple, a son propre remède. Deviner
        serait pire que rendre le message brut.
        """
        self._poser_outil("xcodebuild", """
            echo "Agreeing to the Xcode/iOS license requires admin privileges." >&2
            exit 69
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\n'
            'printf "ETAT=%s\\n" "$CERTIGO_XCODE_ETAT"\n'
            'printf "DIAG=%s\\n" "$CERTIGO_XCODE_DIAG"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=casse", resultat.stdout)
        self.assertIn("license", resultat.stdout)

    def test_sortie_vide_malgre_un_code_zero(self) -> None:
        """Rendre 0 sans rien dire est anormal : on ne devine pas une version."""
        self._poser_outil("xcodebuild", """
            exit 0
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\nprintf "ETAT=%s\\n" "$CERTIGO_XCODE_ETAT"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=casse", resultat.stdout)

    def test_set_e_est_retabli_apres_la_sonde(self) -> None:
        """La sonde suspend `set -e` ; elle doit le rendre comme elle l'a pris.

        Sans cette garantie, tout le reste du script tournerait sans `set -e` et
        les échecs suivants passeraient inaperçus — on aurait remplacé une
        sortie muette par une poursuite muette, ce qui est pire.
        """
        self._poser_outil("xcodebuild", f"""
            echo "{MESSAGE_CLT}" >&2
            exit 1
        """)
        resultat = self._sonder(
            'certigo_detecter_xcode\n'
            'case "$-" in *e*) printf "SET_E=on\\n" ;; *) printf "SET_E=off\\n" ;; esac'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("SET_E=on", resultat.stdout)


@unittest.skipUnless(BASH, "bash est requis pour éprouver un script bash.")
class DetectionOutilTests(unittest.TestCase):
    """`certigo_detecter_outil` applique la même règle aux autres binaires."""

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.faux = Path(self._temp.name)
        self.addCleanup(self._temp.cleanup)

    def _poser_outil(self, nom: str, corps: str) -> None:
        chemin = self.faux / nom
        chemin.write_text("#!/bin/sh\n" + textwrap.dedent(corps), encoding="utf-8")
        chemin.chmod(0o755)

    def _sonder(self, script: str) -> subprocess.CompletedProcess[str]:
        enveloppe = f"""
        set -euo pipefail
        REP="$1"
        if command -v cygpath >/dev/null 2>&1; then REP="$(cygpath -u "$REP")"; fi
        LIB="$2"
        if command -v cygpath >/dev/null 2>&1; then LIB="$(cygpath -u "$LIB")"; fi
        export PATH="$REP:$PATH"
        # shellcheck source=/dev/null
        . "$LIB"
        {script}
        """
        return subprocess.run(
            [BASH, "-c", textwrap.dedent(enveloppe), "bash", str(self.faux), str(LIB)],
            capture_output=True,
            text=True,
        )

    def test_outil_absent(self) -> None:
        resultat = self._sonder(
            'certigo_detecter_outil xcodegen --version\n'
            'printf "ETAT=%s\\n" "$CERTIGO_OUTIL_ETAT"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=absent", resultat.stdout)

    def test_outil_present_mais_casse(self) -> None:
        """Présent et inutilisable — le même piège que `xcodebuild`."""
        self._poser_outil("xcodegen", """
            echo "dyld: Library not loaded" >&2
            exit 1
        """)
        resultat = self._sonder(
            'certigo_detecter_outil xcodegen --version\n'
            'printf "ETAT=%s\\n" "$CERTIGO_OUTIL_ETAT"\n'
            'printf "APRES=oui\\n"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=casse", resultat.stdout)
        self.assertIn("APRES=oui", resultat.stdout)

    def test_outil_utilisable(self) -> None:
        self._poser_outil("xcodegen", """
            echo "Version: 2.44.1"
        """)
        resultat = self._sonder(
            'certigo_detecter_outil xcodegen --version\n'
            'printf "ETAT=%s SORTIE=%s\\n" "$CERTIGO_OUTIL_ETAT" "$CERTIGO_OUTIL_SORTIE"'
        )
        self.assertEqual(0, resultat.returncode, resultat.stderr)
        self.assertIn("ETAT=ok SORTIE=Version: 2.44.1", resultat.stdout)


@unittest.skipUnless(BASH, "bash est requis pour éprouver un script bash.")
class ScriptsSansSortieMuetteTests(unittest.TestCase):
    """Gardes structurelles sur les trois scripts de `apps/ios/Scripts`."""

    SCRIPTS = (
        "apps/ios/Scripts/demarrer.sh",
        "apps/ios/Scripts/verifier-tests.sh",
        "apps/ios/Scripts/prouver-le-rouge.sh",
    )

    def test_la_syntaxe_est_valide(self) -> None:
        """`bash -n` sur chaque script : une faute de syntaxe ne doit pas
        attendre le Mac pour se manifester."""
        for relatif in self.SCRIPTS:
            with self.subTest(script=relatif):
                chemin = REPO_ROOT / relatif
                self.assertTrue(chemin.is_file(), f"{relatif} est introuvable.")
                resultat = subprocess.run(
                    [BASH, "-n", str(chemin)], capture_output=True, text=True
                )
                self.assertEqual(0, resultat.returncode, resultat.stderr)

    def test_aucun_diagnostic_n_est_jete(self) -> None:
        """Aucune sonde de version ne doit rediriger `stderr` vers le néant.

        C'est la cause directe de la panne du 2026-09-14 : `2>/dev/null` sur
        `xcodebuild -version` a supprimé la seule ligne qui nommait le problème.
        """
        interdits = ("xcodebuild", "xcodegen", "swift", "xcrun")
        for relatif in self.SCRIPTS:
            chemin = REPO_ROOT / relatif
            for numero, ligne in enumerate(
                chemin.read_text(encoding="utf-8").splitlines(), start=1
            ):
                nue = ligne.strip()
                if nue.startswith("#") or "2>/dev/null" not in nue:
                    continue
                for outil in interdits:
                    if f"{outil} " in nue or f"{outil}$" in nue:
                        self.fail(
                            f"{relatif}:{numero} jette le diagnostic de « {outil} » "
                            f"dans /dev/null :\n  {nue}\n"
                            "Capturer la sortie avec 2>&1 et l'afficher en cas d'échec."
                        )

    def test_demarrer_pose_un_filet(self) -> None:
        """`demarrer.sh` doit poser un `trap` : aucun premier démarrage ne doit
        rendre le prompt sans un mot."""
        source = (REPO_ROOT / "apps/ios/Scripts/demarrer.sh").read_text(encoding="utf-8")
        self.assertIn("trap", source, "demarrer.sh ne pose aucun filet.")
        self.assertIn(
            "EXIT",
            source,
            "Le filet doit couvrir la sortie du script, pas seulement les erreurs.",
        )

    def test_demarrer_utilise_la_bibliotheque(self) -> None:
        """La détection doit passer par la bibliothèque éprouvée ci-dessus.

        Sans cette garde, quelqu'un pourrait réintroduire un
        `command -v xcodebuild` nu et la régression reviendrait sans que rien
        ne rougisse.
        """
        source = (REPO_ROOT / "apps/ios/Scripts/demarrer.sh").read_text(encoding="utf-8")
        self.assertIn("lib-detection.sh", source)
        self.assertIn("certigo_detecter_xcode", source)


if __name__ == "__main__":
    unittest.main()
