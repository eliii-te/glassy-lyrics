#!/usr/bin/env bash
#
# glassy-lyrics — setup wizard (self-extracting installer)
#
# This file is generated: setup-template.sh + glassy-lyrics payload.
# It installs everything glassy-lyrics needs, puts the tool on your PATH,
# verifies the install, and then DELETES ITSELF on success.
#
# Usage:  bash setup     (or:  ./setup)
# Flags:  -y / --yes     assume yes for all prompts (non-interactive)
# Env:    SETUP_SKIP_SYSTEM=1   skip package-manager steps (dev/testing only)
#
set -u

VERSION="1.6.0"
FLAG_YES=0
for a in "$@"; do
  case "$a" in
    -y|--yes) FLAG_YES=1 ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0 ;;
    *) echo "unknown option: $a (only -y/--yes is supported)" >&2; exit 2 ;;
  esac
done

# Resolve own path so extraction + self-delete work from any cwd.
SELF_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
MARKER="__GLASSY_LYRICS_PAYLOAD_7f3a__"

# ── colors (only when tty) ────────────────────────────────────────────────
if [ -t 1 ]; then
  C_G="\033[32m"; C_Y="\033[33m"; C_R="\033[31m"; C_B="\033[1m"; C_0="\033[0m"
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_0=""
fi
ok()   { printf "${C_G}  ✔${C_0} %s\n" "$*"; }
warn() { printf "${C_Y}  ⚠${C_0} %s\n" "$*"; }
fail() { printf "${C_R}  ✖${C_0} %s\n" "$*"; }
step() { printf "\n${C_B}== %s ==${C_0}\n" "$*"; }

confirm() { # $1 = question; default yes
  if [ "$FLAG_YES" = 1 ]; then
    printf "${C_B}?${C_0} %s [Y/n] -> y\n" "$1"
    return 0
  fi
  printf "${C_B}?${C_0} %s [Y/n] " "$1"
  local ans
  IFS= read -r ans || true
  case "${ans:-y}" in
    [yY]*) return 0 ;;
    *) return 1 ;;
  esac
}

banner() {
  cat <<'EOF'

   ██████╗ ██╗      █████╗ ███████╗███████╗██╗   ██╗
  ██╔════╝ ██║     ██╔══██╗██╔════╝██╔════╝╚██╗ ██╔╝
  ██║  ███╗██║     ███████║███████╗███████╗ ╚████╔╝
  ██║   ██║██║     ██╔══██║╚════██║╚════██║  ╚██╔╝
  ╚██████╔╝███████╗██║  ██║███████║███████║   ██║
   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝
EOF
  printf "  ${C_B}lyrics — setup wizard v%s${C_0}\n\n" "$VERSION"
}

# ── detection ─────────────────────────────────────────────────────────────
detect_pm() {
  if command -v pacman >/dev/null 2>&1; then PM="pacman"
  elif command -v apt-get >/dev/null 2>&1; then PM="apt"
  elif command -v dnf >/dev/null 2>&1; then PM="dnf"
  else PM=""
  fi
}

# PM package names for the four things we may need
pm_pkgs() { # $1 = what (python|pillow|playerctl|fonts|pip)
  case "$PM:$1" in
    pacman:python)   echo "python" ;;
    pacman:pillow)   echo "python-pillow" ;;
    pacman:playerctl) echo "playerctl" ;;
    pacman:fonts)    echo "ttf-dejavu" ;;
    pacman:pip)      echo "python-pip" ;;
    apt:python)      echo "python3" ;;
    apt:pillow)      echo "python3-pil" ;;
    apt:playerctl)   echo "playerctl" ;;
    apt:fonts)       echo "fonts-dejavu-core" ;;
    apt:pip)         echo "python3-pip" ;;
    dnf:python)      echo "python3" ;;
    dnf:pillow)      echo "python3-pillow" ;;
    dnf:playerctl)   echo "playerctl" ;;
    dnf:fonts)       echo "dejavu-sans-fonts" ;;
    dnf:pip)         echo "python3-pip" ;;
    *)               echo "" ;;
  esac
}

pm_install() { # pkgs...
  case "$PM" in
    pacman) sudo -n true 2>/dev/null && sudo pacman -S --needed --noconfirm "$@" || sudo pacman -S --needed "$@" ;;
    apt)    sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
  esac
}

font_present() {
  for f in \
    /usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc \
    /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc \
    /usr/share/fonts/google-noto-cjk/NotoSansCJK-Bold.ttc \
    /usr/share/fonts/TTF/DejaVuSans-Bold.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
    /usr/share/fonts/dejavu/DejaVuSans-Bold.ttf \
    /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf \
  ; do
    [ -f "$f" ] && return 0
  done
  return 1
}

has_pip() { python3 -m pip --version >/dev/null 2>&1; }
has_pil() { python3 -c "import PIL" >/dev/null 2>&1; }

# pip install --user; on PEP 668 distros (Arch/Debian 12+/Fedora 38+) retry
# with --break-system-packages — this is a user-level tool, safe here.
pip_user_install() {
  python3 -m pip install --user --quiet "$1" 2>/dev/null \
    || python3 -m pip install --user --quiet --break-system-packages "$1" 2>/dev/null \
    || return 1
}

# ── main ──────────────────────────────────────────────────────────────────
main() {
  banner
  echo "This wizard installs everything glassy-lyrics needs:"
  echo "  • system packages (python, Pillow, playerctl, fonts)"
  echo "  • optional syncedlyrics fallback (Musixmatch/NetEase)"
  echo "  • the glassy-lyrics tool itself  →  ~/.local/bin/glassy-lyrics"
  echo "On success this file deletes itself."
  echo

  # --- 1. OS sanity -------------------------------------------------------
  if [ "$(uname -s)" != "Linux" ]; then
    fail "glassy-lyrics is built for Linux (playerctl-based)."
    echo "  On macOS/BSD you would need to install playerctl yourself."
    exit 1
  fi
  detect_pm
  [ -n "$PM" ] && ok "package manager detected: $PM" || warn "no pacman/apt/dnf found — system packages must be installed manually"

  # --- 2. system packages --------------------------------------------------
  step "System dependencies"
  NEED=""
  command -v python3 >/dev/null 2>&1 || NEED="$NEED $(pm_pkgs python)"
  has_pil || NEED="$NEED $(pm_pkgs pillow)"
  command -v playerctl >/dev/null 2>&1 || NEED="$NEED $(pm_pkgs playerctl)"
  font_present || NEED="$NEED $(pm_pkgs fonts)"
  has_pip || NEED="$NEED $(pm_pkgs pip)"

  if [ -n "$NEED" ]; then
    if [ "${SETUP_SKIP_SYSTEM:-0}" = "1" ]; then
      warn "SETUP_SKIP_SYSTEM=1 — skipping system packages (dev mode)"
      warn "  still missing:${NEED}"
    elif [ -z "$PM" ]; then
      fail "missing system packages, but no supported package manager found."
      echo "  Please install manually, then re-run this wizard:"
      echo "    python3, Pillow, playerctl, a bold font (DejaVu or Noto CJK)"
      exit 1
    else
      echo "The following system packages are missing:${NEED}"
      if confirm "Install them now (needs sudo)?"; then
        if [ "$(id -u)" = "0" ]; then
          pm_install $NEED || { fail "package install failed"; exit 1; }
        elif command -v sudo >/dev/null 2>&1; then
          echo "  (sudo may ask for your password)"
          sudo -v || { fail "sudo failed — cannot install system packages"; exit 1; }
          pm_install $NEED || { fail "package install failed"; exit 1; }
        else
          fail "not root and no sudo available — install manually:"
          echo "    ${PM:+your package manager: }${NEED}"
          exit 1
        fi
        ok "system packages installed"
      else
        warn "skipped — some features may not work (big text / player detection)"
      fi
    fi
  else
    ok "python3, Pillow, playerctl, fonts, pip — all present"
  fi

  # --- 3. Pillow via pip fallback ------------------------------------------
  if ! has_pil && has_pip; then
    step "Pillow (pip fallback)"
    if confirm "Install Pillow via pip --user?"; then
      if pip_user_install pillow; then
        ok "Pillow installed"
      else
        fail "Pillow install failed — big block text will not work"
      fi
    fi
  fi

  # --- 4. optional syncedlyrics fallback ------------------------------------
  if has_pip && ! python3 -c "import syncedlyrics" >/dev/null 2>&1; then
    step "Optional: syncedlyrics fallback"
    if confirm "Install syncedlyrics (extra lyric source: Musixmatch/NetEase)?"; then
      if pip_user_install syncedlyrics; then
        ok "syncedlyrics installed"
      else
        warn "syncedlyrics install failed — LRCLIB + local LRC files still work"
      fi
    fi
  fi

  # --- 5. install the tool ---------------------------------------------------
  step "Installing glassy-lyrics"
  BIN_DIR="$HOME/.local/bin"
  CFG_DIR="$HOME/.config/glassy-lyrics"
  mkdir -p "$BIN_DIR" "$CFG_DIR/lrc"

  DEST="$BIN_DIR/glassy-lyrics"
  awk -v m="$MARKER" 'index($0,m)==1{f=1;next} f' "$SELF_PATH" > "$DEST"
  if [ ! -s "$DEST" ]; then
    fail "internal error: payload not found in $SELF_PATH"
    echo "  This looks like an unbuilt template. Run ./build-setup.sh first."
    exit 1
  fi
  chmod +x "$DEST"
  ok "installed to $DEST ($(wc -l < "$DEST") lines)"

  # --- 6. PATH ----------------------------------------------------------------
  case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *)
      RC=""
      case "${SHELL:-/bin/bash}" in
        *zsh) [ -f "$HOME/.zshrc" ] && RC="$HOME/.zshrc" || RC="$HOME/.zshrc" ;;
        *)    [ -f "$HOME/.bashrc" ] && RC="$HOME/.bashrc" || RC="$HOME/.bashrc" ;;
      esac
      if ! grep -qF "export PATH=\"\$HOME/.local/bin" "$RC" 2>/dev/null; then
        printf '\n# added by glassy-lyrics setup\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC"
        ok "added ~/.local/bin to PATH in $RC"
        echo "  → open a new terminal (or: source $RC) before running glassy-lyrics"
      fi
      ;;
  esac

  # --- 7. verify ----------------------------------------------------------------
  step "Verification"
  if "$DEST" --version 2>/dev/null | grep -q "glassy-lyrics"; then
    ok "install verified: $("$DEST" --version 2>/dev/null)"
  else
    fail "verification failed — glassy-lyrics --version did not run"
    echo "  Check that python3 and Pillow are installed, then re-run this wizard."
    exit 1
  fi

  # --- 8. done, self-delete -----------------------------------------------------
  cat <<EOF

${C_B}────────────────────────────────────────────────────────${C_0}
${C_G}Setup complete!${C_0} 🎤
  • Start Spotify, play a track, then run:  ${C_B}glassy-lyrics${C_0}
  • Config dir:       $CFG_DIR  (per-song offsets, LRC overrides)
  • Optional word-level sync: put your Spotify sp_dc cookie into
                       $CFG_DIR/sp_dc
  • Help:             glassy-lyrics --help
${C_B}────────────────────────────────────────────────────────${C_0}
EOF
  rm -f -- "$SELF_PATH"
  ok "setup file removed itself — done!"
  exit 0
}

main
