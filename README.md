# omarchy-winbar

A Windows-style taskbar for [Omarchy](https://omarchy.org/).

- **Start button** — the Omarchy mark (the square "O" from the omarchy icon
  font, glyph `U+E900`) in Omarchy green. Clicking opens the Omarchy menu.
- **Search pill** — rounded field with a drawn magnifier; clicking opens the
  apps list, where the search box already has the keyboard.
- **Centred pinned apps** — your existing dock widget, centred like Windows 11.
- **Windows-drawn tray icons** — wifi (fan of arcs + dot), speaker (cone +
  waves), battery (cell + terminal nub + charge fill), all drawn in QML rather
  than taken from an icon font, so they look right no matter which font you run.
- **Show desktop** — the `(min)` button at the far right. Clicking minimises
  everything into a hidden workspace; clicking again puts it all back.
- **Dark grey taskbar** — instead of Omarchy's near-black, at a taller height.

## Install

```bash
omarchy plugin add https://github.com/finleydavid2026-beep/omarchy-winbar.git --yes
~/.config/omarchy/plugins/winbar/install.sh
```

Taskbar chrome only, leaving your tray icons alone:

```bash
~/.config/omarchy/plugins/winbar/install.sh --no-tray
```

`--dry-run` prints what would change without touching anything.

## Uninstall

```bash
~/.config/omarchy/plugins/winbar/uninstall.sh
```

Restores `shell.json` and `shell.toml` from the backups taken at install time
and disables the plugin. The plugin directory itself is left in place — remove
it with `rm -rf ~/.config/omarchy/plugins/winbar`.

## What it changes

| File | Change |
|---|---|
| `~/.config/omarchy/shell.json` | bar layout: start, search, dock, tray, `(min)` |
| `~/.config/omarchy/shell.toml` | `bar.background`, bar height, icon slot sizes |
| `~/.config/omarchy/bar/modules/` | `winsearch.qml`, `windesktop.qml` |
| `~/.config/omarchy/bin/` | `win-show-desktop.sh` |
| `~/.config/omarchy/plugins/<you>.{network,audio,power}` | clones with drawn tray icons |

Your `shell.json` and `shell.toml` are backed up to
`~/.local/state/omarchy/` before anything is written, and re-running
`install.sh` is safe.

## How the tray icons work

Omarchy ships `omarchy.network`, `omarchy.audio` and `omarchy.power`, and they
live in `/usr/share/omarchy/` where they would be overwritten on the next
update. So instead of editing them, the installer clones each one with
`omarchy plugin clone` into your own plugin directory and swaps only the bar
button inside the clone — the glyph button becomes a drawn icon. The popover
behind the button is untouched, so clicking still opens Omarchy's own Wi-Fi
list, volume slider and battery panel.

The clone carries an `omarchy.clonedFrom` marker plus a `WINBAR-MANAGED` file,
so the installer can find and re-create it, and `--remove` can delete exactly
the clones it made.

**If an Omarchy update rewrites those widgets, the patch can stop matching.**
The installer checks before writing and tells you plainly rather than breaking
your bar — re-clone and update `tray/apply-tray.py`.

## Tweaking

- **Taskbar colour / height** — edit `[bar]` in `~/.config/omarchy/shell.toml`.
  It is watched live, so saving restyles the shell without a restart.
- **Start mark colour** — `WinStart.qml`, the `color:` on the `Text`.
- **Icon size** — `iconSize` in the dock entry in `shell.json`.
- **Reordering** — drag widgets on the bar, or use `omarchy bar move`.

## Notes

- `shell.json` hot-reloads on save, but **custom bar modules and newly
  installed icon files need `omarchy restart shell`** — Qt caches themed icon
  lookups, so an icon added while the shell runs keeps resolving to the old
  result until then.
- The `(min)` button toggles a hidden special workspace; its state lives in
  `~/.local/state/omarchy/winbar-desktop.json` and is cleared on uninstall.
