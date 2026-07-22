# Technical Plan: Media Command Center

**Status:** In progress

**Design:** `docs/design-media-command-center.md`
**Last updated:** 2026-07-22

## Scope

This plan turns the desktop `Cmd/Ctrl+K` entry point into a dependable command
center for a personal media library. It is intentionally narrower than the
long-term Media Agent roadmap: the first goal is retrieval with a direct,
safe outcome; the second is a clear handoff to planning work.

The implementation must keep the existing core media database and playback
progress model intact. Intelligence data remains in the independent
intelligence database. A missing worker, embedding model, or cloud provider
must only reduce optional capabilities.

## Current baseline

| Capability | Current state | Notes |
| --- | --- | --- |
| Shell shortcut | Implemented | `Cmd/Ctrl+K` opens `MediaCommandPalette` |
| Local title search | Implemented | Uses `SemanticSearchService` and core media rows |
| Transcript / scene retrieval | Implemented when indexes exist | Uses FTS, scene index, optional embeddings |
| Direct scene playback | Implemented | Reuses `openPlayer` and existing start position args |
| Media navigation | Implemented | Reuses `mediaDetailLocation` |
| Exact-title precedence | Implemented | Avoids filename-only legacy metadata becoming top result |
| Full Agent page | Implemented | Multi-turn UI with plan / confirm / execute boundaries |
| Keyboard result selection | Implemented in this iteration | Arrow navigation, Enter activation, and real toggle behavior |
| Visual foundation | Implemented in this iteration | Selected-state treatment, keyboard help, and palette motion follow the design spec |
| Agent workbench visual refinement | Implemented in this iteration | Editorial response blocks, provenance line, decision-first plan cards, and anchored composer |
| Unified intent / command results | Next | Make handoffs and safe reports explicit, not ad-hoc rows |
| Localization | Next | Current new strings are source-locale English but not localized |
| Mobile command surface | Deferred | Requires a touch-specific design |

## Architecture

```text
AppShell shortcut
  → MediaCommandPalette
      → CommandPaletteController (query lifecycle and active row)
          → CommandSearchService
              → SemanticSearchService
                  → core media DB
                  → intelligence FTS / scene index
                  → optional embedding provider
          → CommandIntentResolver
              → Agent handoff or read-only report descriptor
      → existing media detail route / existing player / existing Agent route
```

The first implementation can keep the controller inside the palette state
while behavior is small. Once result groups and query reuse are introduced,
extract it into a testable service; do not put ranking policy in widgets.

## UI implementation contract

The visual source of truth is the `Visual design` section of
`docs/design-media-command-center.md`. The first production pass uses the
existing `FilmlyPalette` values rather than creating a parallel theme:

- `MediaCommandPalette` owns the 720 px desktop overlay, its 20 px radius,
  compact 64 px input bar, result-state tints, and keyboard footer.
- `MediaAgentPage` owns a 900 px reading measure, plain editorial message
  blocks, and the anchored 56 px composer work surface.
- `FilmlyGlassPanel` is reserved for plans and other decision objects. It is
  not the default wrapper for every paragraph of an Agent response.
- Animation durations are constrained to the document's 120/160/180 ms
  values. Do not add bouncing, position shifts, or decorative gradients.
- Any new visual state needs a stable widget key and a widget or live UI test
  before it is considered complete.

## Data contracts

### Existing retrieval result

`AskFilmlyResult` already represents a verified title or timestamped scene:

```dart
class AskFilmlyResult {
  String title;
  String snippet;
  String reason;
  double score;
  String? mediaId;
  String? uri;
  int? startMs;
  int? endMs;
  bool get isScene;
}
```

It remains the source-backed retrieval contract. No generated timestamp may be
written into this type.

### New command result wrapper

Introduce an immutable presentation-layer wrapper once the palette needs more
than search rows:

```dart
sealed class CommandPaletteItem {
  const CommandPaletteItem();
  CommandResultKind get kind;
  String get title;
  String get subtitle;
  CommandActivation get activation;
}
```

Variants:

- `CommandMediaItem(AskFilmlyResult result)`
- `CommandSceneItem(AskFilmlyResult result)`
- `CommandAgentHandoffItem(String prompt, AgentIntent intent)`
- `CommandReadOnlyReportItem(ReportDescriptor report)`

`CommandActivation` is a description of navigation or a planned action, not a
callable capable of mutating files. The widget activates it through an
explicit dispatcher.

## Delivery phases

### Phase 1 — Keyboard-first retrieval and visual foundation *(implemented in this iteration)*

**Goal:** make the existing palette satisfy the basic command-center contract.

Changes:

- Add an active row index in `lib/widgets/media_command_palette.dart`.
- Handle `ArrowUp`, `ArrowDown`, `Enter`, `Esc`, `Cmd+K`, and `Ctrl+K` from
  the focused field. `Cmd/Ctrl+K` must close the palette when it is already
  open.
- Draw selected rows with semantic selected state and a subtle accent surface.
- Make `Enter` open the selected result; without results it opens Ask Filmly
  with the typed query.
- Reset selection when the query changes and clamp it when async results are
  replaced.
- Keep direct player and route transitions behind the existing dismissal
  helper so a popup barrier never remains over the destination.
- Apply the visual design tokens for selected results, keycaps, spacing, and
  transitions without adding a second palette-specific color system.

Files:

- `lib/widgets/media_command_palette.dart`
- `test/media_command_palette_test.dart`
- `test/media_command_palette_live_ui_test.dart`

Acceptance:

- Widget tests prove Arrow navigation and Enter activate the expected row.
- A live macOS test proves an exact-title result opens its real detail page and
  leaves no palette visible.

### Phase 1B — Agent workbench refinement *(implemented in this iteration)*

**Goal:** make the full Agent feel like a calm decision workspace, not a
messenger clone.

Changes:

- Replace opposing rounded chat bubbles in
  `lib/features/intelligence/media_agent_page.dart` with labelled editorial
  blocks. User input uses a thin rule and muted `YOU` label; Agent output uses
  `OPEN FILMLY` and plain canvas text.
- Summarize tool use as a small provenance line instead of emoji chips or raw
  function names as the dominant visual element.
- Reserve card treatment for `MediaAgentPlan`: scope, preview count,
  confirmation state, and the one available primary action must remain visible
  without reading the whole conversation.
- Refine the empty state and composer to match the 900 px reading measure and
  the dimensions in the UI design.
- Preserve existing plan/confirm/execute/undo behavior and their stable keys.

Files:

- `lib/features/intelligence/media_agent_page.dart`
- `test/media_agent_page_test.dart` (new)
- `test/agent_live_ui_test.dart`

Acceptance:

- Empty Agent state contains the documented heading, examples, and anchored
  composer.
- A plan appears as a decision card with preview count and no hidden execute
  action.
- Existing safe-plan live flow can still find the confirmation and execution
  controls. Provider failures must appear as a compact, readable error state.

### Phase 2 — Query lifecycle and deterministic ranking

**Goal:** results stay responsive and explainable as the library grows.

Changes:

- Add a 150–250 ms debounce before a new query becomes observable by the
  provider; cancellation or stale-result suppression is mandatory.
- Extract ranking policy from `SemanticSearchService` into a small testable
  scorer if it grows beyond title/metadata/FTS precedence.
- Dedupe the same title/scene hit while preserving the strongest evidence.
- Group results by `Media`, `Scenes`, and `Library` only when each group has
  enough useful content; avoid empty headers.
- Maintain an explicit local-only availability state when embeddings or an AI
  provider cannot run.

Files:

- `lib/services/intelligence/semantic_search_service.dart`
- `lib/services/intelligence/command_search_service.dart` (new)
- `lib/providers/intelligence_providers.dart`
- `lib/widgets/media_command_palette.dart`
- `test/semantic_search_service_test.dart`
- `test/command_search_service_test.dart` (new)

Acceptance:

- Exact titles outrank any filename-only result.
- The same asset/timestamp does not appear twice from FTS and embedding paths.
- FTS-only search remains usable with no provider configuration.

### Phase 3 — Intent recognition and Agent handoff

**Goal:** make the palette useful for library work without turning it into a
chat window.

Changes:

- Add a deterministic local `CommandIntentResolver` for known safe intents:
  duplicates, missing subtitles, low quality, smart collection, library
  health, and unwatched media.
- Show a dedicated “Continue in Media Agent” row with the original prompt and
  a plain-language explanation of what happens next.
- Resolve read-only reports through the existing repository and Agent planning
  services; show freshness and scope.
- Keep ambiguous prompts as Ask Filmly retrieval, not as speculative tool
  calls.

Files:

- `lib/services/intelligence/command_intent_resolver.dart` (new)
- `lib/services/intelligence/media_agent_service.dart`
- `lib/services/intelligence/agent_planner.dart`
- `lib/core/router/app_router.dart`
- `lib/widgets/media_command_palette.dart`
- `test/command_intent_resolver_test.dart` (new)

Acceptance:

- “Find duplicate files” opens an Agent plan, never begins scanning or file
  mutation from the palette.
- “Show library health” is explicitly read-only.
- An unrecognized prompt never claims an action was performed.

### Phase 4 — Localization, accessibility, and mobile design

**Goal:** make the command-center model shippable across user-facing clients.

Changes:

- Move strings to the app localization mechanism; keep English as source and
  ship Simplified Chinese at the same time.
- Add semantics labels, selected semantics, focus restoration, and high
  contrast checks.
- Build a mobile bottom-sheet counterpart with the same command result
  contract, without desktop keyboard hints.
- Add responsive screenshots for a desktop width and a phone width.

Acceptance:

- Keyboard-only desktop flow is complete.
- VoiceOver / TalkBack exposes result type, evidence, and primary action.
- Mobile targets have at least 44 pt touch size.

## Tests and verification

| Layer | Required verification |
| --- | --- |
| Unit | ranking, dedupe, intent resolver, activation dispatcher |
| Widget | query reset, selection, Enter/Esc/toggle, no-result fallback, error state |
| Integration | palette → media detail; palette → player at timestamp; palette → Agent prompt |
| Live macOS | connect to the running debug app and its real configured library; no mock data |
| Regression | `flutter analyze`, targeted tests, existing playback / database migration tests |

The live test must not read or print provider API keys. It may use a pre-existing
title in the local library and should save screenshots only under `/tmp`.

## Rollout and compatibility

- Feature-gate the command center behind the existing intelligence capability
  check until Phase 1 is stable.
- Let desktop users continue to use title search through `Cmd/Ctrl+F`.
- Do not migrate or rewrite `media.id`, `episodes.id`, core media rows, or
  playback progress.
- Do not persist raw queries by default. If local history is introduced later,
  make it opt-in and deletable.
- Keep API keys in the system credential store; never in a plan, command
  result, log, export, or database backup.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Stale async queries reorder the list | query token / debounce and stale-result suppression |
| Wrong top result causes wrong playback | explicit-title scoring, reason labels, keyboard selection instead of blind auto-play |
| AI provider failure breaks basic search | local metadata + FTS remain the default retrieval path |
| Agent request feels like a hidden operation | explicit handoff row, preview, confirmation, no mutations in palette |
| Desktop-first UI leaks to mobile | shared result contract, independent mobile surface |

## Definition of done for this iteration

1. Phase 1 is implemented and covered by widget and real macOS tests.
2. The design document's keyboard, direct-result, and safety rules are
   reflected in the shipped palette.
3. `flutter analyze` and all targeted tests pass.
4. The implementation remains compatible with a library that has no AI
   provider, no embeddings, and no transcripts.

Phases 2–4 remain planned work and should be implemented in separate reviewable
changes rather than folded into the first interaction pass.
