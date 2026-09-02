import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


class PublicDomainProjectStateTests(unittest.TestCase):
    def test_workflow_and_security_contracts_stay_fail_closed(self) -> None:
        pages = (
            REPO_ROOT / ".github/workflows/publish-verified-public-pages.yml"
        ).read_text(encoding="utf-8")
        backend = (
            REPO_ROOT / ".github/workflows/cd-backend.yml"
        ).read_text(encoding="utf-8")
        security = (
            REPO_ROOT / ".github/workflows/security-gate.yml"
        ).read_text(encoding="utf-8")
        infra = (
            REPO_ROOT / ".github/workflows/ci-infra.yml"
        ).read_text(encoding="utf-8")
        android = (
            REPO_ROOT / ".github/workflows/release-android.yml"
        ).read_text(encoding="utf-8")
        codemagic = (REPO_ROOT / "codemagic.yaml").read_text(encoding="utf-8")

        for marker in (
            "PUBLIC_WEB_ORIGIN: ${{ vars.PUBLIC_WEB_ORIGIN }}",
            "PUBLIC_DOMAIN_VERIFIED: ${{ vars.PUBLIC_DOMAIN_VERIFIED }}",
            "APPLE_CIAM_DOMAIN_RECONFIGURED: "
            "${{ vars.APPLE_CIAM_DOMAIN_RECONFIGURED }}",
        ):
            self.assertIn(marker, pages)
            self.assertIn(marker, backend)
            self.assertIn(marker, android)
        for marker in (
            "PUBLIC_WEB_ORIGIN",
            "PUBLIC_DOMAIN_VERIFIED",
            "APPLE_CIAM_DOMAIN_RECONFIGURED",
            "public-domain-contract.mjs account-deletion-url",
        ):
            self.assertIn(marker, codemagic)

        self.assertIn("environment: github-pages", pages)
        self.assertLess(
            backend.index("validate-public-domain:"),
            backend.index("resolve-release:"),
        )
        self.assertIn(
            "Require verified public-domain contract before Azure access",
            backend,
        )
        self.assertIn("PAGES_ORIGIN: ${{ steps.pages.outputs.origin }}", pages)
        self.assertIn(
            "PAGES_BASE_PATH: ${{ steps.pages.outputs.base_path }}",
            pages,
        )
        self.assertIn(
            "node .github/scripts/public-domain-contract.mjs link-associations",
            pages,
        )
        self.assertLess(
            pages.index("node .github/scripts/public-domain-contract.mjs link-associations"),
            pages.index("node tools/build_public_pages.mjs"),
        )
        self.assertLess(
            pages.index("node tools/build_public_pages.mjs"),
            pages.index("actions/upload-pages-artifact@"),
        )
        for path in (
            ".github/scripts/public-domain-contract.mjs",
            ".github/scripts/public-domain-contract.test.mjs",
            ".github/scripts/publish-verified-public-pages.test.mjs",
            ".github/workflows/publish-verified-public-pages.yml",
            ".github/workflows/cd-backend.yml",
            ".github/workflows/release-android.yml",
            ".github/workflows/release-ios.yml",
            "codemagic.yaml",
            "tools/generate_link_associations.py",
            "tools/tests/test_generate_link_associations.py",
            "tools/tests/public_pages_security.test.mjs",
        ):
            self.assertIn(f"- '{path}'", security)
        self.assertIn(
            "node --test infra/tests/public-domain-contract.test.mjs",
            infra,
        )


if __name__ == "__main__":
    unittest.main()
