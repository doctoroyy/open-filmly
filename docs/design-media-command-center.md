# Design: Media Command Center

**Status:** Active — Phases 1 and 1B implemented; later phases proposed

**Owner:** Open Filmly

**Last updated:** 2026-07-22
**Related:** `docs/plan-media-command-center.md`

## Summary

Open Filmly is building a personal media OS, not a player with an AI chat box
attached. The Media Command Center is the fastest way to interact with that
OS on desktop: press `Cmd+K` (or `Ctrl+K`), describe a title, line, scene,
person, mood, or library task, then act on a real result immediately.

The command center is deliberately distinct from the full **Media Agent**:

| Surface | Best for | Primary outcome |
| --- | --- | --- |
| Command Center | One short intent, one immediate destination | Open a title or play a scene |
| Ask Filmly | Inspecting and comparing search results | Find the right moment with context |
| Media Agent | Multi-turn questions and changes to the library | Produce a reviewable plan, then require confirmation |

This keeps routine retrieval instant while preserving a capable workspace for
work that needs context, preview, confirmation, or a conversation.

## Problem

Today, a library search is mostly a title lookup. It does not serve the
questions people actually have about a private library:

- “Find the scene where they meet at the airport.”
- “Open the first episode of *Stranger Things*.”
- “Which files have no subtitles?”
- “Help me make a quiet science-fiction collection.”

Putting every one of those requests into a full-screen chat page is slow and
visually heavy. Returning only titles also loses the distinctive value of an
intelligent media library: a result can carry a source, a timestamp, and a
direct path to playback.

## Goals

1. Make a real library result reachable in one keyboard invocation and one
   activation.
2. Show why a result matched and, for a scene, the exact playable timestamp.
3. Keep the first interaction useful without an AI provider, using metadata
   and full-text indexes already stored locally.
4. Send requests that need follow-up or mutation to the Agent without hiding
   the handoff from the user.
5. Maintain local-first behavior: opening, searching, and browsing must not
   upload a user's library.

## Non-goals

- Replacing the media detail page, player, Ask Filmly, or the full Agent
  workspace.
- Treating a language model answer as an authority for a library operation.
- Making deletion, moving, or renaming a one-step command.
- Requiring embeddings, a cloud provider, or a completed transcription before
  title search works.
- Forcing the desktop command palette pattern onto a touch-first mobile UI.

## Core interaction

### Open and close

On desktop, `Cmd+K` on macOS and `Ctrl+K` elsewhere toggles the command
center. It opens centered near the top of the current app window, dims the
library behind it, and places focus in the query field. `Esc` dismisses it and
returns focus to the prior surface.

The existing `Cmd/Ctrl+F` continues to open traditional title search. The two
shortcuts represent different intents rather than competing implementations:

```text
Cmd/Ctrl+F  → title/filter search
Cmd/Ctrl+K  → describe what you remember or what you want to do
```

### States

```text
Empty
  → three concise starting actions: search, full Ask Filmly, full Agent

Typing
  → local title / transcript / scene results stream into a single list

Selection
  → Up / Down changes the active row; Enter runs its safe default action

No match
  → explain that no local match exists, retain the query, offer Ask Filmly

Error
  → explain which capability is unavailable; title search and playback stay
     available even if optional AI infrastructure is not
```

### Result taxonomy

Every result has one primary action. The UI must never make the user infer
whether an item will start playback, open a page, or change data.

| Result kind | Example | Primary action | Required evidence |
| --- | --- | --- | --- |
| Media | A title / series match | Open media detail | title, year, match reason |
| Scene | Dialogue or indexed scene | Play at timestamp | title, snippet, timestamp, match reason |
| Agent handoff | “Find duplicate files” | Open Agent with the exact prompt | visible handoff label |
| Safe library report | “Library health” | Open report or Agent preview | input scope and freshness |
| Mutating plan | “Generate subtitles for…” | Open a plan; never execute here | affected-item preview and confirmation step |

Scene rows use a play affordance. Media rows use a detail affordance. A plan is
never represented as a play result.

### Keyboard behavior

| Key | Behavior |
| --- | --- |
| `Cmd/Ctrl+K` | Toggle the command center |
| `Esc` | Dismiss without changing library state |
| `↑` / `↓` | Move the active result; do not move the text caret |
| `Enter` | Open the active result; with no selected result, continue in Ask Filmly |
| Click / tap | Run the same action as `Enter` on that row |

Keyboard selection is visible with a subtle accent surface and works with a
screen reader's selected state. There is no hidden destructive shortcut.

## Information layout

```text
 ┌────────────────────────────────────────────────────────────────┐
 │ ✦  Search scenes, dialogue, people, or a feeling…          ESC │
 ├────────────────────────────────────────────────────────────────┤
 │ RESULTS FROM YOUR LIBRARY                                      │
 │ ▸  唐朝诡事录 · 2022                                            │
 │    Metadata match                                              │
 │                                                                 │
 │    唐朝诡事录 · 00:17:43                                  ▶     │
 │    “……苏无名……” · Dialogue timeline match                    │
 │                                                                 │
 │ ───────────────────────────────────────────────────────────── │
 │ ◇  Continue in Media Agent                                     │
 ├────────────────────────────────────────────────────────────────┤
 │ ASK FILMLY                              ↑↓ Select  ↵ Open     │
 └────────────────────────────────────────────────────────────────┘
```

The visual language is quiet and utility-oriented: a warm near-white surface,
one accent color, low-contrast separators, and only one prominent icon per
row. It should feel closer to a focused system utility than a chat product.

Results are limited initially to eight so that the action remains fast and the
palette never becomes a second library page. A full results request moves to
Ask Filmly.

## Visual design

### Art direction

**A quiet editorial instrument.** The command center should feel like a
precision tool laid over a personal cinema, not like a generic AI chat panel.
It borrows the familiar immediacy of Spotlight but adopts Open Filmly's
near-white, black, and electric-blue visual language. The memorable detail is
the contrast between an almost silent search surface and a single bright blue
playback timestamp: the interface makes the moment in a film feel tangible.

Avoid gradients, chat bubbles, oversized AI illustrations, or a rainbow of
status badges. Information density comes from precise spacing, type hierarchy,
and clear evidence rather than decorative cards.

### Tokens

These are product tokens, not one-off palette values. They map to the existing
`FilmlyPalette` and should be extracted as component tokens when the surface
is stabilized.

| Token | Value | Use |
| --- | --- | --- |
| Canvas | `#F3F3F6` | App content behind the modal |
| Palette surface | `#F9F9FB` | Command-center body |
| Quiet fill | `#EAEAEE` | Keycaps, inactive icon wells, hover fill |
| Hairline | `#E2E2E6` | Dividers and outline |
| Ink | `#1C1C1E` | Primary text and the single solid action |
| Secondary ink | `#6E6E76` | Explanations and snippets |
| Muted ink | `#9A9AA2` | Labels and secondary metadata |
| Filmly blue | `#2F6BFF` | Timestamp, active result, links, focused state |
| Backdrop | `#57000000` | Modal dim; the library remains recognizable |

Dark mode is not specified by this document. Until it has a complete token
set, preserve the current native light appearance rather than inverting a few
colors opportunistically.

### Desktop composition

The command center has fixed visual anchors but flexible height. It should
never feel like a window within a window.

| Viewport | Palette width | Top offset | Horizontal margin | Maximum height |
| --- | ---: | ---: | ---: | ---: |
| ≥ 1180 px | 720 px | 92 px | 20 px | 640 px |
| 820–1179 px | min(720 px, viewport − 40 px) | 72 px | 20 px | 600 px |
| < 820 px desktop | viewport − 32 px | 56 px | 16 px | viewport − 80 px |

The container uses a 20 px radius, a 1 px hairline, and one deep but diffuse
shadow (`y: 22`, `blur: 52`, black at 25%). It has no chrome, title bar, or
separate close button; `Esc` and the visible keycap make dismissal obvious.

```text
1440 × 900 desktop

  ┌─ existing library remains visible but de-emphasized ────────────────┐
  │                                                                     │
  │                    ┌──────────── 720 ────────────┐                │
  │                    │  [✦]  natural-language query  [ESC]          │
  │                    ├───────────────────────────────────────────────│
  │                    │  RESULTS FROM YOUR LIBRARY                    │
  │                    │  ┌ selected / blue 10% tint ───────────────┐ │
  │                    │  │ [poster/play] Title · year            ↗ │ │
  │                    │  │ reason                         01:17:43 │ │
  │                    │  └─────────────────────────────────────────┘ │
  │                    │  [play] Scene title                      ▶   │
  │                    │          dialogue or scene evidence          │
  │                    ├───────────────────────────────────────────────│
  │                    │  ASK FILMLY              ↑↓ Select  ↵ Open  │
  │                    └───────────────────────────────────────────────┘
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
```

### Type and spacing

Use the operating system's display sans so titles in Latin, Chinese, Japanese,
and Korean use the same native-quality rendering: SF Pro / PingFang SC on
macOS, Segoe UI on Windows, and the platform's appropriate fallback elsewhere.

| Element | Size / weight | Spacing rule |
| --- | --- | --- |
| Query | 18 px / 500 | 16 px top and 15 px bottom in a 64 px input bar |
| Result title | 14 px / 600 | one line; truncate at the end |
| Result snippet | 12 px / 400 | one line; 3 px below title |
| Evidence and timestamp | 11 px / 400; timestamp 700 | 5 px below snippet |
| Section label | 10 px / 800, 1.05 px tracking | 14 px above first result |
| Footer label | 10 px / 800, 1.1 px tracking | 10 px vertical padding |

Result rows use a 12 px radius, 10 px horizontal padding, and 10 px vertical
padding. The leading visual well is 38 × 38 px. These repeated measures make
media, scene, and handoff rows feel like one system rather than a list of
unrelated cards.

### Component states

| Component | Rest | Hover | Keyboard selected | Pressed / loading | Disabled / unavailable |
| --- | --- | --- | --- | --- | --- |
| Query field | transparent, focused text cursor | unchanged | native focus ring only | clear control appears when non-empty | no input only during app startup |
| Result row | transparent | `Quiet fill` | Filmly blue at 10% opacity + semantics selected | 96% scale is not used; retain position | not applicable; hide invalid results |
| Scene affordance | blue icon well | blue 14% tint | same as row | direct player transition | never shown without URI + timestamp |
| Media affordance | quiet icon well | `Quiet fill` | same as row | detail transition | never shown without media id |
| Agent handoff | hairline-separated plain row | quiet fill | blue 10% tint | route transition only | shown even without cloud AI |
| Keycap | quiet fill | unchanged | unchanged | unchanged | omit unavailable shortcuts |

Rows do not jump, resize, or introduce a spinner inside the title when an
action starts. The palette fades and the destination owns the next loading
state. This preserves the feeling of an immediate command.

### Motion

- Open: 180 ms ease-out fade plus a restrained `0.985 → 1.0` scale from the
  top center.
- Close: use the same 180 ms transition in reverse; wait for it before
  navigating so the modal backdrop cannot cover the destination.
- Active result: 120 ms ease-out color transition only.
- Hover controls: 160 ms ease-out; no elastic motion, rotation, or parallax.
- Loading: a 2 px progress indicator centered in the result area. It replaces
  rows rather than making the query field move.

### Full Media Agent workspace

The full Agent is a **workbench**, not a messenger clone. It keeps the same
quiet canvas but uses a wider reading measure and reserves visual emphasis for
plans that need a decision.

```text
┌──────────────────────────────────────────────────────────────────────┐
│ ‹  Media Agent                                    Search ⌘K          │
│    Plan first. Confirm before anything changes.                       │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Your library,                                                         │
│  with intent.                                                         │
│  Search scenes quickly above, or ask for a review and a safe plan.    │
│                                                                        │
│  [Library health] [Find duplicates] [Create collection]               │
│                                                                        │
│  User request                                                         │
│  “Find films I abandoned last year.”                                   │
│                                                                        │
│  Agent response                                                        │
│  12 items match. I can prepare a review; nothing changes yet.         │
│                                                                        │
│  ┌ Plan: Long-unwatched review ────────────────────────────────────┐ │
│  │ 12 items · read-only preview · generated just now                │ │
│  │ [Review items]                                    [Create plan] │ │
│  └─────────────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────┤
│ Ask about your library…                                  [Send ↵]    │
└──────────────────────────────────────────────────────────────────────┘
```

Messages are arranged as editorial blocks, not opposing rounded bubbles:

- User requests align to the reading column with a thin left rule and muted
  `YOU` label.
- Agent responses use plain text on the canvas with an `OPEN FILMLY` label;
  tool use is summarized as a compact provenance line, never raw JSON.
- Plans are the only strong cards. They use a 16 px radius, a quiet surface,
  a concise scope line, visible preview count, and one black primary action.
- Confirmed and completed plans retain a timestamp and result summary instead
  of disappearing from the conversation.
- The composer is a 56 px anchored work surface with a 12 px radius and no
  floating send orb. `Enter` sends; `Shift+Enter` inserts a line break.

At a width below 980 px, the Agent remains a single reading column. A plan
does not become a side panel; it stays inline so keyboard and narrow-window
flows retain reading order.

### Responsive mobile translation

The mobile surface is a bottom sheet rather than a scaled desktop dialog:

| Property | Mobile spec |
| --- | --- |
| Sheet | 16 px top radius, 92% viewport max height, drag handle |
| Query | 52 px field, 16 px side margins, no desktop keycaps |
| Rows | 56 px minimum touch target; title, reason, and timestamp stay visible |
| Scene action | Entire row plays at the timestamp; no tiny trailing-only target |
| Handoff | Opens the full-screen Agent page with the prompt preserved |
| Footer | Omit keyboard help; use a concise local-search/privacy message instead |

### UI acceptance screenshots

The review set for this feature contains real application screenshots, not
mockups:

1. Empty desktop palette at 1440 × 900.
2. Desktop results for a real exact-title query, including selected state.
3. Scene result with timestamp and match reason.
4. Post-Enter destination with the palette fully absent.
5. Full Agent empty state and a plan preview state.
6. Mobile bottom-sheet layout once Phase 4 begins.

## Source of truth and ranking

The command center shows data from the user's existing media and intelligence
stores. It does not synthesize a title, a timestamp, or an operation result.

The ranking order is:

1. Exact and prefix title matches from the core media library.
2. Other title and metadata matches.
3. Transcript FTS matches, with their source timestamps.
4. Indexed scene summaries.
5. Optional embedding matches when a local or approved provider is available.

If the filename includes a title but the stored title says something else,
the explicit stored title must rank above the path-only match. This prevents a
visibly wrong top result from becoming the default action.

## Agent handoff and safety

The palette may hand a query to Media Agent, but it never performs an action
that changes the library. The Agent workflow remains:

```text
request → inspect real local data → proposed plan → user confirms → execute
```

The plan screen must show scope, affected items, and an undo or recovery path
where one exists. Destructive file actions remain unavailable by default.

## Platform behavior

| Platform | Behavior |
| --- | --- |
| macOS / Windows / Linux desktop | Full keyboard-first command center; local search and direct playback |
| iOS / Android | A compact sheet or a dedicated search entry point; no dependency on a hardware shortcut |
| All platforms | Consume previously generated transcripts and scene indexes when available |

Mobile must preserve the result taxonomy and safety rules, but it should use a
bottom sheet and touch-sized targets rather than imitate Spotlight.

## Accessibility and localization

- Focus always starts in the field and returns to the invoking control on
  dismissal.
- Every row exposes title, result type, reason, and timestamp as semantics.
- Color is never the only indication of a scene, selected result, or error.
- All new text moves behind the app's localization layer before the surface is
  declared stable. English is the source locale; Simplified Chinese ships with
  it.
- Timestamps follow the app's familiar playback format and do not depend on
  the display locale.

## Privacy and reliability

- Metadata and FTS retrieval run locally.
- Optional cloud AI must be opt-in and obey the user's existing provider
  configuration; a request shows when it leaves the device.
- API keys are never included in command history, result logging, exports, or
  screenshots.
- If an AI provider, worker, or index is unavailable, the palette reports the
  degraded capability and retains non-AI search and playback.

## Acceptance criteria

1. From any desktop library page, `Cmd/Ctrl+K` opens a focused palette.
2. An exact title query presents that title ahead of path-only legacy matches.
3. Selecting a scene starts the existing player at the stored timestamp.
4. Selecting a media result opens the existing media detail page.
5. The palette fully dismisses before a route or player opens.
6. Keyboard and pointer activation run the same safe action.
7. No provider configuration is required for metadata and FTS results.
8. No library mutation can be executed from the palette.

## Open questions

1. Should the command center search recent viewing activity as an explicit
   result group, or keep it inside Ask Filmly until the ranking model matures?
2. When a remote provider is enabled, should its results be shown only after
   local results, or may it interleave with a visible “cloud-assisted” label?
3. Which Agent reports deserve a direct read-only result in the command center
   rather than a handoff to the full workspace?
4. Should command history be local-only and opt-in, or omitted entirely in the
   first public release?
