# Technical Plan: Personal Media OS — Next Horizons

**Status:** Active planning (post `agent/agent-workspace-redesign` foundation)  
**Branch baseline:** `agent/agent-workspace-redesign` (CI green as of `781ae4a`)  
**Date:** 2026-07-24  
**Platform gate:** macOS first; Windows / iOS / Android keep parity for shell routes only unless noted

---

## 1. Product north star

```text
文件 → AI 理解 → 语义索引 → 个人记忆 → AI Agent → 播放
```

Open Filmly is not “a player with a chat box”. It is a **private media operating system** that:

1. Understands what is *inside* local media (dialogue, scenes, structure).
2. Lets people **find and jump** without remembering titles.
3. Answers **in-progress** questions without spoilers.
4. Plans **library work** with preview → confirm → execute → undo.
5. Keeps media files, credentials, and raw library data under user control.

---

## 2. Baseline already on the branch

### Shipped (code-complete, CI-covered)

| Layer | What exists |
| --- | --- |
| **Command surface** | Spotlight `Cmd/Ctrl+K` (BEST MATCH / MOMENTS / ASK), recent destinations, Shift+Enter → conversation |
| **Conversations** | Durable conversation rail, pin/archive/rename, plan cards + detail drawer, Gemini tools |
| **Intelligence DB** | Independent SQLite: assets, jobs, transcripts, FTS, content segments, embeddings, watch events, agent runs/conversations, smart collections |
| **Offline understanding** | Sidecar `.srt`/`.vtt` ingest, scene segmentation, local hashed embeddings, hybrid Ask Filmly search |
| **Indexer UX** | `/intelligence` workspace, quiet startup index (limit 40), status counts |
| **Companion** | Spoiler guard, citations + seek, optional Gemini over safe context only |
| **Player** | Smart skip chips from intro/outro segments |
| **Agent** | Safe plan ops, `search_dialogue_scenes`, smart collections browser `/collections` |
| **Memory** | Local watch events + summary page |

### Still thin or blocked on external systems

| Gap | Why it matters | Blocker type |
| --- | --- | --- |
| **No-sidecar ASR** | Vision P0 “AI 字幕” for bare MKV | Local Worker + Whisper model path |
| **Real embedding model** | Better semantic recall than hash BoW | Worker `embed` or optional cloud |
| **Frame / visual index** | “雨夜城门画面” without dialogue | `sampleFrames` / vision model |
| **Subtitle timeline editor** | Correct ASR drift, bilingual polish | Flutter editor UX + re-export |
| **Proper nouns / film context correction** | Name consistency beyond regex | LLM or glossary pipeline |
| **Recommendation quality** | “今晚两小时轻松科幻” | History + content features + ranker |
| **Cross-device intelligence sync** | Memory + transcripts follow the user | Export/import or sync protocol |
| **Worker packaging / settings UX** | Non-dev users cannot enable ASR | Binary/script packaging + health UI |

---

## 3. Capability maturity matrix

| Capability | Maturity | Notes |
| --- | --- | --- |
| Library browse / play | **Production** | Core path |
| Cmd+K title open | **Production** | Metadata search |
| Cmd+K dialogue jump | **Beta** | Needs indexed transcripts |
| Ask Filmly hybrid search | **Beta** | Strong when sidecars exist |
| Conversation Agent | **Beta** | Needs Gemini key for NL; plans are safe |
| Companion | **Beta** | Extractive always; Gemini optional |
| Smart skip | **Alpha** | Heuristic labels only |
| Batch AI subtitles | **Alpha** | Code path; needs Worker |
| Visual search | **Not started** | Schema hooks only |
| Personal memory insights | **Alpha** | Counts + recent; weak themes |
| Smart collections UI | **Alpha** | List + open titles; no edit shelf |

---

## 4. Architecture to protect

Do not collapse these boundaries:

```text
Core media DB (files, TMDB, progress)
        │  no AI tables here
        ▼
Intelligence DB (assets, transcripts, jobs, conversations, embeddings)
        │
        ├── Local path: sidecar → FTS → hash embed → search/companion
        ├── Worker path: ASR / translate / real embed / frames
        └── Cloud path (optional): Gemini plan + companion wording only
                                    (never raw library paths/credentials)
```

**Safety invariants (non-negotiable):**

1. Agent never executes library mutations without preview + confirm.
2. Companion never receives transcript after current playback position.
3. Palette never executes plans; only navigation / conversation handoff.
4. Intelligence data can be wiped without corrupting core media DB.
5. Network media stays out of local ASR until a streaming ingest story exists.

---

## 5. Phased plan (PR-sized)

### Phase A — Ship the foundation (0.5–1 day)

**Goal:** Land the redesign branch cleanly.

| PR | Work | Exit criteria |
| --- | --- | --- |
| A1 | Open PR `agent/agent-workspace-redesign` → `main` | CI green; review checklist below |
| A2 | Release notes: Intelligence / Conversations / Companion | User-facing “how to index” short doc |
| A3 | Optional: tag preview build / DMG from CI artifacts | Installable smoke on one Mac |

**Review checklist for A1:**

- [ ] Bundle ID / App name still production (`Open Filmly`)
- [ ] No force-overwrite install scripts in merge
- [ ] Intelligence DB migration path documented
- [ ] Startup index remains best-effort (no snackbar spam on failure)
- [ ] Settings: Gemini + Worker paths still discoverable

---

### Phase B — Make P0 “usable without ASR” excellent (3–5 days)

**Goal:** Anyone with existing Chinese/English sidecars gets a great Ask Filmly + Companion experience.

| PR | Work | Exit criteria |
| --- | --- | --- |
| B1 | Indexer quality: prefer best language sidecar, re-index dirty assets, progress cancel | Re-run index updates only changed files |
| B2 | FTS quality: CJK n-gram indexing at write time (not only fallback scan) | `雨夜长安` hits without full table scan at scale |
| B3 | Ask Filmly results: posters, play button, reason chips, empty-state deep links | Visual parity with design |
| B4 | Detail page “Index this title” + status badge (has transcript / scenes) | Per-item control without full-library run |
| B5 | Job list UI in `/intelligence` (queued/running/failed) | Visibility into long work |

**Acceptance:**

- Library of ≥500 local items with sidecars: index under a few minutes, searchable after restart.
- Companion answers from sidecars without Worker.
- No core DB writes from indexer.

---

### Phase C — AI Worker productization (1–2 weeks, parallelizable)

**Goal:** Bare video files get transcripts without developer CLI ritual.

Existing: `tool/ai_worker/main.py` + `AiWorkerClient` protocol.

| PR | Work | Exit criteria |
| --- | --- | --- |
| C1 | Worker health in Settings: probe path, model dir, latency, last error | User sees green/red status |
| C2 | One-click “Generate subtitles” from player / detail | Job enqueued + progress toast/sheet |
| C3 | Package notes + script for macOS (Python venv / PyInstaller optional) | Fresh Mac can follow ≤10 steps |
| C4 | After ASR success: auto rebuild segments + embeddings | Same path as sidecar ingest |
| C5 | Optional: model download UX (tiny/base) with size warnings | No silent multi-GB downloads |

**Acceptance:**

- `FILMLY_AI_E2E_*` e2e passes on a sample MKV in CI optional job or nightly.
- Failed Worker leaves conversation/job error, never corrupts media files.

---

### Phase D — Companion + Skip to “delight” (1 week)

| PR | Work | Exit criteria |
| --- | --- | --- |
| D1 | Companion sheet: scene chips, jump, “explain this line” from current subtitle | ≤2 taps from player |
| D2 | Spoiler tests: unit matrix of position boundaries | Hard regression suite |
| D3 | Smart skip: user preferences (auto / ask / off), confidence threshold | No false skip mid-plot by default |
| D4 | Recap mode: “summarize what I watched so far” using safe window only | Uses segments + Gemini if present |

---

### Phase E — Agent as library OS (1–2 weeks)

| PR | Work | Exit criteria |
| --- | --- | --- |
| E1 | Tool: `index_library` / `get_intelligence_status` | Agent can diagnose “why no scene hits” |
| E2 | Smart collection edit/delete in UI; pin to home shelf | Collections feel first-class |
| E3 | Batch subtitle plan uses real Worker generator end-to-end | Undo deletes generated artifacts only |
| E4 | Conversation → open media / play scene deep links in answers | Citations become actions |
| E5 | Rate-limit + cost guard for Gemini tool loops | No runaway multi-call turns |

---

### Phase F — Visual & true semantic (research → alpha)

Only after B+C are stable:

| PR | Work | Notes |
| --- | --- | --- |
| F1 | Frame sampling job (`sampleFrames`) + screenshot paths on content segments | Disk budget + privacy |
| F2 | Vision caption → `searchText` / embeddings | Local or remote model |
| F3 | Replace hash embed with Worker embedding model when available | Dual-read: model tag column already exists |
| F4 | Hybrid ranker: title / FTS / embed / visual weights | Offline evaluation set |

---

### Phase G — Memory & multi-device (later)

| PR | Work |
| --- | --- |
| G1 | Memory themes from genres + watch events (no cloud) |
| G2 | Export/import intelligence DB alongside core transfer |
| G3 | Selective sync (memory only vs full transcripts) |

---

## 6. Recommended execution order (next 2 weeks)

```text
Week 1
  A1 merge PR
  B1 indexer quality
  B4 per-title index badge
  C1 Worker health in Settings

Week 2
  B2 CJK FTS write path
  B3 Ask Filmly result polish
  C2 player/detail “Generate subtitles”
  D1 Companion UX polish
  E1 intelligence tools for Agent
```

**Default priority rule:**  
Anything that improves **search/jump with existing subtitles** beats anything that requires new model downloads.

---

## 7. Test & quality strategy

| Layer | Required |
| --- | --- |
| Unit | Ingest, segments, embeddings, spoiler, skip, conversation repo (already present → expand) |
| Widget | Shell no-overflow, palette sections, agent rail, intelligence page |
| Integration | Indexer on temp tree with sidecars |
| Optional e2e | Worker ASR (`test/ai_worker_e2e_test.dart` env flags) |
| Manual macOS | Index 20 real films → Cmd+K scene → Companion → Agent plan |

CI must stay green on:

- Analyze
- Full unit/widget suite
- Platform builds (already in Flutter CI)

---

## 8. Explicit non-goals (this quarter)

- Becoming a general chatbot product UI.
- Auto-deleting or auto-moving user media files.
- Mandatory cloud accounts for core library.
- Full visual search SOTA accuracy on first alpha.
- Real-time streaming ASR for network (SMB/WebDAV) without local cache strategy.

---

## 9. Success metrics (product)

| Metric | Target after Phase B+C |
| --- | --- |
| Scene hit rate for queries with dialogue in subtitles | ≥ 70% on internal query set |
| Time from install → first successful scene jump | ≤ 10 min with sidecars |
| Companion spoiler incidents in test suite | 0 |
| Agent destructive ops without confirm | 0 (invariant) |
| Crash/ANR from startup indexing | 0 |

---

## 10. Immediate next action

1. **Open and merge** the current feature PR (Phase A1).  
2. Start **Phase B1 + B4** in a new branch from `main` after merge.  
3. Parallel track: **C1 Worker health** if you want ASR demos soon.

This plan deliberately freezes the conversation/command redesign as “done enough to ship”, and redirects effort to **understanding coverage** (index quality + Worker) which is the remaining wall between Open Filmly and the Personal Media OS story.
