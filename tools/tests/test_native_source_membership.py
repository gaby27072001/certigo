import re
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET


APP = Path(__file__).resolve().parents[2] / "apps" / "apple" / "CertigoNative"
PROJECT = APP / "CertigoNative.xcodeproj" / "project.pbxproj"


def objects_of_type(project, kind):
    return {
        identifier: body
        for identifier, body in re.findall(
            r"^\t\t([A-F0-9]{24})(?: /\*.*?\*/)? = \{(.*?)\};",
            project,
            re.MULTILINE | re.DOTALL,
        )
        if re.search(rf"\bisa = {re.escape(kind)};", body)
    }


def references(body, field):
    value = re.search(rf"\b{field} = \((.*?)\);", body, re.DOTALL)
    if value is None:
        raise ValueError(f"Missing {field} list")
    return re.findall(r"\b[A-F0-9]{24}\b", value[1])


class NativeSourceMembershipTests(unittest.TestCase):
    def test_shared_profile_action_runs_the_release_app_target(self):
        scheme = ET.parse(
            APP / "CertigoNative.xcodeproj" / "xcshareddata" / "xcschemes"
            / "CertigoNative.xcscheme"
        ).getroot()
        profiles = scheme.findall("ProfileAction")
        self.assertEqual(len(profiles), 1)
        profile = profiles[0]
        self.assertEqual(profile.get("buildConfiguration"), "Release")
        runnables = profile.findall("BuildableProductRunnable")
        self.assertEqual(len(runnables), 1)
        self.assertEqual(runnables[0].get("runnableDebuggingMode"), "0")
        refs = runnables[0].findall("BuildableReference")
        self.assertEqual(len(refs), 1)
        reference = refs[0]
        self.assertEqual(reference.get("BuildableIdentifier"), "primary")
        self.assertEqual(reference.get("BuildableName"), "CertigoNative.app")
        self.assertEqual(reference.get("BlueprintName"), "CertigoNative")
        self.assertEqual(
            reference.get("ReferencedContainer"), "container:CertigoNative.xcodeproj"
        )
        targets = objects_of_type(PROJECT.read_text(encoding="utf-8"), "PBXNativeTarget")
        self.assertIn(reference.get("BlueprintIdentifier"), targets)
        launch = scheme.find("LaunchAction/BuildableProductRunnable/BuildableReference")
        self.assertIsNotNone(launch)
        self.assertEqual(reference.attrib, launch.attrib)

    def test_every_app_swift_file_is_in_the_target_sources_phase_and_group(self):
        project = PROJECT.read_text(encoding="utf-8")
        targets = objects_of_type(project, "PBXNativeTarget")
        sources_phases = objects_of_type(project, "PBXSourcesBuildPhase")
        groups = objects_of_type(project, "PBXGroup")
        build_files = objects_of_type(project, "PBXBuildFile")
        file_refs = objects_of_type(project, "PBXFileReference")

        app_targets = [
            body for body in targets.values()
            if 'productType = "com.apple.product-type.application";' in body
        ]
        self.assertEqual(len(app_targets), 1)
        target = app_targets[0]
        target_sources = set(references(target, "buildPhases")) & sources_phases.keys()
        self.assertEqual(len(target_sources), 1)
        phase = sources_phases[target_sources.pop()]
        source_build_ids = references(phase, "files")
        self.assertEqual(len(source_build_ids), len(set(source_build_ids)))

        compiled_refs = []
        for identifier in source_build_ids:
            self.assertIn(identifier, build_files)
            file_ref = re.search(r"\bfileRef = ([A-F0-9]{24})\b", build_files[identifier])
            self.assertIsNotNone(file_ref, identifier)
            compiled_refs.append(file_ref[1])
        self.assertEqual(len(compiled_refs), len(set(compiled_refs)))

        source_groups = [
            body for body in groups.values() if re.search(r"\bpath = Sources;", body)
        ]
        self.assertEqual(len(source_groups), 1)
        grouped_refs = references(source_groups[0], "children")
        self.assertEqual(len(grouped_refs), len(set(grouped_refs)))
        self.assertEqual(set(grouped_refs), set(compiled_refs))

        compiled_paths = []
        for identifier in compiled_refs:
            self.assertIn(identifier, file_refs)
            body = file_refs[identifier]
            self.assertIn("lastKnownFileType = sourcecode.swift;", body)
            self.assertIn('sourceTree = "<group>";', body)
            path = re.search(r'\bpath = "?([^";]+)"?;', body)
            self.assertIsNotNone(path, identifier)
            compiled_paths.append(path[1])
        self.assertEqual(len(compiled_paths), len(set(compiled_paths)))
        self.assertEqual(
            set(compiled_paths),
            {
                path.relative_to(APP / "Sources").as_posix()
                for path in (APP / "Sources").rglob("*.swift")
            },
        )

    def test_widget_extension_compiles_shared_presentation_and_is_embedded_in_app(self):
        project = PROJECT.read_text(encoding="utf-8")
        targets = objects_of_type(project, "PBXNativeTarget")
        self.assertEqual(len(targets), 2)
        app = targets["000000000000000000000050"]
        widget_id = "0000000000000000000000BC"
        widget = targets[widget_id]
        self.assertIn('productType = "com.apple.product-type.app-extension";', widget)
        phases = objects_of_type(project, "PBXSourcesBuildPhase")
        source_ids = set(references(widget, "buildPhases")) & phases.keys()
        self.assertEqual(len(source_ids), 1)
        build_files = objects_of_type(project, "PBXBuildFile")
        file_refs = objects_of_type(project, "PBXFileReference")
        compiled_refs = []
        for identifier in references(phases[source_ids.pop()], "files"):
            reference = re.search(r"\bfileRef = ([A-F0-9]{24})\b", build_files[identifier])
            self.assertIsNotNone(reference)
            compiled_refs.append(reference[1])
        self.assertEqual(len(compiled_refs), len(set(compiled_refs)))
        self.assertEqual(
            {re.search(r'\bpath = "?([^";]+)"?;', file_refs[ref])[1]
             for ref in compiled_refs},
            {"CertigoWidgetPresentation.swift", "CertigoWidgetExtension.swift"},
        )
        groups = objects_of_type(project, "PBXGroup")
        widget_groups = [
            body for body in groups.values() if re.search(r"\bpath = WidgetExtension;", body)
        ]
        self.assertEqual(len(widget_groups), 1)
        self.assertIn("0000000000000000000000B3", references(widget_groups[0], "children"))
        dependencies = objects_of_type(project, "PBXTargetDependency")
        self.assertTrue(any(
            f"target = {widget_id}" in dependencies[identifier]
            for identifier in references(app, "dependencies")
        ))
        copies = objects_of_type(project, "PBXCopyFilesBuildPhase")
        embed_phases = set(references(app, "buildPhases")) & copies.keys()
        self.assertEqual(len(embed_phases), 1)
        embed = copies[embed_phases.pop()]
        self.assertIn("dstSubfolderSpec = 13;", embed)
        self.assertTrue(any(
            "fileRef = 0000000000000000000000B5" in build_files[identifier]
            for identifier in references(embed, "files")
        ))


if __name__ == "__main__":
    unittest.main()
