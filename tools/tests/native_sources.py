"""Canonical source view for contracts retained during the Phase 1 extraction."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "apps/apple/CertigoNative/Sources"
EXTRACTED_FILES = (
    "NativeCatalogModels.swift",
    "NativeCopyCatalog.swift",
    "NativeSharedComponents.swift",
    "NativeStudyAndExamViews.swift",
    "CertigoNativeApp.swift",
    "NativeEntryViews.swift",
    "NativeDemoViews.swift",
    "NativeDemoModels.swift",
    "NativeAccountDeletionView.swift",
    "NativeRootView.swift",
    "NativeLessonAudioViews.swift",
    "NativeLessonReadingContent.swift",
)


def native_source():
    return "\n".join((SOURCES / name).read_text(encoding="utf-8") for name in EXTRACTED_FILES)
