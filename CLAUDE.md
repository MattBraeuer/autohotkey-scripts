# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

This is a single git repository. The AutoHotkey scripts live under `scripts/`:

- **`scripts/`** — the actual project.
- **`scripts/VD.ahk/`** — a third-party library (virtual desktop COM interface wrapper for AutoHotkey v2), included as a **git submodule** of `https://github.com/FuPeiJiang/VD.ahk`, pinned to the `v2_port` branch. **NEVER modify files here.** Treat it as read-only reference/vendor code. Run `git submodule update --init --recursive` after cloning.

There is no build, lint, or automated test command — these are AutoHotkey v2 hotkey scripts run directly by the AutoHotkey interpreter (see "Running Scripts" below).

## Architecture

- **`scripts/VD.ahk/VD.ah2`** — third-party Windows Virtual Desktop COM wrapper. Key methods used throughout this project: `goToDesktopNum()`, `MoveWindowToDesktopNum()`, `getCurrentDesktopNum()`, `getDesktopNumOfWindow()`, `goToRelativeDesktopNum()`, `RegisterDesktopNotifications()`.
- **`scripts/config.ah2`** — user-editable configuration, `#Include`d first by `default.ah2`. Contains:
  1. `DESKTOP_NAMES` — Map of desktop number → display name
  2. Path constants — `USER_PROFILE`, `MSEDGE_PROXY_PATH`, `CHROME_PROXY_PATH`, `WINDOWS_APPS_PATH`, `LOCAL_PROGRAMS_PATH`, `WINDOWS_APP_LAUNCHER`
  3. `APP_DESKTOP_MAP` — Map from compound key `"exeName|windowTitleSubstring"` to `[desktopNum, displayName]`, used to route an app to a specific virtual desktop
- **`scripts/default.ah2`** — main script. `#Include config.ah2` then `#Include VD.ahk\VD.ah2`. Defines all hotkeys and the core functions: `switchToWindow()`, `cycleMatchingWindows()`, `getAllMatchingWindows()`, `switchToWindowDesktop()`, `launchApplication()`, `activateWindow()`, `getDesktopName()`, `showToast()`.
- **`scripts/tests/`** — scratch scripts for developing/validating functionality against `default.ah2`.

### Core hotkey pattern

App-switch hotkeys call `switchToWindow(winTitleSubstring, exeName, launchCommand, maximiseWindow?)`, which:
1. Builds `winCriteria := winTitleSubstring " ahk_exe " exeName`
2. Tries `cycleMatchingWindows()` — if any matching windows exist (across all virtual desktops, via `DetectHiddenWindows`), switches to that window's desktop and activates it, cycling through duplicates on repeated presses within a 5s window
3. If no window is found, calls `launchApplication()`, which looks up `exeName|winTitleSubstring` in `APP_DESKTOP_MAP` to pre-switch to the app's target desktop before running `launchCommand`

Virtual desktop switching hotkeys (`Ctrl+Win+Numpad0-4` / `Ctrl+Win+0-4`, with Razer alternates on `Ctrl+RightAlt+Numpad0-4`) call `VD.goToDesktopNum()` directly. Window-move hotkeys (`Win+Numpad0-4`) call `VD.MoveWindowToDesktopNum("A", n)`.

### Launch command patterns

Which path constant to use depends on how the target app is installed:

| App type | Constant | Pattern |
|---|---|---|
| Classic Win32 (Program Files) | — | `'"C:\Program Files\App\App.exe"'` |
| Win32 in LocalPrograms | `LOCAL_PROGRAMS_PATH` | `LOCAL_PROGRAMS_PATH "AppFolder\App.exe"` |
| UWP/MSIX with a direct exe alias | `WINDOWS_APPS_PATH` | `WINDOWS_APPS_PATH "app.exe"` |
| MSIX with no stable exe alias (version-stamped subfolder) | `WINDOWS_APP_LAUNCHER` | `WINDOWS_APP_LAUNCHER "PackageFamilyName!AppID"` |
| Edge PWA | `MSEDGE_PROXY_PATH` | `MSEDGE_PROXY_PATH ' --profile-directory=... --app-id=... --app-url=... --app-title="..." --app-launch-source=4'` |
| Chrome PWA | `CHROME_PROXY_PATH` | same shape as Edge PWA |

For MSIX apps without a stable exe path, always use `WINDOWS_APP_LAUNCHER "PackageFamilyName!AppID"`. Find the `PackageFamilyName` via `Get-AppxPackage <AppName> | Select PackageFamilyName` in PowerShell.

## Adding a New App Shortcut

A skill exists for this: `.claude/skills/add-app-shortcut-hotkey/SKILL.md`. When adding a `Ctrl+Alt+<key>` app shortcut, both files must be updated **in the same change**:

1. **`scripts/default.ah2`** — add `^!<key>:: switchToWindow("<Window Title>", "<ExeName>.exe", <launchCommand>, true)` in the hotkey section.
2. **`scripts/config.ah2`** — add a matching `APP_DESKTOP_MAP` entry: `"<ExeName>.exe|<Window Title>", [<desktopNum>, "<Display Name>"]`.

The `exeName` and window-title substring must match exactly between the two files, or desktop routing on launch silently fails. Verify the hotkey isn't already bound before adding it.

## Running Scripts

- Requires AutoHotkey v2.
- VSCode is configured for the `ahk2` debugger (`.vscode/launch.json`) — press `F5` to run/debug the currently open script.
- New test scripts belong in `scripts/tests/` and should `#Include %A_ScriptDir%\..\default.ah2` to reuse shared functionality, then define a minimal hotkey (e.g. `f3::ExitApp`) for quick exit.
- Study `scripts/VD.ahk/notes/` for VD.ahk usage examples, but never edit files there.

## Conventions

- `SetTitleMatchMode(2)` is set globally — window title matches are always partial/substring matches.
- Cross-desktop window enumeration requires `DetectHiddenWindows true` (see `getAllMatchingWindows()`).
- Always verify a window still exists before acting on a cached hwnd: `WinExist("ahk_id " . hwnd)`.
- VD.ahk supports method chaining, e.g. `VD.MoveWindowToDesktopNum("A", 1).follow()`.
- `VD.animation_on := false` disables the virtual desktop switch animation for instant switching.
