# glassy-lyrics 🎤

Synced lyrics as **big, fullscreen terminal text** — karaoke style.
Every word is rendered through Pillow into a bitmap and drawn with terminal
half-block characters (`█ ▀ ▄`), so ASCII, ß, Hangul, accents and emoji all
look the same. Live word highlighting when the source provides word-level
timing.

**Works with any media player** that exposes MPRIS over playerctl — not just
Spotify. Spotify, VLC, mpv, Firefox/YouTube, Chromecast players, … if
playerctl sees it, glassy-lyrics can display its lyrics.

```
glassy-lyrics 1.7.0 — synced lyrics as big terminal text
```

glassy-lyrics is part of **GlassVibe**, which belongs to the **GlassTools**
— the own tools of [GlassyOS](https://github.com/eliii-te) (GOS), my Linux
distribution. GlassyOS is expected to release around the middle of next year.
Until then, glassy-lyrics can be used completely standalone, without GlassyOS
— it runs on any Linux.

## ✨ Features

- **Big text, rendered properly** — Pillow → bitmap → half-block characters.
  No figlet, no broken accents, no missing Hangul.
- **Live word-level karaoke** — from real word/syllable timing (Better Lyrics
  TTML / Spotify word-synced) instead of guessing; char-weighted interpolation
  only as a last-resort fallback on line-level LRCs. For players without word-
  level sources the tool falls back to line-level synced lyrics.
- **Player-agnostic** — works with every playerctl/MPRIS player (Spotify,
  VLC, mpv, Firefox/YouTube, …). Just set `GLASSY_LYRICS_PLAYER` if your
  player isn't named `spotify`.
- **5 lyric sources race in parallel**, word-level wins over line-level:
  1. Local override LRC files (`~/.config/glassy-lyrics/lrc/`)
  2. Spotify's own color-lyrics API (needs your `sp_dc` cookie — optional)
  3. **Better Lyrics API** — TTML with word/syllable timing, the same dataset
     Spicy Lyrics (Spicetify) renders
  4. LRCLIB (line-level)
  5. python-syncedlyrics (Musixmatch / NetEase) — optional fallback
- **Flicker-free** diff-aware rendering at 30 Hz; background poller with
  monotonic-clock position extrapolation so the UI never blocks on playerctl.
- **Width-aware centering** with full CJK/wide-character support.
- Per-song offsets & language overrides via a JSON config.

## 📦 Requirements

- Linux (any distro — Arch, Debian/Ubuntu, Fedora, …)
- `python3` ≥ 3.8
- `playerctl`
- A running media player that exposes MPRIS (Spotify, VLC, mpv, Firefox, …)
  — glassy-lyrics reads whatever playerctl sees
- Fonts: one bold font from the search list (setup installs DejaVu + Noto CJK)
- Pillow (`python3-pillow` / `python3-pil`), syncedlyrics optional
- A terminal that supports ANSI + half-block characters (any modern one)

## 🚀 Install

### Option A — the SETUP folder (recommended)

**1. Download the `SETUP` folder** — on GitHub open the `SETUP` folder in the
 file list and click *Download* (or download the whole repo ZIP — the `SETUP`
 folder is in it). It contains only what's needed: `setup` + `glassy-lyrics`.

**2. Run the setup file inside it** — it installs the tool plus all
dependencies (python, Pillow, playerctl, fonts), adds it to your PATH,
verifies the install and then deletes itself:

```bash
cd SETUP
bash setup          # or: ./setup
```

**3. Open a new terminal and run the installed command:**

```bash
glassy-lyrics
```

### Option B — manual

```bash
# 1. System packages (example: Arch)
sudo pacman -S --needed python python-pillow playerctl ttf-dejavu noto-fonts-cjk

# 2. Install the tool
install -Dm755 glassy-lyrics ~/.local/bin/glassy-lyrics

# 3. Optional: better lyric fallback (Musixmatch/NetEase)
python3 -m pip install --user syncedlyrics
```

## 🎮 Usage

Start playing something (Spotify by default, or any MPRIS player), then:

```bash
glassy-lyrics
```

- `--version` / `-V` — print version
- `--help` / `-h` — show help
- `Ctrl+C` or `Ctrl+\` — exit (screen is restored)

## ⚙️ Configuration

All config lives in `~/.config/glassy-lyrics/`.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `GLASSY_LYRICS_OFFSET` | `0.0` | Seconds added to playback position (positive = earlier) |
| `GLASSY_LYRICS_PLAYER` | `spotify` | playerctl player name |
| `GLASSY_LYRICS_FALLBACK` | `1` | `0` disables the syncedlyrics fallback |
| `GLASSY_LYRICS_HEIGHT` | `8` | Big-text height in terminal rows |
| `GLASSY_LYRICS_DEBUG` | — | `1` keeps stderr visible (default: silenced to `/dev/null`) |
| `GLASSY_LYRICS_BOIDU_KEY` | — | Optional X-API-Key for the Better Lyrics API (uncached tracks / rate-limit bypass) |

### Per-song offsets — `offsets.json`

Keys are `"Artist|Title"` (case-insensitive). A bare number is an offset
shorthand; an object can also set a lyric language for the syncedlyrics
fallback (e.g. `ko` for Korean).

```json
{
  "Stray Kids|Chk Chk Boom": -0.4,
  "IU|Love wins all": { "offset": 0.2, "lang": "ko" }
}
```

### Local LRC overrides — `lrc/`

Drop a file named `<Artist> - <Title>.lrc` (case-insensitive, `/` → `_`)
into `~/.config/glassy-lyrics/lrc/`. It always wins over remote sources —
perfect when a remote LRC is incomplete.

### Word-level Spotify lyrics (optional)

Spotify is the only source with its own word-level timing. If you want
Spotify's own synced lyrics (incl. per-word karaoke timing),
place your `sp_dc` browser cookie in `~/.config/glassy-lyrics/sp_dc`:

```bash
# copy the sp_dc cookie value from your logged-in browser (dev tools → cookies)
echo "YOUR_SP_DC_VALUE" > ~/.config/glassy-lyrics/sp_dc
```

> Note: Spotify has been tightening auth for third-party access since
> late 2025. If your `sp_dc` gets rejected, the tool automatically falls
> back to the other sources — nothing breaks.

### Word/syllable-level via Better Lyrics (default, no setup)

If a track is in the Better Lyrics cache, glassy-lyrics shows real
word/syllable-level karaoke timing (the same TTML data Spicy Lyrics uses).
No configuration needed — it just works. Uncached/obscure tracks fall back
to line-level LRCLIB.

## 🧠 How it works

1. A background thread polls `playerctl` every 0.5 s and extrapolates the
   playback position with a monotonic clock — the render loop never blocks.
2. On track change, all configured lyric sources are queried **in parallel**
   (threads + a 25 s race window); first valid hit wins and is cached.
3. Every word is pre-rendered with Pillow to a bitmap, then converted to
   terminal half-block rows and cached (~5 ms/word).
4. The frame renderer only redraws what changed (big word / footer / size),
   writing ANSI cursor moves instead of clearing the whole screen → no flicker.

## 🐛 Troubleshooting

- **"No track playing"** — is your player running and does
  `playerctl -p spotify status` say `Playing`? Using a different player? Point
  the tool at it with `GLASSY_LYRICS_PLAYER=vlc glassy-lyrics` (or mpv,
  firefox, …).
- **No lyrics shown** — try a well-known track; add a local LRC override or
  install `syncedlyrics` for the Musixmatch/NetEase fallback. Popular tracks
  get word-level karaoke via Better Lyrics; niche tracks usually only have
  line-level LRCLIB.
- **Lyrics drift / feel late** — per-track fix via `offsets.json`, or globally
  with `GLASSY_LYRICS_OFFSET`. Make sure no other app is fighting over
  playerctl (`playerctl status` should show exactly one `Playing` player).
- **Plain text instead of big block letters** — no compatible font found;
  install a bold font (Noto CJK / DejaVu), see the list at the top of the file.

## 🧰 Development

Single-file tool, zero runtime deps beyond Pillow + playerctl. The repo
itself is the distributable folder: `glassy-lyrics` is the tool, `setup`
is the installer users run — keep both in sync when changing the tool.

## 📄 License

MIT — see [LICENSE](LICENSE).
