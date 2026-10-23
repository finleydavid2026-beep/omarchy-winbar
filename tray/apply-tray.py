#!/usr/bin/env python3
"""Install the Windows-drawn tray icons onto Omarchy's network/audio/power widgets.

Omarchy's own widgets are shipped by the omarchy package and must not be edited
in place. Instead each one is cloned into ~/.config/omarchy/plugins/ with
`omarchy plugin clone` (the supported mechanism) and only the bar button inside
the clone is swapped: the glyph BarIconButton becomes a drawn icon. The popover
behind the button is untouched, so clicking still opens Omarchy's own panel.

Usage:
    apply-tray.py            # clone (if needed) + patch all three
    apply-tray.py --check    # report which clones are patched, change nothing
    apply-tray.py --remove   # delete the clones this script created

Prints the resulting plugin ids as JSON on stdout so the caller can wire them
into shell.json.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import time
import sys
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
PLUGINS = HOME / ".config/omarchy/plugins"
REPO = Path(__file__).resolve().parent.parent
MARKER = "WINBAR-MANAGED"

# The drawn icon each widget gets, and the bar-button block that replaces the
# glyph BarIconButton. The replacement keeps the original click/wheel handlers.
WIDGETS = {
    "network": {
        "icon": "WinWifiIcon.qml",
        "block": """  // Windows-style drawn icon; replaces the glyph BarIconButton.
  Item {
    id: button
    anchors.fill: parent
    implicitWidth: Style.bar.iconSlot
    implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

    WinWifiIcon {
      anchors.centerIn: parent
      bar: root.bar
      kind: root.kind
      signalStrength: root.signalStrength
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function() {
        if (root.opened) root.close()
        else root.open()
      }
    }
  }""",
    },
    "audio": {
        "icon": "WinVolumeIcon.qml",
        "block": """  // Windows-style drawn icon; replaces the glyph BarIconButton.
  Item {
    id: button
    anchors.fill: parent
    implicitWidth: Style.bar.iconSlot
    implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

    WinVolumeIcon {
      anchors.centerIn: parent
      bar: root.bar
      hasOutput: root.hasOutput
      muted: root.outputMuted
      volume: root.outputVolume
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.toggleAllMuted()
        else root.toggle()
      }
      onWheel: function(wheel) {
        if (!root.hasOutput) return
        var steps = Util.wheelSteps(root.wheelAccumulator, wheel.angleDelta.y)
        root.wheelAccumulator = steps.remainder
        if (steps.steps === 0) return
        var volume = root.setOutputVolume(root.outputVolume + steps.steps * 0.05)
        root.showVolumeOsd(volume)
      }
    }
  }""",
    },
    "power": {
        "icon": "WinBatteryIcon.qml",
        "block": """  // Windows-style drawn icon; replaces the glyph BarIconButton.
  Item {
    id: button
    anchors.fill: parent
    implicitWidth: Style.bar.iconSlot
    implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

    WinBatteryIcon {
      anchors.centerIn: parent
      bar: root.bar
      present: root.batteryPresent
      fraction: root.batteryFraction
      charging: root.charging
      full: root.batteryFull
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (!root.batteryPresent) return
        if (mouse.button === Qt.RightButton) root.togglePercentage()
        else root.toggle()
      }
    }
  }""",
    },
}


def clone_dir(name):
    """The clone this script manages for `name`, or None."""
    for d in sorted(PLUGINS.glob(f"*.{name}")):
        manifest = d / "manifest.json"
        if not manifest.exists():
            continue
        try:
            meta = json.loads(manifest.read_text())
        except Exception:
            continue
        if meta.get("omarchy", {}).get("clonedFrom") == f"omarchy.{name}":
            if (d / MARKER).exists():
                return d
    return None


def find_clone(name):
    """Any clone of omarchy.<name> currently present, managed or not."""
    for d in sorted(PLUGINS.glob(f"*.{name}")):
        manifest = d / "manifest.json"
        if not manifest.exists():
            continue
        try:
            meta = json.loads(manifest.read_text())
        except Exception:
            continue
        if meta.get("omarchy", {}).get("clonedFrom") == f"omarchy.{name}":
            return d
    return None


def run_clone(name):
    """Clone omarchy.<name> with Omarchy's own tool and return the new dir.

    The shell's IPC socket occasionally refuses a connection right after a
    plugin is added or a config is rewritten, so retry a few times.
    """
    last = None
    for _ in range(5):
        proc = subprocess.run(["omarchy", "plugin", "clone", f"omarchy.{name}"],
                              capture_output=True, text=True)
        if proc.returncode == 0:
            break
        last = (proc.stderr or proc.stdout).strip()
        time.sleep(1)
    else:
        sys.exit(f"omarchy plugin clone omarchy.{name} failed: {last}")
    d = find_clone(name)
    if d is None:
        sys.exit(f"omarchy plugin clone omarchy.{name} did not produce a plugin directory")
    return d


def button_block_span(text):
    """Character span of the first `BarIconButton { ... }` block, or None."""
    start = text.find("BarIconButton {")
    if start < 0:
        return None
    depth = 0
    i = text.find("{", start)
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
        i += 1
    return None


def patch(panel, block):
    text = panel.read_text()
    if "WinWifiIcon" in text or "WinVolumeIcon" in text or "WinBatteryIcon" in text:
        return False, "already patched"
    span = button_block_span(text)
    if span is None:
        return False, "no BarIconButton block found"
    start, end = span
    if "id: button" not in text[start:end]:
        return False, "BarIconButton block is not the bar button"
    panel.write_text(text[:start] + block + text[end:])
    return True, "patched"


def plugin_id(d):
    return json.loads((d / "manifest.json").read_text())["id"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="report only")
    ap.add_argument("--remove", action="store_true", help="delete managed clones")
    args = ap.parse_args()

    if args.remove:
        removed = []
        for name in WIDGETS:
            d = clone_dir(name)
            if d:
                # Read the id before deleting: the manifest is inside the dir.
                label = plugin_id(d)
                shutil.rmtree(d)
                removed.append(f"{label} ({d})")
        print("removed: " + (", ".join(removed) if removed else "nothing"))
        return

    ids = {}
    for name, spec in WIDGETS.items():
        d = clone_dir(name)
        if d is None:
            existing = find_clone(name)
            if existing is not None and not args.check:
                # Reuse a clone someone made by hand, but only if unpatched.
                panel = existing / "Panel.qml"
                ok, why = patch(panel, spec["block"])
                if not ok and "already patched" not in why:
                    sys.exit(f"{existing} exists and is not patchable ({why}); "
                             f"remove it and re-run")
                d = existing
            elif existing is None and not args.check:
                d = run_clone(name)
            else:
                d = existing

        if d is None:
            print(f"  {name}: no clone present", file=sys.stderr)
            continue

        icon_src = REPO / "tray" / spec["icon"]
        if not icon_src.exists():
            sys.exit(f"missing {icon_src}")
        shutil.copy2(icon_src, d / spec["icon"])

        panel = d / "Panel.qml"
        ok, why = patch(panel, spec["block"])
        if not ok and "already patched" not in why:
            sys.exit(f"{d}/Panel.qml: {why}\n"
                     f"Omarchy changed this widget; re-clone and update the patch.")
        if not args.check:
            (d / MARKER).write_text("installed by omarchy-winbar\n")
        ids[name] = plugin_id(d)
        state = "patched" if ok else "already patched"
        print(f"  {name}: {ids[name]} -> {spec['icon']} ({state})")

    print(json.dumps(ids))


if __name__ == "__main__":
    main()
