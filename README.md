# gopher-jobs

Link to Cover Letter Generator — paste a job URL and source material, then generate an ATS-optimized resume and cover letter with your preferred AI provider (OpenAI, Anthropic, or Gemini).

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **stable** (this repo targets Dart `^3.12.2`)
- For web: Chrome
- For iOS: Xcode + CocoaPods
- For Android: Android Studio / Android SDK

If Flutter is not on your `PATH`, a common local install is:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor
```

## Setup

```bash
cd /path/to/gopher-jobs
flutter pub get
```

## Run

### Web (Chrome)

```bash
flutter run -d chrome
```

On web, many job sites block browser fetches (CORS). Configure an optional **job fetch proxy URL** in Settings (`{proxy}?url={encodedJobUrl}` returning HTML).

### iOS Simulator

```bash
open -a Simulator
flutter run -d ios
```

### Android emulator / device

```bash
flutter devices
flutter run -d android
```

## Analyze & test

```bash
flutter analyze
flutter test
```

CI runs the same checks via [`.github/workflows/flutter.yml`](.github/workflows/flutter.yml).

## ATS output

Generated resumes and cover letters follow ATS structure rules (standard section headings, no tables, contact details, cover-letter length). Results shows soft ATS checks from generation. **Download ATS .txt** exports plain text suitable for pasting into applicant tracking systems (not DOCX/PDF).

## Privacy

Your **API token** and **job/source content** are sent to the AI provider you choose (OpenAI, Anthropic, or Gemini). If you set a fetch proxy, job URLs are requested through that proxy. Tokens are stored locally (secure storage / SharedPreferences); there is no Gopher Jobs backend.

## Project layout

| Path | Role |
| --- | --- |
| `lib/main.dart` / `lib/app.dart` | Entry + NavigationBar shell (Generate / Results / Settings) |
| `lib/core/` | Theme, constants, error types |
| `lib/domain/` | Contracts + Riverpod providers |
| `lib/data/` | Settings, job fetch, AI clients, generation orchestration |
| `lib/features/*/` | Generate, Results, Settings screens |
| `docs/agent-ownership.md` | Multi-agent write ownership (waves 0–3 complete) |

See [docs/agent-ownership.md](docs/agent-ownership.md) for which agent owns which paths.
