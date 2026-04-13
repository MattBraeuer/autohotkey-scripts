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
2. **Path Constants**: `USER_PROFILE`, `MSEDGE_PROXY_PATH`, `WINDOWS_APPS_PATH`, `LOCAL_PROGRAMS_PATH`
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
    4, "Video Conference"
)
```

**Application Desktop Mapping** (in `config.ah2`):
The `APP_DESKTOP_MAP` associative array defines application-to-desktop assignments. The key is a compound string of executable name and window title, and the value is an array with desktop number and optional display name.
```autohotkey
APP_DESKTOP_MAP := Map(
    "Code.exe|Visual Studio Code", [2, "VS Code"],
    "msedge.exe|FAIR - Microsoft​ Edge", [2, "Microsoft Edge (Work)"]
)

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

