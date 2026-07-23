# Design: Filmly Command Palette & Conversation Library

**Status:** Implemented (conversation rail, palette sections, plan drawer); polish tracked in `plan-personal-media-os-next.md`

**Platforms:** Desktop first (macOS validation), with a responsive path for
Windows and mobile consumption
**Replaces:** the first Media Command Center design

## Why the first design is not enough

The first implementation solved neither of the two jobs it was meant to
separate:

1. `Cmd/Ctrl+K` should let someone find and open something immediately.
2. A longer question or a library task should have a durable home where the
   conversation can be resumed.

Instead, the full Agent currently behaves like a single, temporary chat
transcript. It has no conversation list, consumes a large empty canvas, and
makes the lightweight search shortcut feel like a route into a chat product.
That is the opposite of the intended experience: **Spotlight for immediate
navigation, a conversation library for sustained thinking.**

This redesign treats them as two distinct surfaces that happen to share a
query and the same media intelligence layer. It is not an “AI chat redesign”.
It is the desktop interaction model for a personal media OS.

## Product promise

| Surface | The question it answers | Outcome | Must never become |
| --- | --- | --- | --- |
| **Filmly Command Palette** | “Where is that film, scene, person, or line?” | A focused result list; one key or click opens the destination. | A chat window or an action executor. |
| **Filmly Conversations** | “Help me understand, review, or safely plan work in my library.” | A persistent, named conversation with evidence and reviewable plans. | A blank full-page messenger clone. |

The primary desktop flow is therefore:

```text
Cmd/Ctrl+K
  → type a memory, title, person, line, or scene
  → choose a concrete list result
  → open media detail or play at the matched timestamp

Only when the request needs reasoning, follow-up, or a reviewable action:
  → Continue as a new Filmly conversation
  → keep the conversation in the local conversation library
```

## Design direction: the private screening room

The interface should feel like a carefully indexed private collection: quiet,
editorial, precise, and close to native macOS utility software. It should not
look like a generic SaaS dashboard, a messenger, or an “AI assistant” with
decorative sparkles.

- **Visual character:** warm paper-white surfaces, graphite text, a single
  cinematic blue for focus and navigation, and restrained shadows. Use film
  poster or scene imagery only when it helps choose a result.
- **Typography:** a compact, high-legibility Chinese/Latin pairing. The
  implementation should use the platform text stack until a bundled typeface
  is approved; hierarchy comes from weight, measure, and spacing—not large
  display slogans.
- **Shape:** 10–14 px corners for controls, 12 px row rhythm, hairline
  dividers. Large rounded cards are reserved for a reviewable plan, never for
  every message.
- **Motion:** 140–180 ms, ease-out. The palette rises and settles; the active
  result moves by tint and a small position change. No bounce, glow, or
  typewriter effect.

### Tokens

| Token | Value | Use |
| --- | --- | --- |
| Canvas | `#F6F5F2` | Conversation and palette background |
| Elevated surface | `#FFFDFC` | Composer, palette, plan card |
| Ink | `#1D1C1A` | Titles and primary content |
| Secondary ink | `#68655F` | Summaries and timestamps |
| Rule | `#E5E2DC` | Dividers and inactive borders |
| Filmly blue | `#246BDE` | Selection, links, open/play actions |
| Warm focus | `#EAF1FF` | Keyboard-active result row |
| Warning | `#A85C16` | Pending plan state only |

## Information architecture

```text
Open Filmly shell
├── Cmd/Ctrl+K: Filmly Command Palette
│   ├── direct media / person / scene result → detail or player timestamp
│   ├── Ask Filmly search workspace → /ask
│   └── “Continue in Filmly” → a new persisted conversation
└── Filmly Conversations → /agent
    ├── conversation rail
    │   ├── New conversation
    │   ├── Pinned
    │   ├── Today / Earlier / Archived
    │   └── overflow: rename, archive, delete
    ├── active conversation thread
    │   ├── grounded answer and source affordances
    │   └── reviewable plan card, when relevant
    └── contextual detail drawer (only when useful)
        ├── plan preview / execution status
        └── citations, matched media, or task history
```

The global Open Filmly navigation stays unchanged. “Conversations” is a
workspace within the existing Agent destination, not a second application
sidebar.

## 1. Filmly Command Palette

### Behaviour

`Cmd+K` on macOS and `Ctrl+K` elsewhere opens the palette from every desktop
route. The field has focus before the surface finishes its entrance animation.
Typing is search-first: it immediately produces a keyboard-navigable list of
real library matches.

The palette does not send text to a cloud provider while the person is simply
searching. It may use local title, metadata, FTS, and semantic indexes. A
query becomes a conversation only through the explicit handoff row or the
`Shift+Enter` shortcut.

| Input | Primary result | Secondary option |
| --- | --- | --- |
| `唐朝诡事录` | Open the show | Open seasons / episodes |
| `雨夜 长安 等朋友` | Play the matching scene at its timestamp | Open Ask Filmly search |
| `宫崎骏` | List matching titles, people, and collections | Continue in Filmly if no local result answers it |
| `找重复文件` | “Plan this in Filmly” handoff row | Never execute from the palette |

### Desktop wireframe

```text
                               ⌘K
                   ┌──────────────────────────────────────────────┐
                   │  ⌕  Search your library                       │
                   │                                      Esc       │
                   ├──────────────────────────────────────────────┤
                   │  BEST MATCH                                   │
                   │  [poster] 唐朝诡事录 · 2022          ↵ Open    │
                   │           36 episodes · TV series             │
                   ├──────────────────────────────────────────────┤
                   │  MOMENTS                                      │
                   │  ▶  唐朝诡事录                                │
                   │     “雨夜的长安城门…” · 00:31:18     Play ↵   │
                   │  ▶  长安十二时辰                              │
                   │     “…” · 00:42:09                            │
                   ├──────────────────────────────────────────────┤
                   │  ASK                                           │
                   │  ↗  Continue in Filmly                        │
                   │     Ask a follow-up or make a safe plan       │
                   ├──────────────────────────────────────────────┤
                   │  ↑↓ Navigate     ↵ Open     ⇧↵ Continue    Esc│
                   └──────────────────────────────────────────────┘
```

### Layout and hierarchy

- **Placement:** centered horizontally, 12–16% down from the usable desktop
  height. It is not pinned to the top like an application page.
- **Width:** 720 px at normal desktop widths; may grow to 800 px for scene
  result readability. Minimum 480 px.
- **Input row:** plain search icon, input, and `Esc` hint. No AI logo, hero
  copy, or permanent “start here” menu. With no query, show only three recent
  local destinations and a muted prompt example.
- **Result rows:** 56 px for media, 68 px for a scene. A poster or a play
  glyph is functional visual context. The reason and timestamp sit on the
  second line; the right edge states the outcome (`Open`, `Play 00:31:18`).
- **Selection:** one warm-blue row tint and a 2 px blue leading rule. The
  selected item never changes the entire card background.
- **No-result state:** remain in the same compact list. Offer “Search all in
  Ask Filmly” and “Continue in Filmly”, with the exact query preserved.

### Keyboard contract

| Key | Behaviour |
| --- | --- |
| `Cmd/Ctrl+K` | Open; when already open, close without changing the current route |
| `↑` / `↓` | Move the active result row |
| `Enter` | Execute the active result’s visible outcome |
| `Shift+Enter` | Start a new Filmly conversation with the current prompt |
| `Esc` | Close and return focus to the previous element |
| `Cmd/Ctrl+F` | Keep the existing in-page library search; it does not compete with the palette |

## 2. Filmly Conversations

### A library, not a transient transcript

A conversation begins only on the first submitted message. It receives a
local, deterministic title from that message and is saved in the intelligence
database. Reopening it must restore every visible turn, the plans created in
it, and their current execution states.

The conversation rail is a first-class part of the desktop page. A person can
scan their prior questions in the same way they scan playlists or recent
media. Chat history is not hidden behind a profile menu or a modal.

### Desktop wireframe

```text
┌──────── Open Filmly shell ───────┬──── Conversations ────┬──────────────────────── Thread ───────────────────────┐
│                                   │  + New conversation   │  影视库健康度                         ⌘K Search       │
│  Home / Movies / TV / …           │                       │  Updated just now · local conversation                  │
│                                   │  PINNED               │─────────────────────────────────────────────────────────│
│                                   │  ● 科幻片智能合集      │  YOU                                                    │
│                                   │    7 items · 12 min   │  分析我的影视库健康度                                  │
│                                   │                       │                                                         │
│                                   │  TODAY                │  FILMLY                                                 │
│                                   │  ◉ 影视库健康度        │  你的库有 2,277 个项目，其中 1,966 个缺少海报…          │
│                                   │    Missing metadata   │  Sources: library metadata · last checked just now      │
│                                   │  ◌ 雨夜长安是哪一集    │                                                         │
│                                   │    2 messages         │  [ View affected titles ]                               │
│                                   │                       │                                                         │
│                                   │  EARLIER              │                                                         │
│                                   │  ◌ 90 分钟的轻松电影   │                                                         │
│                                   │                       │─────────────────────────────────────────────────────────│
│                                   │                       │  Ask about your library or describe a task…    ↑ Send   │
└───────────────────────────────────┴───────────────────────┴─────────────────────────────────────────────────────────┘
```

### Conversation rail

| Element | Behaviour |
| --- | --- |
| **New conversation** | Clears the active thread without creating an empty record. The record exists after the first send. |
| **Pinned** | Explicitly pinned conversations, then most recently updated ones. |
| **Time groups** | Today, Yesterday, Previous 7 days, Earlier. Archive is separated from the default list. |
| **Conversation row** | Title, one-line latest-answer preview, relative update time, and a subtle plan status dot when applicable. |
| **Overflow menu** | Rename, pin/unpin, archive, and delete. Deletion asks for confirmation and removes only conversation data, never plans or media. |
| **Active state** | Warm-blue leading rule plus a quiet surface tint. No filled pill spanning the rail. |

Rows are 56–64 px. The rail is 248 px wide at desktop sizes, has its own
scroll, and never forces the thread to become overly narrow.

### Active thread

- **Reading measure:** 640–760 px. Messages are not full-width page blocks;
  they have a deliberate left edge and a comfortable line length.
- **Header:** editable conversation title, local-only status, last-updated
  time, compact overflow menu, and the `⌘K Search` affordance. The page title
  is the actual conversation, not a permanent “Media Agent” banner.
- **Messages:** user requests are a short left-ruled record. Filmly answers
  are typography on the canvas, followed by compact evidence chips or source
  links. Avoid rounded speech bubbles for both sides.
- **Plans:** a plan remains an attached, high-contrast review card containing
  scope, preview count, affected titles, and exactly one next state. It can
  open a contextual drawer for the full preview; it never silently executes.
- **Composer:** sticky but visually light. One field, optional attachment or
  context control later, `⌘↵` / button to send. It is aligned with the thread,
  not stretched across unused page width.
- **Empty conversation:** no oversized marketing headline. Show a small
  opening prompt and three useful examples in the message area, with the
  composer already ready.

### Contextual detail drawer

The detail drawer is closed by default. It appears only for an active plan,
a source list, or a result set that needs inspection. It is a 300 px panel on
large desktops and a slide-over on narrower ones. This preserves the quiet
thread while keeping evidence and plan review close at hand.

## Responsive behaviour

| Available content width (after global navigation) | Conversations rail | Detail drawer | Palette |
| --- | --- | --- | --- |
| `≥ 1120 px` | 248 px, always visible | 300 px when opened | 720–800 px |
| `780–1119 px` | 232 px, always visible | Slide-over | 640 px max |
| `< 780 px` | Opened from a conversation button / sheet | Full-height sheet | Full-width bottom sheet |

Mobile consumes conversations and search results, but does not imitate a
desktop multi-pane view. The current macOS validation remains the release
gate for this redesign.

## Conversation lifecycle and privacy

1. **New** creates an unsaved visual state.
2. The first send creates a local conversation and saves the user message.
3. A final Filmly answer is stored with its visible evidence and any plan ID.
4. Opening a row restores the thread locally before any provider call.
5. Continuing a conversation sends only the selected, bounded local context to
   the configured provider. API keys, raw credentials, and unrelated library
   paths are never stored in message text.
6. Archiving hides a conversation from the default list. Deleting it removes
   its local conversation records after confirmation; it does not delete the
   associated media, subtitles, collection, or Agent execution record.

Command-palette query text remains ephemeral. It is not command history and
is not saved unless the person explicitly continues it as a conversation.

## Safety boundaries

- The palette opens destinations only. It never confirms or executes an Agent
  plan.
- Every plan appears inside a persisted conversation with its current status.
- A completed task can still be inspected after reopening the conversation.
- A failed provider request preserves the user’s sent message and displays a
  retryable local error record; it never drops the conversation.
- The command palette, conversation store, and execution history are all
  independent from the core media database.

## What we deliberately remove

- The generic “Media Agent” landing screen with a large empty field of view.
- “Open Media Agent” as the dominant empty state of `Cmd/Ctrl+K`.
- An in-memory-only transcript that disappears on navigation or relaunch.
- Decorative AI icons, gradients, bubbles, or an always-visible right panel.

## Acceptance criteria

1. Pressing `Cmd/Ctrl+K`, typing a query, and pressing `Enter` can open a real
   title or play a real scene without visiting a chat route.
2. `Shift+Enter` or the explicit handoff creates a new conversation with the
   exact query, never a hidden transient transcript.
3. Every submitted conversation is visible in the conversation rail after
   navigation and relaunch.
4. Selecting an old conversation restores its messages, sources, plan cards,
   and current plan status.
5. The active thread has no large unstructured empty space at a 1200 px app
   width.
6. The only UI that can confirm or execute a plan is its review card in the
   selected conversation.
7. No palette query is persisted unless it becomes a conversation.
