### Contributing to OpenAppUI

Thank you for considering a contribution! This guide explains how to propose changes and report issues.

## Code of Conduct

By participating, you agree to abide by the rules in `CODE_OF_CONDUCT.md`.

## Project scope

- This repository contains the Flutter client app.
- The `dev-submodules/` folder is for local development only and is not part of the shipped app.

## Ways to contribute

- File issues (bug reports or feature requests)
- Improve documentation
- Submit pull requests

## Getting started

1. Install Flutter (stable) and set up your platform toolchains.
2. Clone the repo and install dependencies:
   ```bash
   git clone https://github.com/sleepyyui/open-appui
   cd open-appui
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Development standards

- Use Material Design 3.
- Keep code readable and well‑named. Prefer early returns and clear error handling.
- Follow the repository `analysis_options.yaml` lints. Run `flutter analyze` before committing.
- Add unit/widget tests when feasible. Run `flutter test`.

## Pull requests

1. Fork the repo and create a feature branch.
2. Make focused changes with clear commits.
3. Ensure the app builds and tests pass on all supported platforms you touched.
4. Open a PR with:
   - A clear description of the problem and solution
   - Screenshots for UI changes
   - Notes on testing and potential impacts

## Issue reports

Please include:

- Expected vs actual behavior
- Steps to reproduce
- Environment details (platform, OS version, Flutter/Dart versions)
- Logs or screenshots when helpful

## Commit message style

Not required, but conventional commits are appreciated, e.g. `feat:`, `fix:`, `docs:`.

## Licensing

By contributing, you agree that your contributions will be licensed under the repository’s license.


