---
name: add-app-shortcut-hotkey
description: 'Add a new Ctrl+Alt app shortcut to AutoHotkey scripts by updating default.ah2 and config.ah2 together. Use when adding switchToWindow hotkeys, choosing launcher command type (WindowsApps, LocalPrograms, Windows App Launcher, Edge app, Chrome app), deriving default exe names, and keeping APP_DESKTOP_MAP aligned.'
argument-hint: 'shortcut key, app window name, fullscreen yes/no, launcher type, app id (for Edge/Chrome), desktop number, optional display name'
---

# Add App Shortcut Hotkey

Create or update a shortcut that follows this project pattern:

- Hotkey format: `Ctrl+Alt+<alphanumeric key>`
- Action: switch to an existing app window, otherwise launch it
- Required consistency: update both files in one change

Files this skill updates:

- `scripts/default.ah2`
- `scripts/config.ah2`

Never modify:

- `scripts/VD.ahk/` (third-party dependency)

## When To Use

Use this skill when you need a new app shortcut that:

- Adds a `^!<key>:: switchToWindow(...)` binding
- Chooses one of the supported launcher path patterns
- Keeps desktop-routing behavior by adding `APP_DESKTOP_MAP` entry
- Avoids mismatched `exeName` / `windowTitle` between files

## Inputs

Primary parameters:

- `shortcutKey`: single alphanumeric key used in `^!<key>`
- `windowName`: title substring used for matching windows
- `fullscreen`: `true` or `false` for the `maximiseWindow` argument

Additional required decision inputs:

- `launcherType`: one of
  - `WINDOWS_APPS_PATH`
  - `LOCAL_PROGRAMS_PATH`
  - `WINDOWS_APP_LAUNCHER`
  - `MSEDGE_PROXY_PATH`
  - `CHROME_PROXY_PATH`
- `desktopNumber`: target desktop number for `APP_DESKTOP_MAP`

Conditional inputs:

- `appId`: required for `MSEDGE_PROXY_PATH` and `CHROME_PROXY_PATH`. Feeds `DEFAULT_PWA_PARAMS` in `config.ah2`, not the hotkey line directly.
- `profileDirectory`: optional for Edge/Chrome apps, default `Default`. Also feeds `DEFAULT_PWA_PARAMS`, not the hotkey line directly.
- `displayName`: optional friendly name for `APP_DESKTOP_MAP`

## Default Exe Name Derivation

Use this order to derive `exeName`:

1. `MSEDGE_PROXY_PATH` -> `msedge.exe`
2. `CHROME_PROXY_PATH` -> `chrome.exe`
3. `WINDOWS_APPS_PATH` -> basename of exe path, preserving case if known
   - Example: `WINDOWS_APPS_PATH "Slack.exe"` -> `Slack.exe`
4. `LOCAL_PROGRAMS_PATH` -> basename of exe path
   - Example: `LOCAL_PROGRAMS_PATH "Obsidian\Obsidian.exe"` -> `Obsidian.exe`
5. `WINDOWS_APP_LAUNCHER` -> default to `<windowNameNoSpaces>.exe`, then verify against running process name if available
   - Example: `windowName = "Claude"` -> `Claude.exe`

If confidence is low (especially Windows App Launcher), ask for override before writing.

## Launcher Command Construction

Construct `launchCommand` by `launcherType`:

1. `WINDOWS_APPS_PATH`
    - Format: `WINDOWS_APPS_PATH "<exeAlias>.exe"`

2. `LOCAL_PROGRAMS_PATH`
    - Format: `LOCAL_PROGRAMS_PATH "<Folder>\<Exe>.exe"`

3. `WINDOWS_APP_LAUNCHER`
    - Format: `WINDOWS_APP_LAUNCHER "<PackageFamilyName!AppID>"`

4. `MSEDGE_PROXY_PATH`
    - Format:
      `buildPwaLaunchCommand(MSEDGE_PROXY_PATH, "<windowName>", "<derivedUrl>", "<windowName>")`

5. `CHROME_PROXY_PATH`
    - Format:
      `buildPwaLaunchCommand(CHROME_PROXY_PATH, "<windowName>", "<derivedUrl>", "<windowName>")`

`profileDirectory` and `appId` are never embedded as literals in the hotkey line. They live in `config.ah2`'s `DEFAULT_PWA_PARAMS` map (see step below), and `buildPwaLaunchCommand()` (defined in `default.ah2`) resolves them per-machine at call time via `resolvePwaParams()`.

## URL Derivation For Edge/Chrome Apps

Derive URL using a deterministic fallback sequence:

1. If there is an existing hotkey with the same `appId`, reuse its `--app-url`.
2. If there is an existing hotkey with the same `windowName`, reuse that URL.
3. Infer from `windowName` keyword map:
   - contains `calendar` -> `https://calendar.google.com/calendar/r`
   - contains `mail` or `gmail` -> `https://mail.google.com/mail/?usp=installed_webapp`
   - contains `jira` -> `https://faircg.atlassian.net/jira`
   - contains `rocketlane` -> `https://psa.faircg.com`
4. If still unknown, stop and ask user for URL (do not guess beyond known mappings).

## Procedure

1. Validate inputs
    - Ensure `shortcutKey` is a single alphanumeric char.
    - Ensure hotkey `^!<key>` is not already used in `default.ah2`.
    - Confirm `desktopNumber` is valid in `DESKTOP_NAMES` map.

2. Derive normalized values
    - Compute `exeName` using derivation rules.
    - Set `titleSubstring = windowName`.
    - Set `maximiseWindow = fullscreen`.
    - Build `launchCommand` by launcher type.

3. Update `scripts/default.ah2`
    - Add:
      `^!<key>:: switchToWindow("<windowName>", "<exeName>", <launchCommand>, <maximiseWindow>)`
    - Keep style consistent with surrounding multi-line formatting where needed.

4. If `launcherType` is `MSEDGE_PROXY_PATH` or `CHROME_PROXY_PATH`, update `scripts/config.ah2`'s `DEFAULT_PWA_PARAMS`
    - Add map entry:
      `"<windowName>", { profile: "<profileDirectory>", appId: "<appId>" }`
    - Required for any Edge/Chrome launcher type — do not skip even if the value is only known to be correct on one machine for now. If a given machine's actual profile/app-id ever differs, that's handled separately via a `PWA_MACHINE_OVERRIDES["<A_ComputerName>"]` entry, not by editing this default.

5. Update `scripts/config.ah2`'s `APP_DESKTOP_MAP`
    - Add map entry:
      `"<exeName>|<windowName>", [<desktopNumber>, "<displayName>"]`
    - If `displayName` omitted, default to `windowName`.

6. Consistency checks
    - `exeName` in `switchToWindow` matches map key.
    - `windowName`/title substring matches map key, and matches the key used in `DEFAULT_PWA_PARAMS` (if applicable).
    - Launcher constant matches chosen app type.

7. Validation
    - Confirm AutoHotkey syntax remains valid.
    - Confirm no edits outside `scripts/`.
    - Summarize final inserted lines in both files.

## Decision Branches

- If hotkey exists:
  - Offer replacement key options; do not overwrite silently.
- If launcher type is Edge/Chrome and `appId` missing:
  - Block and request `appId`.
- If `windowName` already exists as a key in `DEFAULT_PWA_PARAMS` with a different `appId`/`profileDirectory` than the one supplied:
  - Confirm before overwriting; do not silently replace an existing (possibly machine-tuned) entry.
- If launcher type is `WINDOWS_APP_LAUNCHER` and package id missing:
  - Block and request `PackageFamilyName!AppID`.
- If URL cannot be derived confidently for Edge/Chrome:
  - Request URL explicitly.

## Examples From This Repository

1. Local Programs app (VS Code style)
    - Hotkey pattern in `default.ah2`:
      `^!v:: switchToWindow("Visual Studio Code", "Code.exe", LOCAL_PROGRAMS_PATH "Microsoft VS Code\Code.exe", true)`
    - Matching map entry in `config.ah2`:
      `"Code.exe|Visual Studio Code", [2, "VS Code"]`

2. WindowsApps exe alias (Slack style)
    - Hotkey:
      `^!s:: switchToWindow("Slack", "slack.exe", WINDOWS_APPS_PATH "Slack.exe")`
    - Map:
      `"slack.exe|Slack", [3, "Slack"]`

3. Windows App Launcher (Claude style)
    - Hotkey:
      `^!a:: switchToWindow("Claude", "Claude.exe", WINDOWS_APP_LAUNCHER "Claude_pzs8sxrjxfjjc!Claude", false)`
    - Map:
      `"Claude.exe|Claude", [2, "Claude"]`

4. Edge app (Rocketlane style)
    - Hotkey:
      `^!r:: switchToWindow("Rocketlane - Customer onboarding", "msedge.exe", buildPwaLaunchCommand(MSEDGE_PROXY_PATH, "Rocketlane - Customer onboarding", "https://psa.faircg.com", "Rocketlane"), true)`
    - `DEFAULT_PWA_PARAMS` entry:
      `"Rocketlane - Customer onboarding", { profile: "Default", appId: "olhanhdjfagopdlkfbfikkjjddkaomni" }`
    - `APP_DESKTOP_MAP` entry:
      `"msedge.exe|Rocketlane - Customer onboarding", [3, "Rocketlane"]`

5. Chrome app (Google Calendar style)
    - Hotkey:
      `^!c:: switchToWindow("Google Calendar", "chrome.exe", buildPwaLaunchCommand(CHROME_PROXY_PATH, "Google Calendar", "https://calendar.google.com/calendar/r", "Google Calendar"), true)`
    - `DEFAULT_PWA_PARAMS` entry:
      `"Google Calendar", { profile: "Default", appId: "kjbdgfilnfhdoflbpgamdcdgpehopbep" }`
    - `APP_DESKTOP_MAP` entry:
      `"chrome.exe|Google Calendar", [3, "Google Calendar"]`

## Completion Checklist

- New hotkey exists in `default.ah2`.
- Matching `APP_DESKTOP_MAP` entry exists in `config.ah2`.
- For Edge/Chrome apps: matching `DEFAULT_PWA_PARAMS` entry exists in `config.ah2`, and the hotkey calls `buildPwaLaunchCommand(...)` rather than embedding `profile-directory`/`app-id` literals.
- `exeName` and title substring align exactly across both files.
- Correct launcher constant/pattern used.
- Syntax and behavior validated.
