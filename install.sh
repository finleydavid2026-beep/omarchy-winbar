#!/usr/bin/env bash
# Install the Windows-style taskbar for Omarchy.
#
#   ./install.sh              full install (taskbar + Windows-drawn tray icons)
#   ./install.sh --no-tray    taskbar chrome only, leave the tray icons alone
#   ./install.sh --dry-run    show what would change, change nothing
#
# Safe to re-run: it backs up shell.json and shell.toml first, and the tray
# clones are re-created rather than duplicated.

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$(eval echo ~"$USER")"
OMARCHY_CONFIG="$HOME_DIR/.config/omarchy"
BAR_MODULES="$OMARCHY_CONFIG/bar/modules"
BIN_DIR="$OMARCHY_CONFIG/bin"
BACKUP="$HOME_DIR/.local/state/omarchy/winbar-backup.json"
TOML_BACKUP="$HOME_DIR/.local/state/omarchy/winbar-shell.toml.bak"

WITH_TRAY=1
DRY_RUN=0
HOTBAR="${WINBAR_HOTBAR:-greyforge.hotbar}"
for arg in "$@"; do
  case "$arg" in
    --no-tray) WITH_TRAY=0 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "install.sh: unknown argument '$arg'" >&2; exit 2 ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
die()  { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
run()  { if (( DRY_RUN )); then printf '    would run: %s\n' "$*"; else "$@"; fi; }

# The shell's IPC socket occasionally refuses a connection right after a
# plugin is added or a config is rewritten; retry rather than fail.
retry() {
  local tries=0
  until "$@"; do
    tries=$(( tries + 1 ))
    (( tries >= 5 )) && return 1
    say "  (retrying: $*)"
    sleep 1
  done
  return 0
}

for cmd in omarchy omarchy-shell; do
  command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' not found — is Omarchy installed?"
done

# Back up first, before anything touches the config: `omarchy plugin enable`
# writes the widget into shell.json, so a backup taken later would already
# contain our own changes and uninstall would not be able to undo them.
if (( !DRY_RUN )); then
  mkdir -p "$HOME_DIR/.local/state/omarchy"
  if [[ ! -f "$BACKUP" ]]; then
    cp "$OMARCHY_CONFIG/shell.json" "$BACKUP"
    say "backed up shell.json to $BACKUP"
  else
    say "keeping existing backup $BACKUP"
  fi
  if [[ ! -f "$TOML_BACKUP" ]]; then
    cp "$OMARCHY_CONFIG/shell.toml" "$TOML_BACKUP"
    say "backed up shell.toml to $TOML_BACKUP"
  fi
fi

# ---------------------------------------------------------------- 1. modules
say "bar modules"
install -d "$BAR_MODULES" "$BIN_DIR"
for f in winsearch windesktop; do
  say "  $f.qml -> $BAR_MODULES"
  run install -m 644 "$REPO/modules/$f.qml" "$BAR_MODULES/$f.qml"
done
say "  win-show-desktop.sh -> $BIN_DIR"
run install -m 755 "$REPO/bin/win-show-desktop.sh" "$BIN_DIR/win-show-desktop.sh"

# ------------------------------------------------------------ 2. the plugin
say "plugin"
if omarchy plugin list 2>/dev/null | grep -q '^winbar'; then
  say "  winbar already installed"
else
  say "  install this repo first:  omarchy plugin add <this-repo-url> --yes"
  say "  (or run install.sh from the cloned plugin directory)"
fi
retry omarchy plugin enable winbar

# ------------------------------------------------------------ 3. bar layout
say "shell.json bar layout"
if (( !DRY_RUN )); then
  python3 - "$OMARCHY_CONFIG/shell.json" "$REPO" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
repo = pathlib.Path(sys.argv[2])
cfg = json.loads(path.read_text())

# Tray ids come from apply-tray.py via the environment.
net = __import__("os").environ.get("WINBAR_NETWORK", "omarchy.network")
aud = __import__("os").environ.get("WINBAR_AUDIO", "omarchy.audio")
pwr = __import__("os").environ.get("WINBAR_POWER", "omarchy.power")
hotbar = __import__("os").environ.get("WINBAR_HOTBAR", "greyforge.hotbar")

layout = cfg.setdefault("bar", {}).setdefault("layout", {})

# Keep the user's existing left section (workspace switcher and friends).
layout.setdefault("left", [{"id": "omarchy.workspaces"}])

# Reuse the hotbar's own entry if the user already has one, so their pins and
# matches survive the rewrite.
hotbar_entry = None
for section in ("left", "center", "right"):
    for entry in layout.get(section, []):
        if isinstance(entry, dict) and entry.get("id") == hotbar:
            hotbar_entry = entry
            break

center = [
    {"id": "winbar"},
    {"id": "winsearch", "type": "qml"},
]
if hotbar_entry is None:
    # The previous bar may have replaced the centre entirely (the macOS dock
    # does), so there is no entry to reuse. Fall back to a default one rather
    # than dropping the dock from the layout.
    hotbar_entry = {"id": hotbar}
    print("    no existing hotbar entry; using a default one")
center.append(hotbar_entry)

# Keep the user's clock if they have one, otherwise a sensible default.
clock = None
for section in ("left", "center", "right"):
    for entry in layout.get(section, []):
        if isinstance(entry, dict) and entry.get("id") == "omarchy.clock":
            clock = entry
            break
center.append(clock or {"id": "omarchy.clock", "format": "h:mm AP",
                        "formatAlt": "d MMMM 'W'ww yyyy",
                        "verticalFormat": "HH\\n\u2014\\nmm"})

layout["center"] = center
layout["right"] = [
    {"id": "omarchy.tray"},
    {"id": "omarchy.indicators"},
    {"id": net},
    {"id": aud},
    {"id": pwr},
    {"id": "windesktop", "type": "qml"},
]

cfg["bar"]["position"] = "bottom"
cfg["bar"]["transparent"] = False
cfg["bar"]["centerAnchor"] = ""

path.write_text(json.dumps(cfg, indent=2) + "\n")
print("    layout written")
PY
fi

# --------------------------------------------------------------- 4. theming
say "shell.toml (dark grey taskbar, larger bar)"
if (( !DRY_RUN )); then
  cp "$OMARCHY_CONFIG/shell.toml" "$TOML_BACKUP"
  python3 - "$OMARCHY_CONFIG/shell.toml" "$REPO/shell.toml.example" <<'PY'
import sys, pathlib

target = pathlib.Path(sys.argv[1])
example = pathlib.Path(sys.argv[2])
text = target.read_text() if target.exists() else ""

# Only add keys that are not already present, so a user's own overrides win.
for line in example.read_text().splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in stripped:
        continue
    key = stripped.split("=", 1)[0].strip()
    section = "default"
    if text:
        for existing in text.splitlines():
            s = existing.strip()
            if s.startswith("[") and s.endswith("]"):
                section = s[1:-1]
            elif "=" in s and section != "default" and s.split("=", 1)[0].strip() == key:
                break
        else:
            if f"{key} =" not in text and not any(
                l.strip().startswith(key + " =") for l in text.splitlines()
            ):
                if not text.endswith("\n"):
                    text += "\n"
                if "[bar]" not in text:
                    text += "\n[bar]\n"
                text += line + "\n"
    else:
        text += line + "\n"

target.write_text(text)
print("    shell.toml updated")
PY
fi

# ------------------------------------------------------------ 5. tray icons
if (( WITH_TRAY )); then
  say "tray icons (Windows-drawn)"
  if (( DRY_RUN )); then
    say "  would run: tray/apply-tray.py"
  else
    # apply-tray.py prints a progress line per widget and the id map as the
    # final JSON line.
    ids="$(python3 "$REPO/tray/apply-tray.py")"
    echo "$ids"
    idmap="$(printf '%s\n' "$ids" | tail -n 1)"
    export WINBAR_NETWORK="$(python3 -c "import json,sys;print(json.loads(sys.argv[1]).get('network','omarchy.network'))" "$idmap")"
    export WINBAR_AUDIO="$(python3 -c "import json,sys;print(json.loads(sys.argv[1]).get('audio','omarchy.audio'))" "$idmap")"
    export WINBAR_POWER="$(python3 -c "import json,sys;print(json.loads(sys.argv[1]).get('power','omarchy.power'))" "$idmap")"
    # The layout was written before the ids were known; rewrite it with them.
    python3 - "$OMARCHY_CONFIG/shell.json" "$WINBAR_NETWORK" "$WINBAR_AUDIO" "$WINBAR_POWER" <<'PY'
import json, sys, pathlib
path, net, aud, pwr = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
cfg = json.loads(path.read_text())
right = cfg["bar"]["layout"]["right"]
for entry in right:
    if entry.get("id") == "omarchy.network":
        entry["id"] = net
    elif entry.get("id") == "omarchy.audio":
        entry["id"] = aud
    elif entry.get("id") == "omarchy.power":
        entry["id"] = pwr
path.write_text(json.dumps(cfg, indent=2) + "\n")
print("    tray ids wired into shell.json")
PY
  fi
else
  say "tray icons skipped (--no-tray)"
fi

# --------------------------------------------------------------- 6. restart
say "applying"
retry omarchy-shell shell reloadConfig
retry omarchy restart shell

cat <<EOF

Done. Your Windows-style taskbar is live.

  start button    winbar      click opens the Omarchy menu
  search pill     winsearch           click opens the apps list
  app icons      $HOTBAR
  show desktop    windesktop          the "(min)" button at the far right

Undo with:  "$REPO/uninstall.sh"
Backups:    $BACKUP
            $TOML_BACKUP
EOF
