# glassy-lyrics 🎤

**Synced lyrics as big, fullscreen terminal text — karaoke style.**

glassy-lyrics turns whatever your media player is playing into giant, glowing
lyrics in the middle of your terminal. There is no GUI, no browser, no overlay
window fighting for focus — just your terminal, filled with the current word in
huge block letters, live-highlighted in time with the music.

Under the hood it is a *single Python file*. Every word is rendered with
**Pillow** into a bitmap and then painted as terminal **half-block characters**
(`█ ▀ ▄`), which means ASCII, German ß, accents, Hangul, CJK and emoji all come
out looking the same — sharp, monochrome and terminal-native. When the lyric
source provides word-level timing, the highlighting follows the actual singing;
otherwise it falls back to line-level sync and a smart character-weighted
interpolation.

It works with **any player that exposes MPRIS over `playerctl`** — not just
Spotify. Spotify, VLC, mpv, Firefox/YouTube, Chromecast players … if `playerctl`
sees it, glassy-lyrics can display its lyrics.

```text
glassy-lyrics 1.7.0 — synced lyrics as big terminal text
```

glassy-lyrics is part of **GlassVibe**, which belongs to the **GlassTools** —
the in-house tools of [GlassyOS](https://github.com/eliii-te) (GOS), my Linux
distribution. GlassyOS is expected to release around the middle of next year.
Until then glassy-lyrics runs **completely standalone** on any Linux distro —
you do not need GlassyOS, GOS, or a license to use it.

---

## Table of contents

- [Why glassy-lyrics?](#why-glassy-lyrics)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option A — the SETUP.zip package (recommended)](#option-a--the-setupzip-package-recommended)
  - [Option B — manual install](#option-b--manual-install)
- [Quick start](#quick-start)
- [Usage & CLI reference](#usage--cli-reference)
- [Environment variable reference](#environment-variable-reference)
  - [Sizing the big text (`GLASSY_LYRICS_HEIGHT`)](#sizing-the-big-text-glassy_lyrics_height)
- [Configuration](#configuration)
  - [Per-song offsets — `offsets.json`](#per-song-offsets--offsetsjson)
  - [Local LRC overrides — `lrc/`](#local-lrc-overrides--lrc)
  - [Word-level Spotify lyrics (`sp_dc`)](#word-level-spotify-lyrics-sp_dc)
  - [Word/syllable-level via Better Lyrics](#wordsyllable-level-via-better-lyrics)
- [How it works (architecture)](#how-it-works-architecture)
  - [The lyric race](#the-lyric-race)
  - [The renderer](#the-renderer)
  - [Position tracking](#position-tracking)
- [Colours, glyphs & internals](#colours-glyphs--internals)
- [Examples](#examples)
- [Troubleshooting & gotchas](#troubleshooting--gotchas)
- [Development](#development)
- [Status & roadmap](#status--roadmap)
- [Credits & license](#credits--license)

---

## Why glassy-lyrics?

Lyrics displays are usually either locked to one app, drawn by a webview, or
shrink to fit a normal-sized window so that nobody can read them from across the
room. glassy-lyrics goes the other way:

- **Big first.** The point is the *text*. The active word fills the screen, the
  metadata is a thin dim footer at the bottom, and nothing else competes.
- **One file, almost no dependencies.** `glassy-lyrics` is a single executable
  Python script. The only mandatory third-party bits are `playerctl` (for
  metadata) and Pillow (for rendering). No daemon, no config service, no
  database.
- **Player-agnostic.** It reads MPRIS through `playerctl`, so it does not care
  whether the music comes from Spotify, a local mpv window, a video in Firefox
  or a Chromecast.
- **Truthful karaoke.** Where real word-level timing exists (Spotify's own
  synced lyrics, or the Better Lyrics TTML dataset), it is used directly instead
  of being guessed. Guessing only happens as an explicit last resort.
- **Flicker-free.** It renders at 30 Hz but only redraws the rows that actually
  changed, using ANSI cursor moves instead of clearing the screen.

---

## Features

- **Big text, rendered properly** — Pillow → bitmap → half-block characters.
  No `figlet`, no broken accents, no missing Hangul or CJK.
- **Live word-level karaoke** — driven by real word/syllable timing from
  Better Lyrics TTML or Spotify's `LINE_AND_WORD_SYNCED` data. On line-level
  LRCs it falls back to a character-weighted interpolation so the highlight is
  still roughly in step.
- **Player-agnostic via MPRIS** — works with every `playerctl` player. Set
  `GLASSY_LYRICS_PLAYER` if your player is not named `spotify`.
- **Five lyric sources**, queried in a prioritised race, word-level before
  line-level:
  1. **Local override LRC files** (`~/.config/glassy-lyrics/lrc/`) — always win.
  2. **Spotify's own color-lyrics API** — needs your `sp_dc` cookie (optional).
  3. **Better Lyrics API** (`lyrics-api.boidu.dev`) — TTML with word/syllable
     timing, the same dataset Spicy Lyrics (Spicetify) renders.
  4. **LRCLIB** — line-level.
  5. **python-syncedlyrics** (Musixmatch / NetEase) — optional line-level
     fallback.
- **Flicker-free, diff-aware rendering** at 30 Hz with a background poller and
  monotonic-clock position extrapolation — the render loop never blocks on a
  `playerctl` subprocess.
- **Width-aware centering** with full CJK / wide-character support: wide glyphs
  count as two cells, so centering stays true.
- **Auto-fit and long-word splitting** — if a word is too wide, the renderer
  shrinks it; if it *still* does not fit, the word is split across stacked
  block-art rows.
- **Per-song offsets and language overrides** via a small JSON config.
- **Silent by default** — stray stderr from subprocesses and libraries is
  redirected to `/dev/null` so nothing can corrupt the display (flip it back on
  with `GLASSY_LYRICS_DEBUG=1`).

---

## Requirements

- **Linux** (any distro — Arch, Debian/Ubuntu, Fedora, …).
- **`python3` ≥ 3.8**.
- **`playerctl`** — the bridge to the playing media player.
- **A running media player that exposes MPRIS** (Spotify, VLC, mpv, Firefox,
  Chromium, …). glassy-lyrics reads whatever `playerctl` reports.
- **Pillow** (`python3-pillow` / `python3-pil`) — mandatory for big block text.
  Without it the tool still runs, but degrades to plain one-line text.
- **A bold font** from the built-in search list — at least one of
  **DejaVu Sans Bold** or **Noto Sans CJK Bold**. The installer pulls these in.
- **A terminal that supports ANSI escapes and half-block characters** — any
  modern terminal (kitty, alacritty, foot, GNOME Terminal, Konsole, xterm-256color…).

Optional:

- **`syncedlyrics`** (pip) — adds Musixmatch / NetEase as extra fallback
  sources.
- **A Spotify `sp_dc` cookie** — unlocks Spotify's own synced lyrics, including
  word-level timing, for Spotify Premium/Free web sessions.

---

## Installation

### Option A — the SETUP.zip package (recommended)

The repo ships a self-contained installer archive: **`SETUP.zip`** (~15 KB). It
contains exactly two files:

```text
SETUP/setup          # the installer
SETUP/glassy-lyrics  # the tool itself
```

**1. Download `SETUP.zip`** from the file list.

**2. Extract it and run the setup file** — it installs the tool plus all
dependencies (`python3`, Pillow, `playerctl`, fonts), adds `~/.local/bin` to
your `PATH`, verifies the install, and finally deletes itself:

```bash
unzip SETUP.zip
cd SETUP
bash setup          # or: ./setup
```

`setup` is interactive and asks before touching the system (it needs `sudo` for
package installs). Flags and escape hatches:

| Flag / env | Effect |
|---|---|
| `-y`, `--yes` | Assume *yes* for every prompt (non-interactive). |
| `-h`, `--help` | Show the installer's short help. |
| `SETUP_SKIP_SYSTEM=1` | Skip all package-manager steps (dev/testing only). |

What the installer does, step by step:

1. sanity-checks that it is running on Linux with `glassy-lyrics` next to it,
2. detects your package manager (`pacman`, `apt` or `dnf`) and installs the
   missing system packages (python, Pillow, playerctl, a font, pip),
3. offers the optional `syncedlyrics` fallback via `pip --user`,
4. copies `glassy-lyrics` to `~/.local/bin/glassy-lyrics` (chmod +x),
5. appends `~/.local/bin` to `PATH` in `~/.bashrc` (or `~/.zshrc`) if missing,
6. verifies with `glassy-lyrics --version`,
7. prints next steps and **removes itself**.

**3. Open a new terminal and run the installed command:**

```bash
glassy-lyrics
```

### Option B — manual install

If you would rather do it yourself (or your distro is not covered by the
installer), the whole thing is three small steps:

```bash
# 1. System packages (example: Arch)
sudo pacman -S --needed python python-pillow playerctl ttf-dejavu noto-fonts-cjk

# Debian/Ubuntu equivalent:
#   sudo apt install python3 python3-pil playerctl fonts-dejavu-core
# Fedora equivalent:
#   sudo dnf install python3 python3-pillow playerctl dejavu-sans-fonts

# 2. Install the tool
install -Dm755 glassy-lyrics ~/.local/bin/glassy-lyrics

# 3. Optional: extra lyric fallback (Musixmatch / NetEase)
python3 -m pip install --user syncedlyrics
```

Make sure `~/.local/bin` is on your `PATH` (the installer does this for you; for
a manual install add it to your shell rc yourself):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Quick start

```bash
# 1. Start playing something — Spotify by default, or any MPRIS player.
# 2. Then run:
glassy-lyrics
```

That's it. The screen is cleared, the current word appears huge in the middle,
and a dim footer at the bottom shows the track, a progress bar and elapsed /
total time. Press **Ctrl+C** to quit — the screen, cursor and attributes are
restored.

Using a different player? Point it there explicitly:

```bash
GLASSY_LYRICS_PLAYER=vlc glassy-lyrics
GLASSY_LYRICS_PLAYER=mpv glassy-lyrics
GLASSY_LYRICS_PLAYER=firefox glassy-lyrics
```

Check the version or read the built-in help:

```bash
glassy-lyrics --version
glassy-lyrics --help
```

---

## Usage & CLI reference

glassy-lyrics deliberately has a **tiny** command-line surface — everything
interesting happens while it runs.

| Command | Description |
|---|---|
| `glassy-lyrics` | Run the fullscreen lyrics display for the active player. |
| `glassy-lyrics --version` / `-V` | Print `glassy-lyrics <version>` and exit. |
| `glassy-lyrics --help` / `-h` | Print the usage/help text and exit. |

Anything else is configured through **environment variables** and the files in
`~/.config/glassy-lyrics/` (see below).

While running:

- the **big text** shows the currently sung word (word-level sources) or the
  interpolated active word (line-level sources);
- the **footer** shows `Artist — Title`, a 24-cell progress bar, `m:ss / m:ss`
  elapsed/total and, if a per-song offset is active, a `Δ±x.xs` marker;
- if nothing is playing you get `No track playing — playerctl: no active player`;
- if lyrics are still being fetched you get `Loading lyrics …`;
- if no source had a match you get `No synced lyrics found`.

**Exit:** `Ctrl+C` (SIGINT) and `SIGTERM` both run the cleanup path, which shows
the cursor again and clears/re-restores the screen.

---

## Environment variable reference

All behaviour is driven by these variables. None of them are required — the
defaults are chosen so that plain `glassy-lyrics` just works.

| Variable | Default | Description |
|---|---|---|
| `GLASSY_LYRICS_PLAYER` | `spotify` | The `playerctl` player name to read metadata from. Set it to `vlc`, `mpv`, `firefox`, … for other players. |
| `GLASSY_LYRICS_OFFSET` | `0.0` | Global offset in **seconds** added to the playback position. **Positive = lyrics appear earlier**; negative = later. |
| `GLASSY_LYRICS_HEIGHT` | `8` | Height of the big block text in **terminal rows**. See the sizing section below. |
| `GLASSY_LYRICS_FALLBACK` | `1` | `1` (default) also tries the `syncedlyrics` source; set to `0` to skip it (faster, less network). |
| `GLASSY_LYRICS_DEBUG` | *(unset)* | Set to `1` to keep **stderr visible**. By default all stderr is redirected to `/dev/null` so nothing corrupts the display. |
| `GLASSY_LYRICS_BOIDU_KEY` | *(unset)* | Optional `X-API-Key` for the **Better Lyrics** API (uncached tracks / rate-limit bypass). Sent as the `X-API-Key` header. |
| `SETUP_SKIP_SYSTEM` | *(unset)* | **Installer only.** `1` skips all package-manager steps. |

### Sizing the big text (`GLASSY_LYRICS_HEIGHT`)

`GLASSY_LYRICS_HEIGHT` sets how many terminal rows a single word should occupy.
The tool converts that into a Pillow bitmap of `height × 2` pixels (two pixel
rows per terminal cell row, using the upper/lower half-block trick) and draws
the font to roughly 85 % of that box before trimming empty rows.

Practical guidance:

- **Range:** roughly **4–14 rows** is the usable band.
  - Below **4** there is nothing left to shrink to — the auto-fit loop stops at
    4 rows, so smaller values behave the same as 4 and the text stops being
    "big".
  - Above **14** you need a genuinely tall terminal; the word plus its vertical
    centering and the one-row footer will otherwise overflow.
- **Sweet spot:** **8–12 rows**. That is big enough to read from across the
  room and still leaves breathing space on a normal 24–40 row terminal.
- The renderer also **auto-fits**: if the word is too wide for the terminal at
  your configured height, it retries at progressively smaller sizes down to 4
  rows. Only if it *still* overflows does it **split the word** into chunks and
  stack them, separated by a blank row.

Persist your choice for every session by adding it to your shell rc:

```bash
# ~/.bashrc (or ~/.zshrc)

# Point at a non-Spotify player
export GLASSY_LYRICS_PLAYER="vlc"

# Nice, roomy letter size on a normal terminal
export GLASSY_LYRICS_HEIGHT=10

# Nudge every song a little earlier / later
# export GLASSY_LYRICS_OFFSET=0.2

# Keep stderr visible while experimenting
# export GLASSY_LYRICS_DEBUG=1
```

Then `source ~/.bashrc` (or open a new terminal) and run `glassy-lyrics`.

---

## Configuration

Everything lives in the config directory:

```text
~/.config/glassy-lyrics/
├── sp_dc          # optional Spotify cookie (single line)
├── offsets.json   # per-song offsets + language overrides
└── lrc/           # local LRC override files (always win)
```

The installer creates this directory (including `lrc/`). You can create it by
hand too: `mkdir -p ~/.config/glassy-lyrics/lrc`.

### Per-song offsets — `offsets.json`

Some masters are simply shifted: the lyrics are consistently a fraction of a
second early or late. `offsets.json` fixes that per song, so you don't have to
nudge the global `GLASSY_LYRICS_OFFSET` every time.

Keys are `"Artist|Title"` and matching is **case-insensitive**. A value can be:

- a **number** → offset shorthand, in seconds (positive = lyrics earlier), or
- an **object** with an `offset` field and/or a `lang` field used by the
  `syncedlyrics` fallback (e.g. `ko` for Korean).

```json
{
  "Stray Kids|Chk Chk Boom": -0.4,
  "IU|Love wins all": { "offset": 0.2, "lang": "ko" }
}
```

- The **global** `GLASSY_LYRICS_OFFSET` is applied first; the **per-song**
  offset is added on top.
- While a per-song offset is active the footer shows `Δ±x.xs`.
- A missing or malformed file is ignored silently (it falls back to offset 0).

### Local LRC overrides — `lrc/`

Drop a standard `.lrc` file into `~/.config/glassy-lyrics/lrc/` and it **always
wins** over every remote source. This is the fix when a remote LRC is
incomplete, mistimed, or missing entirely.

Naming rule:

- filename is `<Artist> - <Title>.lrc`
- matching is **case-insensitive**
- any `/` in the artist or title is replaced with `_`

```text
~/.config/glassy-lyrics/lrc/My Band - My Song.lrc
```

When such a file exists, the race is skipped entirely and the local file is
used immediately — offline and instant.

### Word-level Spotify lyrics (`sp_dc`)

Spotify is the only source with its own per-word timing. If you want Spotify's
synced lyrics (including `LINE_AND_WORD_SYNCED` word-level karaoke timing), put
your `sp_dc` browser cookie in `~/.config/glassy-lyrics/sp_dc`:

```bash
# copy the sp_dc cookie value from your logged-in browser
# (dev tools → Application → Cookies → open.spotify.com → sp_dc)
echo "YOUR_SP_DC_VALUE" > ~/.config/glassy-lyrics/sp_dc
```

Notes:

- The file must contain the raw cookie value on a single line.
- glassy-lyrics exchanges it for a short-lived web-player access token and
  refreshes it as needed; the token is kept **in memory only**.
- If Spotify rejects the cookie (HTTP 400/403), the source is **disabled for
  the session** so the tool stops hammering the endpoint, and everything falls
  back to the other sources. Nothing breaks — you simply won't get Spotify's
  own timing.
- Spotify has been tightening third-party auth (TOTP) since late 2025, so this
  source can legitimately stop working at any time. It is genuinely optional.

### Word/syllable-level via Better Lyrics

The **Better Lyrics API** (`lyrics-api.boidu.dev`) returns Apple-style **TTML**
with real word/syllable timing — the same dataset Spicy Lyrics (Spicetify)
renders. If a track is cached there, glassy-lyrics shows true karaoke timing
with **no configuration at all**.

- `itunes:timing="Word"` → every `<span>` is a word.
- `itunes:timing="Syllable"` → consecutive syllables are grouped into words by
  their trailing spaces.
- If a track has no word spans, the `<p begin>` times are used as line-level.

Uncached or obscure tracks simply fall through to line-level LRCLIB. If you hit
rate limits, set `GLASSY_LYRICS_BOIDU_KEY` with an API key.

---

## How it works (architecture)

glassy-lyrics is a single ~1150-line Python file with a handful of clear
components. There is no server, no database, and nothing is written to disk
except whatever you put in the config dir yourself.

| Component | Responsibility |
|---|---|
| `BlockRenderer` | Renders a string through Pillow into a bitmap, then converts pairs of pixel rows into `█ ▀ ▄` half-block rows. Caches per `(text, rows)`. |
| `BigWord` | Wraps `BlockRenderer` with **auto-fit** and **long-word splitting**, plus a background **pre-warm** of every word in the lyrics. |
| `Frame` | The diff-aware frame renderer: remembers the last word/size/footer and only emits ANSI cursor moves for the lines that changed. |
| `TrackState` | Background thread polling `playerctl` every 0.5 s; exposes a non-blocking `current()` with monotonic-clock position extrapolation. |
| `SpotifyLyrics` | Optional Spotify web-player API client (token from `sp_dc`, `color-lyrics/v2`). |
| `LyricsCache` | In-memory per-`(artist, title)` cache + in-flight deduplication. |
| `fetch_lyrics_race` | The multi-source race described below. |
| `parse_lrc` | Parses standard `[mm:ss.xx]` LRC into `(line_ts, line_text, [])`. |
| `parse_ttml` | Parses Apple-style TTML (Better Lyrics) into `(line_ts, line_text, [(word_ts, word), …])`, handling namespaces and both word/syllable timing. |
| `parse_spotify_response` | Converts Spotify's JSON into the same internal shape, mapping syllables to words via a prefix-sum of character offsets. |
| `find_word` | Given the playback position, returns the active line, the active word, and the line index — real word timing when present, char-weighted interpolation otherwise. |

Everything is coordinated in `main()`: a 30 Hz loop that reads the current
track, asks the cache for lyrics, resolves the active word and hands it to
`Frame`.

### The lyric race

On every track change, all configured sources are queried **in parallel** and
the first valid hit wins. Word-level sources get a head start so an accurate
karaoke track always beats a guessed one:

1. **Local override** (`lrc/`) — if present, it returns immediately and the race
   is skipped entirely.
2. **Phase 1 — word-level sources** start first: Spotify (if `sp_dc` is
   configured) and Better Lyrics. They get a **1.2 s head start**.
3. **Phase 2 — line-level fallbacks** start only if Phase 1 has not produced a
   result yet: LRCLIB exact match, LRCLIB search, and (if
   `GLASSY_LYRICS_FALLBACK=1`) `syncedlyrics` via a subprocess.
4. The whole race is bounded by a **25 s** window; the individual HTTP fetches
   use a **12 s** timeout.

`syncedlyrics` runs in a **subprocess** (using `sys.executable`, so a
pyenv/venv interpreter still finds it) so its noisy `print()` output can never
leak into the rendering.

### The renderer

- The target bitmap is `GLASSY_LYRICS_HEIGHT × 2` pixels tall.
- The active **word** is rendered **upper-cased**; consecutive pixel rows are
  combined into blocks: top+bottom → `█`, top only → `▀`, bottom only → `▄`,
  neither → space. Empty top/bottom rows are stripped.
- If the rendered word is wider than the terminal, the height is stepped down
  (down to 4 rows). If it still overflows, the word is **split into chunks** and
  the chunks are stacked with a blank row between them.
- Frames are diffed: the previous big-text block is erased by geometry, the new
  one is written vertically centred (leaving one row for the footer), and the
  footer is only rewritten when it changes. All writes are batched into one
  `sys.stdout.write()` per frame to avoid tearing.
- Wide characters (CJK, Hangul, full-width forms, emoji planes) count as two
  cells in `char_width`, so `vis_width`, `truncate_vis` and `center_pad` keep
  everything correctly aligned. `truncate_vis` appends `…` when clipping.

### Position tracking

`playerctl` is slow enough that calling it from the render loop would stutter.
So `TrackState` polls it in the background (every 0.5 s), records the position
together with a `time.monotonic()` timestamp, and the reader *extrapolates*:
while the player is `Playing`, the reported position is `last_position +
(now - last_timestamp)`. Small backward jumps from noisy reporting (< 0.6 s)
are clamped away so the highlight never jumps backwards.

---

## Colours, glyphs & internals

The look is intentionally minimal, so there is not much to configure. For the
curious, these are the fixed internals:

| Constant | Value | Meaning |
|---|---|---|
| `VERSION` | `1.7.0` | Tool version. |
| `POLL_INTERVAL` | `0.5 s` | How often the background thread polls `playerctl`. |
| `RENDER_HZ` | `30` | Frame rate of the render loop. |
| `FETCH_TIMEOUT` | `12 s` | Per-request HTTP timeout for lyric fetches. |
| `RACE_TIMEOUT` | `25 s` | Total window for the lyric race. |
| `BIG_HEIGHT_ROWS` | `8` (→ `GLASSY_LYRICS_HEIGHT`) | Default big-text height. |
| Progress bar width | `24` cells | `▰` filled / `▱` empty. |

Styling is applied with plain ANSI codes: `\033[97m` (bright white) and
`\033[1m` (bold) for the big text, `\033[2m` (dim) for the footer, `\033[0m` to
reset. The cursor is hidden on start and shown again on exit
(`\033[?25l` / `\033[?25h`). Attributes are reset *before* each erase so a stray
escape from another program can't bleed into a new frame.

Fonts are chosen from a built-in search list, first match wins:

```text
/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc          # Arch Noto CJK
/usr/share/fonts/noto-cjk/NotoSansCJK-Black.ttc
/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc     # Debian/Ubuntu
/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc
/usr/share/fonts/google-noto-cjk/NotoSansCJK-Bold.ttc   # Fedora
/usr/share/fonts/google-noto-cjk/NotoSansCJK-Black.ttc
/usr/share/fonts/TTF/DejaVuSans-Bold.ttf                # DejaVu, several paths
/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf
/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf     # Nerd Font / JetBrains
/usr/share/fonts/JetBrainsMonoNerdFont-Bold.ttf
```

If **no** font from this list exists — or Pillow is missing — the tool does not
crash: `BlockRenderer.render()` returns the raw text on one line, so you get
plain (small) lyrics instead of block art.

---

## Examples

**Everyday use** — Spotify, default size, quick exit:

```bash
glassy-lyrics
# … watch the words, then Ctrl+C to quit
```

**A room-filling setup** on a big terminal:

```bash
GLASSY_LYRICS_HEIGHT=12 glassy-lyrics
```

**mpv / local files** instead of Spotify:

```bash
GLASSY_LYRICS_PLAYER=mpv glassy-lyrics
```

**Nudge a notoriously early Spotify master** a bit later:

```bash
GLASSY_LYRICS_OFFSET=-0.3 glassy-lyrics     # negative = lyrics later
```

**Debug why nothing shows up** — keep stderr visible:

```bash
GLASSY_LYRICS_DEBUG=1 glassy-lyrics
```

**Offline-ish, single LRC file** for one specific song:

```bash
mkdir -p ~/.config/glassy-lyrics/lrc
cp "my-song.lrc" "$HOME/.config/glassy-lyrics/lrc/My Band - My Song.lrc"
glassy-lyrics
```

**Persist all of it** in your shell:

```bash
cat >> ~/.bashrc <<'EOF'

# glassy-lyrics
export GLASSY_LYRICS_HEIGHT=10
export GLASSY_LYRICS_PLAYER=spotify
EOF
```

---

## Troubleshooting & gotchas

- **"No track playing"** — is your player actually running, and does
  `playerctl -p spotify status` say `Playing`? Using a different player? Set
  `GLASSY_LYRICS_PLAYER=vlc` (or `mpv`, `firefox`, …).
- **No lyrics shown** ("No synced lyrics found") — try a well-known track first.
  Add a local LRC override, or install `syncedlyrics` for the
  Musixmatch/NetEase fallback. Popular tracks get word-level karaoke via Better
  Lyrics; niche tracks usually only have line-level LRCLIB.
- **Lyrics drift / feel late** — fix per track with `offsets.json`, or globally
  with `GLASSY_LYRICS_OFFSET` (positive = earlier). Also make sure no other app
  is fighting over MPRIS: `playerctl status` should show exactly one `Playing`
  player.
- **Plain text instead of big block letters** — no compatible bold font was
  found, or Pillow is missing. Install Noto CJK or DejaVu (see the font list
  above) and/or Pillow.
- **Text is cut off on the sides** — the word is wider than the terminal. Lower
  `GLASSY_LYRICS_HEIGHT`, widen the terminal, or let auto-fit shrink it (it
  already steps down to 4 rows before splitting).
- **Garbled output / stray characters** — your terminal probably lacks half-block
  or ANSI support, or something else wrote to the terminal. Try a modern
  terminal, and avoid running other interactive programs in the same pane.
- **`playerctl` not found** — install it (`sudo pacman -S playerctl`, etc.). The
  tool has no MPRIS implementation of its own.
- **Spotify word-sync stopped working** — Spotify tightened third-party auth
  (TOTP) in late 2025. Update `~/.config/glassy-lyrics/sp_dc`, or just rely on
  Better Lyrics / LRCLIB, which need no account.
- **`syncedlyrics` installed but not used** — it must be importable by the
  interpreter running the script (`sys.executable`). If you installed it into a
  different Python/venv, install it there; and remember
  `GLASSY_LYRICS_FALLBACK=0` disables it on purpose.
- **Nothing shows over SSH / in a multiplexer** — the tool needs a real TTY with
  ANSI support. Most terminals over SSH are fine; strip-downed sessions are not.
- **Screen isn't restored after a kill** — if the process is killed with
  `SIGKILL` (or the terminal dies), cleanup cannot run. `reset` (or
  `tput reset`) in that terminal restores it.

---

## Development

The repo *is* the distributable:

```text
glassy-lyrics   # the tool (single executable Python file)
SETUP.zip       # the installer package users download
LICENSE         # MIT
README.md       # this file
```

There is **no build step**. Edit `glassy-lyrics`, then either run it in place
(`./glassy-lyrics`) or reinstall it:

```bash
install -Dm755 glassy-lyrics ~/.local/bin/glassy-lyrics
```

> **Keep `SETUP.zip` in sync.** The archive contains its own copy of the tool
> (`SETUP/glassy-lyrics`) and the installer (`SETUP/setup`). When you change
> the tool, refresh the copy inside the zip too — otherwise users who install
> from `SETUP.zip` get an older build.

Runtime dependencies beyond the standard library are intentionally minimal:
**Pillow** (mandatory) and **`playerctl`** (mandatory), plus optional
**`syncedlyrics`**. There is no framework, no packaging, no lockfile — just a
script you can read end to end in a few minutes.

`.gitignore` keeps the tree clean:

```text
__pycache__/
*.pyc
*.bak*
```

---

## Status & roadmap

**Status: 1.7.0 — β (beta), but stable for daily use.**

Working today:

- big-text rendering with Pillow + half-block characters,
- line-level sync (LRCLIB, local LRC) and real word-level sync (Better Lyrics
  TTML, Spotify `sp_dc`),
- any MPRIS player via `playerctl`,
- per-song offsets and language overrides,
- auto-fit and long-word splitting,
- flicker-free 30 Hz diff rendering with background polling.

Known limitations:

- Spotify's own synced-lyrics API may be blocked at any time (TOTP), so it is
  best-effort and clearly optional.
- Better Lyrics only covers *cached* tracks perfectly; the rest fall back to
  line-level.
- Line-level sources get *interpolated* karaoke, which can drift on very fast
  or very slow lines.

Ideas / not yet done:

- a persistent on-disk lyrics cache,
- a config file for the constants (currently env vars + source),
- translation / dual-language display,
- a small lyrics-picker for tracks with several candidates,
- packaging for major distros.

Contributions and ideas are welcome — open an issue.

---

## Credits & license

glassy-lyrics is part of the **GlassyOS** project (GlassVibe / GlassTools).

Lyric sources it talks to (as plain HTTP APIs — no code is copied):

- **LRCLIB** — https://lrclib.net
- **Better Lyrics API** — https://lyrics-api.boidu.dev (TTML dataset, as
  rendered by Spicy Lyrics)
- **Spotify color-lyrics** — Spotify's own web-player API (optional, via your
  `sp_dc` cookie)
- **python-syncedlyrics** — https://github.com/rtcq/syncedlyrics (optional,
  Musixmatch / NetEase / LRCLIB providers)

Fonts used for rendering come from your system (DejaVu, Noto CJK, or a Nerd
Font).

**License: MIT** — see [LICENSE](LICENSE).

```text
MIT License · Copyright (c) 2026 GlassyOS
```

Use it, fork it, ship it. Just keep the copyright notice.
