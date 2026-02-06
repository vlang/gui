# External Integrations

**Analysis Date:** 2026-02-01

## APIs & External Services

**Mermaid Diagram Rendering:**
- Kroki API - Converts Mermaid diagram source to PNG
  - Endpoint: `https://kroki.io/mermaid/png`
  - SDK/Client: `net.http` (V stdlib)
  - Method: POST
  - Input: Mermaid diagram source (plaintext)
  - Output: PNG binary
  - Auth: None (public API)
  - Location: `xtra_mermaid.v` - `fetch_mermaid_async()` function (line 55)
  - Caching: Local FIFO cache (max 50 diagrams) with temp file storage

**IME Input (macOS):**
- vglyph StandardIMEHandler - Routes IME composition events to focused input
  - SDK/Client: `vglyph` (V library)
  - Integration: NSTextInputClient protocol via overlay view
  - Auth: None (local OS API)
  - Location: `ime.v` - `init_ime()`, `update_ime_focus()`
  - Events: commit (final text), update (marked text change),
    layout (cursor position), cursor index (byte offset)
  - Lifecycle: Overlay created lazily in `frame_fn` because NSWindow
    unavailable during `init_fn`

## Data Storage

**Databases:**
- None - Framework does not use databases

**File Storage:**
- Local filesystem only
  - Temporary PNG cache for Mermaid diagrams
  - Temp files stored in `os.temp_dir()` with format: `mermaid_{hash}_{random}.png`
  - Cache entry cleanup: `BoundedDiagramCache.clear()` deletes temp files
  - Location: `xtra_mermaid.v` (lines 120-189)

**Caching:**
- In-memory FIFO diagram cache (`BoundedDiagramCache` struct)
  - Max size: 50 entries (configured in `DiagramCacheEntry`)
  - Key: i64 hash of diagram source
  - Value: `DiagramCacheEntry` with state (loading/ready/error), PNG path, error msg
  - LRU eviction: Oldest entries deleted when cache full
  - Location: `view_state.v` - `diagram_cache` field in `ViewState` struct

## Authentication & Identity

**Auth Provider:**
- None - GUI framework has no user authentication
- Kroki API is unauthenticated (public)

## Monitoring & Observability

**Error Tracking:**
- None configured

**Logs:**
- Console logging via `log` module (V stdlib)
  - Used in `render.v` for graphics debugging
  - No structured logging framework

## CI/CD & Deployment

**Hosting:**
- GitHub (source repository at `https://github.com/vlang/gui`)

**CI Pipeline:**
- Not detected in codebase
- Check: `.github/` directory exists but no workflow files analyzed

## Environment Configuration

**Required env vars:**
- None

**Optional env vars:**
- None detected

**Secrets location:**
- No secrets management (Kroki is public API, no auth credentials needed)

## Webhooks & Callbacks

**Incoming:**
- None - GUI is client-side only

**Outgoing:**
- None declared
- HTTP calls are one-way to Kroki API for diagram rendering

## Network Behavior

**Outbound Connections:**
- Kroki API calls (https://kroki.io/mermaid/png)
  - Triggered by: `gui.view_mermaid()` widget
  - Async background thread: `spawn` in `fetch_mermaid_async()` (line 52)
  - Error handling: Network failures stored in cache with error message
  - Timeout: V's `http.fetch` default timeout (no explicit config)
  - Response validation:
    - Max size: 10MB (rejected if larger)
    - Status code 200 required
    - PNG format validated via stbi loader
  - Retry: Not implemented (one-shot request)

## Image Processing

**Image Libraries:**
- `stbi` (V stdlib) - Handles PNG/JPG loading and resizing
  - Used in Mermaid diagram flow for:
    - Loading PNG from binary response: `stbi.load_from_memory()`
    - Resizing if wider than max_width: `stbi.resize_uint8()`
    - Writing temp PNG file: `stbi.stbi_write_png()`
  - Location: `xtra_mermaid.v` (lines 84-137)

## Data Format Support

**Markdown Parsing:**
- Custom markdown parser in `xtra_markdown.v`
  - Converts markdown to rich text
  - Link detection for embedded URLs
  - Not using external library

**SVG Rendering:**
- Custom SVG parser in `svg.v`
  - Full SVG support: paths, transforms, groups, strokes, gradients
  - Not using external library

**CSV Support:**
- `encoding.csv` (V stdlib) - Used for table data in `view_table.v`

---

*Integration audit: 2026-02-01*
