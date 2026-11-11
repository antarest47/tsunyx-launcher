# Tsunyx Launcher

A GNOME Activities-style application launcher for KDE Plasma 6: a big paginated
icon grid with live search, opened from a panel button (or a keyboard
shortcut). Built because the launchers already available for Plasma — Kicker,
Kickoff, FairyWren, etc. — are all popup/list style, and none of them give you
a full grid you can page through the way GNOME's app grid does.

This repo ships **two variants** that install side by side, sharing the same
grid/search code but with a different window:

- **Tsunyx Launcher** (`local.tsunyxlauncher`) — the original. Its background
  covers the whole screen, with the panel drawn on top of it (like GNOME's
  dash over the app grid) and the grid kept clear of the panel, and stays out of the taskbar/pager/window-switcher like any other
  launcher menu would.
- **Tsunyx Launcher (Dialog)** (`local.tsunyxdialog`) — a fixed-size
  (1490x990 physical pixels), custom-bordered floating window instead of a
  fullscreen one, for a more traditional popup-window feel. Its border is
  hand-drawn QML (matching the accent color from your active color scheme),
  not real window decoration — `PlasmaCore.Dialog`, which this variant is
  built on, can't get real decoration from KWin no matter what.

## Features

- Full-screen paginated app grid — swipe (touchpad), scroll, arrow keys, or
  the page dots to move between pages — or switch to a single continuous
  scrolling list instead, from the settings.
- Live search as you type, no need to click into a field first — results are
  grouped by category (Applications, Files, Web Bookmarks, Browser Tabs...)
  the same way KRunner groups them.
- Terminal commands, like Tsunyx Search below: if KRunner recognizes the text
  as a command, a "Run in terminal" result goes first (unless some result's
  name starts with what was typed) and runs it in a terminal that stays open
  (`terminalCommand`, default `konsole`).
- Full keyboard navigation, including across pages and search-result
  sections.
- Right-click context menu on any icon (add/remove favorite, and whatever
  actions the app itself provides).
- Open/close animation: the app icons fly out of the panel button in a wave (and back on
  close), with the dimmed, blurred background fading in and out.
- Configurable panel icon, grid icon size, and whether the grid is paginated
  or a scrolling list (Tsunyx Launcher also lets you configure the
  background dim — not applicable to the Dialog variant, which has no
  fullscreen background to dim).
- Interface localized to Spanish (falls back to English otherwise).

## Requirements

- KDE Plasma 6.0+, Qt 6.8+, on Wayland or X11.
- `msgfmt` (from `gettext`) — only needed once, to build the Spanish
  translation catalog.
- `kpackagetool6` and `kwriteconfig6` — ship with any standard Plasma 6
  install, used to install the companion KWin script (see below).

## Installing

```sh
git clone https://github.com/antarest47/tsunyx-launcher.git
cd tsunyx-launcher
./install.sh
```

This installs **both** variants: symlinks each plasmoid into
`~/.local/share/plasma/plasmoids/`, compiles and installs each Spanish
translation catalog, and installs + enables each one's companion KWin
script. Both scripts are necessary because neither launcher's window is a
normal, fully-decorated app window that KWin would handle taskbar/pager
visibility for by itself:

- Tsunyx Launcher's window never goes into exclusive fullscreen (that's
  what would otherwise cover the panel) — without its script, it would show
  up as a regular running app in the taskbar.
- Tsunyx Launcher (Dialog) is a `PlasmaCore.Dialog`, which can't position or
  correctly size itself on Wayland, and doesn't hide itself from the
  taskbar the way a fullscreen window can — its script centers it, sizes it
  to the correct physical pixels for your display's scale factor, and hides
  it from the taskbar/pager/switcher.

After running the script, add each widget to a panel by hand: right-click
the panel → **Add Widgets…** → search for "Tsunyx Launcher" (both variants
show up separately).

Only want one variant? Just don't add its widget to a panel — installing
both is harmless (a few extra symlinked files and a KWin script that never
matches any window until you actually add and open that launcher).


## Tsunyx Search (panel search box)

`local.tsunyxsearch` is a separate panel widget: a text box (with a magnifier,
like Tsunyx Launcher's search pill) that sits in the panel itself (add it next to the launcher button). Typing searches apps,
files, bookmarks, browser tabs and so on through KRunner, the same way Tsunyx
Launcher's search does, and shows the results in a popup above the box,
aligned with its left edge (arrow keys to pick, Enter to open, Escape to
clear).

If KRunner's command line runner recognizes the text as a terminal command,
Enter runs it in Konsole with zsh from the home folder (bash if zsh is
missing; since 1.13, with Uzunyx's `ZDOTDIR` if the terminal didn't set it),
and the terminal stays open afterwards in that shell. The command goes first unless some result's
name starts with what was typed, so `fire` opens Firefox while `ls -la` runs in
a terminal. The terminal and the box width are configurable (`terminalCommand`,
`fieldWidth`).

## Debian package (system-wide)

`make deb` builds `build/tsunyx-launcher_<version>_all.deb` with the original
(fullscreen) launcher and Tsunyx Search: the plasmoid in
`/usr/share/plasma/plasmoids/local.tsunyxlauncher`, the compiled Spanish
catalog in `/usr/share/locale/es/LC_MESSAGES/`, and the skip-taskbar KWin
script in `/usr/share/kwin-wayland/scripts/` (enabled by default). Needs
`msgfmt` (package `gettext`) to build. `install.sh` stays as the per-user
development install.

## Configuring

Right-click either panel button → **Configure Tsunyx Launcher…**:

- **Panel icon** — pick any icon from the system theme.
- **Icon size** — size of the app icons in the grid.
- **Background dim** — opacity of the dark overlay behind the grid
  (Tsunyx Launcher only).
- **Layout** — paginated grid (default) or a continuously-scrolling list.
- **Page dots** — show/hide the page indicator (paginated mode only).

## Uninstalling

Tsunyx Launcher:

```sh
rm ~/.local/share/plasma/plasmoids/local.tsunyxlauncher
rm ~/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxlauncher.mo
kpackagetool6 --type=KWin/Script --remove tsunyxlauncherskiptaskbar
kwriteconfig6 --file kwinrc --group Plugins --key tsunyxlauncherskiptaskbarEnabled --delete
qdbus6 org.kde.KWin /KWin reconfigure
```

Tsunyx Launcher (Dialog):

```sh
rm ~/.local/share/plasma/plasmoids/local.tsunyxdialog
rm ~/.local/share/locale/es/LC_MESSAGES/plasma_applet_local.tsunyxdialog.mo
kpackagetool6 --type=KWin/Script --remove tsunyxdialogcenter
kwriteconfig6 --file kwinrc --group Plugins --key tsunyxdialogcenterEnabled --delete
qdbus6 org.kde.KWin /KWin reconfigure
```

Then remove the corresponding widget(s) from the panel via their right-click
menu.

## License

GPL-3.0-or-later.
