import re
import unittest
from pathlib import Path


APP = Path(__file__).resolve().parents[2] / "apps" / "apple" / "CertigoNative"
PROJECT = APP / "CertigoNative.xcodeproj" / "project.pbxproj"


def objects_of_type(project, kind):
    section = project.split(f"/* Begin {kind} section */", 1)[1].split(
        f"/* End {kind} section */", 1
    )[0]
    return dict(
        re.findall(
            r"^\t\t([A-F0-9]{24})(?: /\*.*?\*/)? = \{(.*?)\};",
            section,
            re.MULTILINE | re.DOTALL,
        )
    )


def references(body, field):
    value = re.search(rf"\b{field} = \((.*?)\);", body, re.DOTALL)
    if value is None:
        raise ValueError(f"Missing {field} list")
    return re.findall(r"\b[A-F0-9]{24}\b", value[1])


class NativeSourceMembershipTests(unittest.TestCase):
    def test_every_app_swift_file_is_in_the_target_sources_phase_and_group(self):
        project = PROJECT.read_text(encoding="utf-8")
        targets = objects_of_type(project, "PBXNativeTarget")
        sources_phases = objects_of_type(project, "PBXSourcesBuildPhase")
        groups = objects_of_type(project, "PBXGroup")
        build_files = objects_of_type(project, "PBXBuildFile")
        file_refs = objects_of_type(project, "PBXFileReference")

        self.assertEqual(len(targets), 1)
        target = next(iter(targets.values()))
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


if __name__ == "__main__":
    unittest.main()
