# AutoHotkey Scripts with VD.ahk

This workspace contains AutoHotkey v2 scripts for window management and virtual desktop automation using the VD.ahk library.

## CRITICAL: File Modification Rules

**NEVER modify files in the `VD.ahk/` directory** - this is a third-party Git repository cloned as a dependency. Only modify files in the `autohotkey-scripts/` directory, which contains this project's own code.

## Architecture Overview

### Core Components
- **`VD.ahk/VD.ah2`**: Windows Virtual Desktop COM interface wrapper (third-party, read-only)
- **`autohotkey-scripts/config.ah2`**: User configuration — desktop name mapping, path constants, and application-to-desktop assignments (`APP_DESKTOP_MAP`)
- **`autohotkey-scripts/default.ah2`**: Main script — includes `config.ah2`, defines hotkeys, window cycling, and launch logic
- **`autohotkey-scripts/tests/`**: Test scripts for developing and validating functionality

### VD.ahk Library Patterns
The VD library wraps undocumented Windows COM interfaces for virtual desktop control:
Key methods: `goToDesktopNum()`, `MoveWindowToDesktopNum()`, `getCurrentDesktopNum()`, `getDesktopNumOfWindow()`

### Script Structure

`config.ah2` — loaded first via `#Include`, contains all user-editable configuration:
1. **Desktop Name Mapping** (`DESKTOP_NAMES`): maps desktop numbers to display names
2. **Path Constants**: `USER_PROFILE`, `MSEDGE_PROXY_PATH`, `WINDOWS_APPS_PATH`, `LOCAL_PROGRAMS_PATH`, `WINDOWS_APP_LAUNCHER`
3. **Application Desktop Mapping** (`APP_DESKTOP_MAP`): maps apps to target desktops

`default.ah2` — main script, not manually edited for configuration:
1. **Header Setup**:
   ```autohotkey
   #Requires AutoHotkey v2.0
   #SingleInstance force
   #WinActivateForce
   ListLines(False)
   SetWorkingDir(A_ScriptDir)
   ProcessSetPriority("H")
   ```
2. **Imports**: `#Include config.ah2` then `#Include VD.ahk\VD.ah2`
3. **Hotkey Definitions**: app-switch, window management, virtual desktop navigation
4. **Function Definitions**: `switchToWindow()`, `cycleMatchingWindows()`, `launchApplication()`, etc.

**Desktop Name Mapping** (in `config.ah2`):
```autohotkey
DESKTOP_NAMES := Map(
    1, "Terminal",
    2, "Primary",
    3, "Secondary",
    4, "Video Conference",
    5, "Client Workspace"
)
```

**Virtual Desktop Hotkeys** (in `default.ah2`):
- Desktop switching follows the pattern `Ctrl+Win+Numpad0-4` and `Ctrl+Win+0-4` for desktops 1-5.
- Razer-bound alternates follow the pattern `Ctrl+RightAlt+Numpad0-4` for desktops 1-5.
- Window moves follow the pattern `Win+Numpad0-4`, with `Win+Numpad4` moving the active window to `Client Workspace`.

**Application Desktop Mapping** (in `config.ah2`):
The `APP_DESKTOP_MAP` associative array defines application-to-desktop assignments. The key is a compound string of executable name and window title, and the value is an array with desktop number and optional display name.
```autohotkey
APP_DESKTOP_MAP := Map(
    "Code.exe|Visual Studio Code", [2, "VS Code"],
    "msedge.exe|FAIR - Microsoft​ Edge", [2, "Microsoft Edge (Work)"]
)
```

### Launch Command Patterns
There are three types of launch commands depending on the app:

| App type | Constant | Launch command pattern |
|---|---|---|
| Classic Win32 (installed to Program Files) | — | `'"C:\Program Files\App\App.exe"'` |
| Win32 installed to LocalPrograms | `LOCAL_PROGRAMS_PATH` | `LOCAL_PROGRAMS_PATH "AppFolder\App.exe"` |
| UWP/MSIX with a direct exe alias | `WINDOWS_APPS_PATH` | `WINDOWS_APPS_PATH "app.exe"` |
| MSIX with no direct exe alias (version-stamped subfolder) | `WINDOWS_APP_LAUNCHER` | `WINDOWS_APP_LAUNCHER "PackageFamilyName!AppID"` |
| Edge PWA | `MSEDGE_PROXY_PATH` | `MSEDGE_PROXY_PATH ' --profile-directory=... --app-id=...'` |

For MSIX apps without a stable exe path (the subfolder changes with every update), **always** use `WINDOWS_APP_LAUNCHER`:
```autohotkey
WINDOWS_APP_LAUNCHER := "explorer.exe shell:AppsFolder\"
; Usage:
^!a:: switchToWindow("Claude", "Claude.exe", WINDOWS_APP_LAUNCHER "Claude_pzs8sxrjxfjjc!Claude", true)
```
The `PackageFamilyName!AppID` string can be found by running `Get-AppxPackage <AppName> | Select PackageFamilyName` in PowerShell.

### Adding A New App Shortcut (Required Workflow)
When adding a new app shortcut (for example, `Ctrl+Alt+A`), update **both** files in the same change:
1. **`autohotkey-scripts/default.ah2`**
- Add the hotkey in the hotkey section using this pattern:
    `^!<key>:: switchToWindow("<Window Title>", "<ExeName>.exe", <launchCommand>, true)`
- Use the same executable name and window-title substring that will be used in `APP_DESKTOP_MAP`.
- Choose the correct launch command pattern from the table above.
2. **`autohotkey-scripts/config.ah2`**
- Add an `APP_DESKTOP_MAP` entry with the compound key format:
    `"<ExeName>.exe|<Window Title>", [<desktopNum>, "<Display Name>"]`
- Keep the title substring aligned with `switchToWindow(...)` so desktop routing works on launch.

Shortcut change checklist (must all be true):
- A new hotkey exists in `default.ah2`.
- A matching `APP_DESKTOP_MAP` entry exists in `config.ah2`.
- The `exeName` and title substring match across both files.
- The correct launch command constant/pattern is used for the app type.
- The script has no AutoHotkey syntax problems after the change.

## Development Workflows

### Testing VD.ahk Functions
- **Read-only reference**: Study existing test scripts in `VD.ahk/notes/` for patterns, but never modify them
- Create new test scripts in `autohotkey-scripts/tests` directory only
- Use `#Include %A_ScriptDir%\..\default.ah2` to access shared functionality
- Keep test scripts minimal and focused on specific functionality
- Example test pattern for new scripts in autohotkey-scripts/tests/:
  ```autohotkey
  #Requires AutoHotkey v2.0
  #Include %A_ScriptDir%\..\default.ah2
  ; Test specific functionality
  VD.getCurrentDesktopNum()
  f3::ExitApp ; Quick exit hotkey
  ```

### Running Scripts
- AutoHotkey v2 required
- #launch.json configured for VSCode debugging
- Use `F5` in VSCode to run/debug scripts

### Window Criteria Patterns
- Use compound keys: `"exeName|windowTitle"` for precise matching
- Handle partial title matching with `SetTitleMatchMode(2)`
- Always validate window existence: `WinExist("ahk_id " . hwnd)`
- Cross-desktop window enumeration requires `DetectHiddenWindows true`

### Project-Specific Conventions
- **Method chaining**: `VD.MoveWindowToDesktopNum("A",1).follow()` pattern supported
- **Animation control**: `VD.animation_on := false` for instant desktop switching
- **Relative path imports**: Use `%A_LineFile%\..\..\` for cross-directory includes

## Key Integration Points

### Virtual Desktop Event Handling
```autohotkey
VD.RegisterDesktopNotifications()
VD.DefineProp("CurrentVirtualDesktopChanged", {Call:CurrentVirtualDesktopChanged})
CurrentVirtualDesktopChanged(desktopNum_Old, desktopNum_New) {
    ; Handle desktop change events
}
```

