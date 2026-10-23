#!/usr/bin/env bash
# Remove the Windows-style taskbar and put Omarchy's stock bar back.
#
#   ./uninstall.sh

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$(eval echo ~"$USER")"
OMARCHY_CONFIG="$HOME_DIR/.config/omarchy"
BAR_MODULES="$OMARCHY_CONFIG/bar/modules"
BIN_DIR="$OMARCHY_CONFIG/bin"
BACKUP="$HOME_DIR/.local/state/omarchy/winbar-backup.json"
TOML_BACKUP="$HOME_DIR/.local/state/omarchy/winbar-shell.toml.bak"

say() { printf '  %s\n' "$*"; }

# ------------------------------------------------------- 1. bar modules + bin
say "removing bar modules"
rm -f "$BAR_MODULES/winsearch.qml" "$BAR_MODULES/windesktop.qml"
rmdir "$BAR_MODULES" 2>/dev/null || true
rm -f "$BIN_DIR/win-show-desktop.sh"

# -------------------------------------------------------------- 2. tray icons
say "removing Windows-drawn tray icons"
# Capture the clone ids before deleting them: the fallback below needs them to
# strip the right entries out of shell.json.
TRAY_IDS=()
while IFS= read -r m; do
  TRAY_IDS+=("$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["id"])' "$m")")
done < <(grep -rl "WINBAR-MANAGED" "$OMARCHY_CONFIG/plugins"/*/manifest.json 2>/dev/null)
python3 "$REPO/tray/apply-tray.py" --remove || say "  (nothing to remove)"

# ---------------------------------------------------------------- 3. plugin
say "disabling plugin"
omarchy plugin disable winbar 2>/dev/null || true

# ------------------------------------------------------------- 4. shell.json
say "restoring shell.json"
if [[ -f "$BACKUP" ]]; then
  cp "$BACKUP" "$OMARCHY_CONFIG/shell.json"
  say "  restored from $BACKUP"
else
  # No backup: strip the entries we added and fall back to Omarchy's defaults.
  python3 - "$OMARCHY_CONFIG/shell.json" "${TRAY_IDS[@]}" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
tray_ids = set(sys.argv[2:])
ours = {"omarchy.winbar", "winsearch", "windesktop"} | tray_ids
cfg = json.loads(path.read_text())
for section in ("left", "center", "right"):
    entries = cfg.get("bar", {}).get("layout", {}).get(section, [])
    kept = [e for e in entries if not (isinstance(e, dict) and e.get("id") in ours)]
    cfg["bar"]["layout"][section] = kept
cfg["bar"]["centerAnchor"] = "omarchy.clock"
cfg["bar"]["transparent"] = True
path.write_text(json.dumps(cfg, indent=2) + "\n")
print("    entries removed (no backup found)")
PY
fi

# -------------------------------------------------------------- 5. shell.toml
say "restoring shell.toml"
if [[ -f "$TOML_BACKUP" ]]; then
  cp "$TOML_BACKUP" "$OMARCHY_CONFIG/shell.toml"
  say "  restored from $TOML_BACKUP"
else
  say "  no backup; leaving shell.toml as-is"
fi

# ------------------------------------------------------------- 6. app state
rm -f "$HOME_DIR/.local/state/omarchy/winbar-desktop.json"

say "applying"
for i in 1 2 3 4 5; do omarchy-shell shell reloadConfig && break; sleep 1; done
for i in 1 2 3 4 5; do omarchy restart shell && break; sleep 1; done

cat <<EOF

Removed. Omarchy's stock bar is back.

If you also want the plugin itself gone:
  rm -rf "$OMARCHY_CONFIG/plugins/winbar"
EOF
