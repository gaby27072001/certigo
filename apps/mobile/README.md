# Microlingo — mobile app

Flutter client for Microlingo, the bite-sized learning app for Microsoft
certifications (AZ-900 and beyond). Built on the shared `prism_ui` design
system and the `core` / `cortex` / `data` packages in this monorepo.

## Run

From the repo root, install dependencies with Melos, then launch from this
directory:

```bash
flutter pub get
flutter run            # a connected device / emulator
flutter run -d edge    # or any desktop browser for a quick preview
```

## Checks

These mirror the `ci-mobile` workflow:

```bash
dart format --line-length 100 apps packages
flutter analyze
flutter test
```

Supported platforms: iOS, Android, and web (the `web/` folder enables the
browser preview used during development).
