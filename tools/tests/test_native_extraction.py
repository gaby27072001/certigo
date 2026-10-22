"""Frozen baseline payloads prove extraction did not edit screen implementations."""

import hashlib
import json
from pathlib import Path
import re
import unittest

from native_sources import EXTRACTED_FILES, SOURCES


class NativeExtractionTests(unittest.TestCase):
    def test_every_extracted_payload_matches_the_frozen_baseline(self):
        manifest = json.loads(
            (Path(__file__).parent / "fixtures/native_extraction.json").read_text(encoding="utf-8")
        )
        self.assertEqual(set(manifest), set(EXTRACTED_FILES))
        for name, entry in manifest.items():
            with self.subTest(file=name):
                source = (SOURCES / name).read_text(encoding="utf-8")
                self.assertTrue(source.startswith(entry["prefix"]))
                self.assertTrue(source.endswith(entry["suffix"]))
                payload = source[len(entry["prefix"]):]
                if entry["suffix"]:
                    payload = payload[:-len(entry["suffix"])]
                if name == "CertigoNativeApp.swift":
                    addition = (
                        "                    #if DEBUG\n"
                        "                        .modifier(PrismDebugGalleryLauncher())\n"
                        "                    #endif\n"
                    )
                    self.assertEqual(payload.count(addition), 1)
                    payload = payload.replace(addition, "")
                # Only file-level visibility was widened for cross-file references.
                promoted = (
                    "NativeEntry", "NativeRoot", "NativeStudyPlanView", "NativeMockExamView",
                    "NativeNotificationPreferencesView", "NativeAccountDeletionView",
                    "NativeDemoRoot", "NativeShowcaseTile", "NativeDeveloperToolbar",
                    "NativePracticeBadge", "NativeCatalogSearch",
                )
                payload = re.sub(
                    r"\bprivate (struct|enum) (" + "|".join(promoted) + r")\b",
                    r"\1 \2", payload,
                )
                tokens = "".join(re.findall(
                    r'"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|\d+|[^\s]', payload
                ))
                self.assertEqual(
                    hashlib.sha256(tokens.encode()).hexdigest(), entry["sha256"], name
                )
