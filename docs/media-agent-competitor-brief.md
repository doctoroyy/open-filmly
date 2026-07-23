# Media Agent competitor brief

**Purpose:** Ground Open Filmly’s Media Agent in jobs users already want from the self-host media ecosystem (GitHub + Chinese forums), not generic chatbot UX.

**Sources:** GitHub projects (SuggestArr, Maintainerr, Janitorr, Jellyfin MCP / multi-agent routing patterns), Linux.do / NodeSeek self-host threads (MediaStationGo, Emby rename/scrape pipelines, Bangumi auto-rename + subtitle workflows, “小龙猫 AI” download agents).

---

## Peer matrix

| Peer / source class | Defining media-agent jobs | How it runs | What it is not |
| --- | --- | --- | --- |
| **SuggestArr** ([GitHub](https://github.com/giuseppe99barchetta/SuggestArr)) | Watch history → similar titles → request downloads (Seerr/Overseerr); optional LLM ranking | Server-side automation against Plex/Jellyfin/Emby APIs | Local-file hygiene; dialogue search; safe confirm for destructive ops |
| **Maintainerr / Janitorr** | Library maintenance rules: age, watch state, disk pressure → tag/delete schedules | Rule engines on server libraries + *arr stack | In-player NL Q&A; private local-first agent without a media *server* |
| **Jellyfin MCP / multi-agent routers** (e.g. LobeHub Jellyfin MCP writeups) | NL “play / find 1999 movies / server status” routed to specialist agents | MCP tools over Jellyfin HTTP API | Understands *inside* files (dialogue timeline) only if server plugins exist |
| **MediaStationGo + Chinese NAS threads** (Linux.do / NodeSeek) | One-box library + scrape + AI search/recommend + 302 cloud play; rename/scrape pipelines | Self-host media center + AI search | Local-first client agent sitting on the user’s own library DB with undoable plans |
| **Community rename/subtitle bots** (Linux.do: Bangumi rename → subtitle forums → Emby refresh) | Rename, subtitle acquire, metadata refresh, notify | Scripts / n8n-like chains | Conversational durable agent with preview/confirm and local scene search |

---

## Jobs users actually ask for (synthesized)

1. **Library pulse** — How many movies/TV? Favorites? Unwatched backlog?  
2. **Metadata health** — Missing posters, ratings, overviews (scrape debt).  
3. **File hygiene reports** — Duplicates, low-res names, missing sidecars (report first, never silent delete).  
4. **Find something to watch** — Genre + year + unwatched filters.  
5. **Inside-content find** — Dialogue/scene jump when subtitles/index exist.  
6. **Maintain / grow** — Smart collections, subtitle generation plans, (out of scope) download requests.  
7. **Diagnose AI features** — “Why can’t I search 雨夜长安?” → intelligence index status.

---

## Open Filmly gaps to own (product differentiation)

| Job | Peers | Open Filmly Media Agent should own |
| --- | --- | --- |
| Dialogue/scene search in *local* files | Rare without plugins | Index sidecars + FTS/semantic; honest empty when unindexed |
| Safe plan lifecycle on client library | Server tools often auto-act | Preview → confirm → execute → undo; never silent delete/move |
| Durable conversation + plan cards | Chatbots forget; *arr UIs are dashboards | Intelligence DB conversations with linked plan ids |
| Offline-first tool answers | Many need always-on server + LLM key | Local rule engine for common Chinese/English library tasks without Gemini |
| Personal media OS (player + library + agent in one app) | Split across Jellyfin + Seerr + Maintainerr + scripts | Single app, local DB, agent next to playback |

**Non-goals (do not copy blindly):** unsupervised Arr download bots, multi-user server admin, silent disk cleanup.

---

## Tool allowlist implied by research

Must stay grounded on real library data:

- `get_library_stats`, `inspect_metadata_health`, `inspect_media_issues` (duplicates / lowQuality / **missingSubtitles**)
- `search_media`, `search_dialogue_scenes` (when indexed)
- `get_intelligence_status` (diagnostic)
- Plan-generating: smart collections, batch subtitles, unwatched/duplicate/low-quality **reports**

---

## Implementation priority from this brief

1. Complete missing issue inspections and richer stats/health samples.  
2. Offline NL → tool/plan path so the agent is useful without a cloud key.  
3. Intelligence status + dialogue search diagnostics.  
4. Keep durability + plan safety tests as the quality bar for “真正实用”.
