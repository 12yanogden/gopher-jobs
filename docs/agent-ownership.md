# Agent ownership

Write ownership by agent and wave. Agents must not edit files outside their column unless a gate explicitly transfers ownership.

| Agent | Waves | Owns (write) |
| --- | --- | --- |
| Orchestrator | 0, gates | `lib/main.dart`, `lib/app.dart`, `lib/core/**`, `lib/domain/**`, `pubspec.yaml`, `analysis_options.yaml`, platform folders (`web/`, `ios/`, `android/`), README scaffold / run docs, `docs/agent-ownership.md` |
| Settings | 1 | `lib/data/settings/**`, `lib/features/settings/**`, matching tests |
| Fetch | 1 | `lib/data/job_fetch/**`, `test/data/job_fetch/**`, `test/fixtures/**` |
| AI | 1 | `lib/data/ai/**`, `lib/prompts/**`, matching tests |
| GenerateUI | 1 | `lib/features/generate/**`, matching tests |
| Orchestrate | 2 | `lib/data/generation/**`, `lib/domain/providers.dart` wiring, matching tests |
| Results | 2 | `lib/features/results/**`, matching tests |
| Harden | 3 | Repo-wide polish after feature freeze: CI, analyze/test green, Settings↔domain seam, Generate token gate, privacy note, responsive/a11y basics, error copy |

## Wave status

| Wave | Status |
| --- | --- |
| 0 Orchestrator scaffold | Complete |
| 1 Settings / Fetch / AI / GenerateUI | Complete |
| 2 Orchestrate + Results | Complete |
| 3 Harden | Complete (CI, seam, token gate, privacy, polish) |

## ATS Scanner Optimization (Wave 0+)

| Agent | Wave | Owns (write) |
| --- | --- | --- |
| Orchestrator | 0 | `lib/domain/generation_artifacts.dart` (+ compile-only call-site fixes); this ownership note |
| AI | 1 | Validator / plain-text helpers under `lib/data/ai/**`, prompts under `lib/prompts/**` (populate `atsWarnings`) |
| Results | 1+ | `lib/features/results/**` (surface `atsWarnings`) |
| Harden | 3 | Repo-wide polish: analyze/test green, README ATS note, mark waves complete |

| Wave | Status |
| --- | --- |
| 0 Orchestrator (`atsWarnings` field) | Complete |
| 1 AI (prompts, `AtsStructureValidator`, `AtsPlainText`, parser wiring) | Complete |
| 1+ Results (ATS panel, Download ATS .txt) | Complete |
| 3 Harden (analyze/test, docs) | Complete |

Wave 0 only adds the field API: `GenerationArtifacts.atsWarnings` defaults to `const []`. Do not invent validators, prompt changes, or Results UI in Wave 0.

### `GenerationArtifacts` constructor (Wave 0 exit)

```dart
const GenerationArtifacts({
  required this.resumeMarkdown,
  required this.coverLetterMarkdown,
  this.atsWarnings = const [],
});
```

- `resumeMarkdown` / `coverLetterMarkdown`: required `String`
- `atsWarnings`: `List<String>`, default `const []` — soft ATS structure warnings populated by `AtsStructureValidator` after parse

## Frozen contracts (Wave 0)

Wave 1+ agents consume these types; do not rename without an Orchestrator gate:

| Type | Path |
| --- | --- |
| `AiProviderKind` | `lib/domain/ai_provider_kind.dart` |
| `AppSettings` | `lib/domain/app_settings.dart` |
| `JobPosting` | `lib/domain/job_posting.dart` |
| `GenerationRequest` | `lib/domain/generation_request.dart` |
| `GenerationArtifacts` | `lib/domain/generation_artifacts.dart` |
| `SettingsRepository` | `lib/domain/settings_repository.dart` |
| `JobFetchService` | `lib/domain/job_fetch_service.dart` |
| `AiClient` | `lib/domain/ai_client.dart` |
| `GenerationService` | `lib/domain/generation_service.dart` |
| Providers | `lib/domain/providers.dart` |

Barrel export: `lib/domain/domain.dart`.

## Screen overwrite convention

Placeholder screens at stable paths / class names — overwrite in place; keep `GenerateScreen`, `ResultsScreen`, `SettingsScreen` so `lib/app.dart` imports stay stable:

- `lib/features/generate/generate_screen.dart` → GenerateUI (Wave 1)
- `lib/features/results/results_screen.dart` → Results (Wave 2)
- `lib/features/settings/settings_screen.dart` → Settings (Wave 1)

## Provider wiring

`lib/domain/providers.dart` wires real Settings / Fetch / AI / Generation implementations.

Settings UI keeps `settingsRepositoryLocalProvider` / `appSettingsLocalProvider` as aliases that default to the domain providers. On Save, Settings invalidates both local and `appSettingsProvider` so Generate sees the new token without restart.
