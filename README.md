### OpenAppUI

OpenAppUI is a cross‑platform Flutter client for interacting with an Open WebUI backend.

- **Platforms**: Android, iOS, macOS, Windows, Linux, Web
- **Tech**: Flutter, Riverpod, GoRouter, Material Design 3
- **Backend**: Any reachable Open WebUI server (self‑hosted or remote)

> Note: The `dev-submodules/` directory (in case you clone with submodules) (including `dev-submodules/open-webui`) is for development convenience only. It is not part of the application and is not required to build or run OpenAppUI.

## Affiliation

OpenAppUI is an independent project and is not affiliated with, endorsed by, or sponsored by the Open WebUI project or its maintainers. The projects are separate and unrelated entities. References to Open WebUI in this repository are solely for interoperability and descriptive purposes.

## Prerequisites

- Flutter (stable) with Dart SDK ≥ 3.7.2
- A running Open WebUI backend you can reach from your device/emulator

## Quick start

```bash
git clone https://github.com/sleepyyui/open-appui
cd open-appui
flutter pub get
flutter run
```

On first launch, set the backend Base URL in‑app when prompted (or via Settings). Example: `https://your-webui.example.com`.

## Build for a platform

- Android: `flutter build apk` or `flutter build appbundle`
- iOS: `flutter build ios` (requires Xcode setup)
- macOS: `flutter build macos`
- Windows: `flutter build windows`
- Linux: `flutter build linux`
- Web: `flutter build web`

Refer to Flutter’s platform setup guides as needed.

## Configuration

OpenAppUI stores the backend Base URL and session token securely on device. There are no required compile‑time flags; all configuration is done within the app. You can change the Base URL later in Settings.

## Development

- Use Material Design 3 components and theming.
- Run checks locally:
  - Analyze: `flutter analyze`
  - Tests: `flutter test`

See `CONTRIBUTING.md` for the full contribution guide.

## Contributing

We welcome issues and PRs! Please read:

- `CODE_OF_CONDUCT.md`
- `CONTRIBUTING.md`

## Security

Please do not file public issues for security matters. See `SECURITY.md` for private disclosure instructions.

## Acknowledgements

- [Open WebUI](https://github.com/open-webui/open-webui)
- Flutter and the Flutter community
