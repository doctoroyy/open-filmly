# Technical Plan: Filmly Command Palette & Conversation Library

**Status:** Proposed redesign

**Scope:** macOS-first implementation, preserving the existing intelligence
database boundary and Media Agent safety model

## Objective

Replace the temporary Agent transcript with a durable local conversation
library, while narrowing `Cmd/Ctrl+K` back to its intended role: immediate,
keyboard-first navigation through real media and scene results.

The deliverable is not a new chat feature. It is a clear split between:

```text
Command Palette: local query → result list → open destination
Conversation: persisted context → grounded answer / plan → review and execute
```

## Current-state findings

| Finding | Consequence | Redesign response |
| --- | --- | --- |
| `MediaAgentPage` keeps `ChatUiMessage` in widget memory. | Messages disappear after route changes or app restart. | Persist conversations and messages in the intelligence database. |
| `ConversationalAgentEngine` owns one in-memory `_history`. | Context can leak between UI sessions and cannot be reopened deterministically. | Make the engine request-scoped; pass bounded context for one conversation. |
| `agent_runs` persists plans but has no conversation link. | A historical plan cannot be discovered from its original discussion. | Add nullable `conversationId` and store `planId` on the model message. |
| The full Agent is the only durable-looking surface. | A quick `Cmd+K` task feels like a chat detour. | Keep the palette result-only; explicit handoff starts a conversation. |
| The thread has a wide canvas but no local navigation. | It looks sparse and cannot support returning to work. | Add a 248 px conversation rail and conditional detail drawer. |

## Architecture

```text
                         ┌────────────────────────────┐
Cmd/Ctrl+K ─────────────▶│ MediaCommandPalette         │
                         │ local title / FTS / semantic│
                         └─────────────┬──────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              ▼                        ▼                        ▼
       media detail route       player at timestamp       start conversation
                                                               │
                                                               ▼
                         ┌──────────────────────────────────────────────┐
                         │ ConversationWorkspaceController               │
                         │ active conversation + UI state + lifecycle    │
                         └───────┬───────────────────────┬──────────────┘
                                 │                       │
                    ┌────────────▼───────────┐  ┌────────▼──────────────┐
                    │ AgentConversationRepo   │  │ Request-scoped engine │
                    │ conversations / messages│  │ provider + local tools│
                    └────────────┬───────────┘  └────────┬──────────────┘
                                 │                       │
                                 ▼                       ▼
                         IntelligenceDatabase      AgentRunRepository
                         (independent SQLite)      (plans / execution)
```

No conversation data is added to the core media database. Scanning, playback,
and existing import/export flows remain operational when the intelligence
database is absent, damaged, or cleared.

## Data model

### Schema migration: v3 → v4

Extend `lib/data/intelligence/intelligence_tables.dart` and
`lib/data/intelligence/intelligence_database.dart` with the following tables.

### `agent_conversations`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID / timestamp-safe local ID |
| `title` | text | Derived locally from the first user message; user editable |
| `preview` | text | Last visible message summary for the rail |
| `pinnedAt` | text nullable | Sort pinned conversations first |
| `archivedAt` | text nullable | Hidden from default rail |
| `createdAt` | text | ISO-8601 |
| `updatedAt` | text | Updated transactionally with its last message |

### `agent_messages`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | Local message ID |
| `conversationId` | text | Indexed with `sequence` |
| `sequence` | integer | Strict local ordering within a conversation |
| `role` | text | `user`, `model`, or `system` display record |
| `content` | text | Only visible, non-secret content |
| `toolsJson` | text nullable | Compact list of tool names, never raw credentials |
| `planId` | text nullable | Points to the existing `agent_runs.id` |
| `status` | text | `complete`, `failed`, or `cancelled` |
| `createdAt` | text | ISO-8601 |

### Existing `agent_runs`

Add nullable `conversationId`. Existing runs remain valid and ungrouped. New
plans created in a conversation set it in the same transaction that writes the
model message. A plan must still be usable without a conversation for existing
service callers and tests.

### Indexes and deletion rules

```sql
CREATE INDEX agent_messages_conversation_sequence_idx
  ON agent_messages(conversation_id, sequence);
CREATE INDEX agent_conversations_updated_idx
  ON agent_conversations(archived_at, pinned_at, updated_at DESC);
CREATE INDEX agent_runs_conversation_idx
  ON agent_runs(conversation_id, updated_at DESC);
```

Deleting a conversation deletes only its `agent_messages` and
`agent_conversations` rows. It explicitly does **not** delete `agent_runs`,
smart collections, subtitle artifacts, media rows, or watch events. Its plan
link becomes null or remains as an orphaned historical run according to the
repository’s migration-safe deletion method.

## Repositories and services

### New files

| File | Responsibility |
| --- | --- |
| `lib/data/intelligence/agent_conversation_repository.dart` | CRUD, list grouping, message ordering, archive/delete transactions |
| `lib/services/intelligence/agent_conversation_service.dart` | Start/resume/send lifecycle, title and preview derivation, context bounding |
| `lib/providers/agent_conversation_providers.dart` | AsyncNotifier state for rail, active thread, and mutations |
| `lib/features/intelligence/agent_conversation_rail.dart` | Persistent desktop history list |
| `lib/features/intelligence/agent_thread_view.dart` | Readable message thread and evidence rows |
| `lib/features/intelligence/agent_composer.dart` | Composer and keyboard send behaviour |
| `lib/features/intelligence/agent_detail_drawer.dart` | Conditional plan/source inspector |

The existing `MediaAgentPage` becomes a thin conversation workspace shell or
is renamed to `AgentConversationPage` after routing is migrated. Do not leave
two independently stateful Agent pages.

### Request-scoped provider context

Refactor `ConversationalAgentEngine` so it does not retain `_history`. The new
method receives one conversation context and returns one completed turn:

```dart
Future<ConversationalTurnResult> sendUserMessage({
  required String userPrompt,
  required List<AgentModelContextMessage> context,
  required String conversationId,
});
```

`AgentConversationService.send()` performs this sequence:

```text
create conversation only if necessary
  → insert user message and update rail preview
  → build bounded model context from selected conversation only
  → call request-scoped engine
  → persist model reply / tool labels / optional plan link
  → update conversation title and rail preview
  → return the new durable thread state
```

The model receives the last 12 complete visible turns (or a byte/token budget
equivalent) from the active conversation only. A later summarisation mechanism
may compress older turns, but the first release must never mix contexts from
two conversations.

On a provider failure, the user message stays in history. The service writes a
local failed system record with a retry affordance; it does not create an
invented model response.

### Local title and privacy rules

- Use the first user message, whitespace-normalised and truncated to 36
  grapheme clusters, as the initial title. Do not use a cloud call to create a
  title.
- Preview uses the final visible reply or user prompt, truncated locally.
- Never persist API keys, provider HTTP payloads, raw tool response JSON, or
  hidden system instructions in messages.
- Command palette queries remain in widget state unless explicitly handed off
  to a conversation.

## UI implementation plan

### Phase 1 — Durable conversation foundation

1. Add the v4 migration and generated Drift code.
2. Implement domain models and `AgentConversationRepository`.
3. Refactor the conversational engine to request-scoped context.
4. Implement `AgentConversationService` and Riverpod state.
5. Keep the current page rendering messages from the repository before any
   visual redesign; this isolates data correctness from layout work.

**Exit criteria:** Create two conversations, restart the app, reopen either
one, and prove that its messages and plan state are restored without mixing
context.

### Phase 2 — Conversation workspace UI

1. Replace the fixed 900 px single-column layout with the desktop workspace:
   global shell + 248 px conversation rail + thread column.
2. Make “New conversation” unsaved until the first message.
3. Add time grouping, active row state, overflow actions, empty state, and
   responsive rail drawer.
4. Move plan preview into an inline card and detail drawer.
5. Remove the permanent “Media Agent” title and the oversized welcome copy.

**Exit criteria:** At a 1200 px-wide macOS app window, a person can see prior
conversations, select one, send a message, and inspect a plan without a large
empty canvas or an overlapping composer.

### Phase 3 — Strict command palette

1. Reduce the palette’s empty state to a focused input plus compact local
   recents; remove “Open Media Agent” as a primary card.
2. Group real results as Best match, Moments, and Ask.
3. Add `Shift+Enter` for explicit conversation handoff and preserve the exact
   query on the new thread.
4. Keep `Enter` deterministic: open the highlighted title or play the
   highlighted timestamp.
5. Use the existing semantic search service. Search does not require a cloud
   Agent provider.

**Exit criteria:** A real indexed scene can be opened by keyboard directly
from `Cmd+K`; an action request cannot execute from the palette.

### Phase 4 — Plan history and recovery

1. Attach newly created `agent_runs` to their conversation ID.
2. Resolve plan state from `AgentRunRepository` each time a historical thread
   is opened; do not trust a stale message snapshot.
3. Render `planned`, `confirmed`, `running`, `succeeded`, `failed`, and
   `undone` states exactly as the existing safety workflow requires.
4. Archive/delete conversation rules must never change existing Agent run
   records or core library data.

**Exit criteria:** A plan generated before app restart can be reopened,
reviewed, confirmed, executed, or inspected in its originating conversation.

## Routing and keyboard integration

| Route / trigger | Target |
| --- | --- |
| `/agent` | New unsaved workspace or last active conversation |
| `/agent/:conversationId` | Specific persisted conversation |
| `/agent?prompt=…` | New conversation, sends only after page initialises |
| `Cmd/Ctrl+K` | `MediaCommandPalette.show()` from the root shell |
| `Shift+Enter` inside palette | `/agent?prompt=…` |
| `Cmd/Ctrl+F` | Existing page-local search, unchanged |

The root shell owns global shortcut registration. A text field consumes normal
typing; the shortcut handler must avoid stealing `Cmd/Ctrl+K` while an
accessibility modal or system dialog is active.

## Tests and verification

### Automated tests

| Test | Coverage |
| --- | --- |
| `test/agent_conversation_repository_test.dart` | CRUD, group ordering, archive/delete, sequence ordering |
| `test/intelligence_database_migration_test.dart` | v3 → v4 upgrade preserves assets, jobs, runs, and smart collections |
| `test/agent_conversation_service_test.dart` | new/resume/send, bounded context, provider failure persistence |
| `test/conversational_agent_engine_test.dart` | no cross-conversation history and correct tool/plan result mapping |
| `test/media_command_palette_test.dart` | keyboard selection, `Enter` direct result, `Shift+Enter` handoff, no query persistence |
| `test/agent_conversation_page_test.dart` | rail selection, new draft, responsive drawer, restored messages |
| `test/agent_plan_history_test.dart` | reopen plan and render its current execution state |

### Real macOS verification

The release gate includes a non-mocked, opt-in run against the configured
provider and existing local media database:

1. Launch the installed macOS release build with the existing data container.
2. Open `Cmd+K`, search an actual title and an indexed scene, then navigate by
   keyboard to the real detail/player destination.
3. Hand off a typed request to a new conversation.
4. Send it to the configured provider, confirm the visible reply and any
   returned local evidence.
5. Navigate away, quit and relaunch, then select the conversation from the
   rail and compare all message text and plan state.
6. Capture the actual application screenshot and report the database counts
   without exposing configured credentials.

Unit/widget tests may use controlled fakes for determinism; the acceptance
evidence above must use the real configured provider and the real local
library, not a mocked screenshot or data source.

## Data safety and backwards compatibility

- The intelligence database remains a separate file. Removing it removes only
  conversations, indexes, and Agent metadata; media rows and playback progress
  remain intact.
- Existing `agent_runs` rows without `conversationId` remain listable in the
  existing run history.
- No core media IDs, episode IDs, import/export formats, or bundle identifiers
  are modified.
- The app continues to browse and play media when no provider is configured.
- Conversation deletion must use an explicit confirmation in the UI and must
  not delete agent-run, collection, subtitle, or media records.

## Definition of done

1. `Cmd/Ctrl+K` is visibly a command palette and opens actual results with one
   keyboard action.
2. The full conversation workspace has a durable, usable conversation list.
3. Conversations survive routing and application relaunch.
4. Provider context is limited to the selected conversation and cannot leak
   from another conversation.
5. Action plans remain reviewable, safe, and linked to their origin.
6. The redesigned macOS release build passes automated tests, analysis, and a
   real provider/local-library smoke test with screenshot evidence.
