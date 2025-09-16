#Requires AutoHotkey v2.0

;---- SETUP ----
#SingleInstance force
#WinActivateForce

ListLines(False)
SendMode("Input")
SetWorkingDir(A_ScriptDir)
KeyHistory(False)
ProcessSetPriority("H")
SetWinDelay(-1)
SetControlDelay(-1)

SetTitleMatchMode(2) ; Set title match mode to allow partial matches

; ----- IMPORT OF OTHER SCRIPTS -----
#Include %A_LineFile%\..\..\VD.ahk\VD.ah2    ; Virtual Desktop library

; ----- CONSTANT DEFINITIONS -----
USER_PROFILE := EnvGet("USERPROFILE")
MSEDGE_PROXY_PATH := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe"
WINDOWS_APPS_PATH := USER_PROFILE "\AppData\Local\Microsoft\WindowsApps\"
LOCAL_PROGRAMS_PATH := USER_PROFILE "\AppData\Local\Programs\"

; Application to desktop mapping configuration
APP_DESKTOP_MAP := Map(
    "Code.exe|Visual Studio Code", [2, "VS Code"],                    ; VS Code -> Primary Desktop
    "WindowsTerminal.exe|", [1, "Windows Terminal"],                   ; Windows Terminal -> Terminal Desktop
    "msedge.exe|FAIR - Microsoft​ Edge", [2, "Microsoft Edge (Work)"], ; Work Edge -> Primary Desktop
    "msedge.exe|Personal", [2, "Microsoft Edge (Personal)"],          ; Personal Edge -> Primary Desktop
    "msedge.exe|Google Calendar", [3, "Google Calendar"],             ; Google Calendar -> Secondary Desktop
    "msedge.exe|FAIR Consulting Group Mail", [3, "Gmail"],            ; Gmail -> Secondary Desktop
    "msedge.exe|Kagi Assistant", [2, "Kagi Assistant"],               ; Kagi Assistant -> Primary Desktop
    "msedge.exe|JIRA", [3, "JIRA"],                                   ; JIRA -> Secondary Desktop
    "slack.exe|Slack", [3, "Slack"],                                  ; Slack -> Secondary Desktop
    "Motion - Projects, Tasks, and Calendar.exe|Motion", [3, "Motion"], ; Motion -> Secondary Desktop
    "Mailbird.exe|Mailbird", [3, "Mailbird"],                         ; Mailbird -> Secondary Desktop
    "Obsidian.exe|", [3, "Obsidian"],                                 ; Obsidian -> Secondary Desktop
    "Miro.exe|", [2, "Miro"]                                          ; Miro -> Primary Desktop
)

; ----- LOGGING CLASS -----
class Log {
    ; Log level constants
    static DEBUG := 1
    static INFO := 2
    static WARN := 3
    static ERROR := 4
    static FATAL := 5
    
    ; Configuration with environment variable support
    static CURRENT_LOG_LEVEL := Log._getLogLevelFromEnv()
    static FILE_PATH := Log._getLogFilePathFromEnv()
    static TO_FILE := Log._getLogToFileFromEnv()
    static MAX_FILE_SIZE := Log._getMaxFileSizeFromEnv()
    static BACKUP_COUNT := Log._getBackupCountFromEnv()
    
    ; Static initialization - log configuration values
    static _initialized := Log._logConfiguration()
    
    ; Private methods to read configuration from environment variables
    static _getLogLevelFromEnv() {
        envLevel := EnvGet("AHK_LOG_LEVEL")
        if (envLevel != "") {
            switch StrUpper(envLevel) {
                case "DEBUG": return Log.DEBUG
                case "INFO": return Log.INFO
                case "WARN": return Log.WARN
                case "ERROR": return Log.ERROR
                case "FATAL": return Log.FATAL
                default: return Log.INFO  ; Default fallback
            }
        }
        return Log.INFO  ; Default if no environment variable
    }
    
    static _getLogFilePathFromEnv() {
        envPath := EnvGet("AHK_LOG_FILE")
        if (envPath != "") {
            return envPath
        }
        return A_ScriptDir "\autohotkey.log"  ; Default
    }
    
    static _getLogToFileFromEnv() {
        envToFile := EnvGet("AHK_LOG_TO_FILE")
        if (envToFile != "") {
            return (StrUpper(envToFile) == "TRUE" || envToFile == "1")
        }
        return true  ; Default to true to ensure logging is enabled
    }
    
    static _getMaxFileSizeFromEnv() {
        envSize := EnvGet("AHK_LOG_MAX_SIZE")
        if (envSize != "" && IsNumber(envSize)) {
            return Integer(envSize)
        }
        return 5242880  ; Default 5MB
    }
    
    static _getBackupCountFromEnv() {
        envCount := EnvGet("AHK_LOG_BACKUP_COUNT")
        if (envCount != "" && IsNumber(envCount)) {
            return Integer(envCount)
        }
        return 3  ; Default
    }
    
    ; Log configuration values after static initialization
    static _logConfiguration() {
        ; Use a simple file append for initialization logging since Log.message() isn't ready yet
        if (Log.TO_FILE) {
            try {
                timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
                configMsg := timestamp . " [INFO] Log configuration initialized:"
                configMsg .= " LEVEL=" . Log.toString(Log.CURRENT_LOG_LEVEL)
                configMsg .= " TO_FILE=" . (Log.TO_FILE ? "true" : "false")
                configMsg .= " FILE_PATH=" . Log.FILE_PATH
                configMsg .= " MAX_SIZE=" . Log.MAX_FILE_SIZE
                configMsg .= " BACKUP_COUNT=" . Log.BACKUP_COUNT
                FileAppend(configMsg . "`n", Log.FILE_PATH, "UTF-8")
            } catch Error {
                ; Silently ignore file write errors during initialization
            }
        }
        return true
    }
    
    static toString(level) {
        switch level {
            case 1: return "DEBUG"
            case 2: return "INFO"
            case 3: return "WARN"
            case 4: return "ERROR"
            case 5: return "FATAL"
            default: return "UNKNOWN"
        }
    }
    
    ; Main logging method
    static message(level, message, showToast := false, variables := "") {
        ; Skip if below current log level
        if (level < Log.CURRENT_LOG_LEVEL) {
            return
        }
        
        ; Format timestamp
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
        levelStr := Log.toString(level)
        
        ; Format variables if provided
        varStr := ""
        if (variables != "") {
            if (Type(variables) == "Map") {
                for key, value in variables {
                    varStr .= " " . key . "=" . String(value)
                }
            } else {
                varStr := " " . String(variables)
            }
        }
        
        ; Create log entry
        logEntry := timestamp . " [" . levelStr . "] " . message . varStr
        
        ; Write to file if enabled
        if (Log.TO_FILE) {
            try {
                ; Check file size and rotate if necessary
                if (FileExist(Log.FILE_PATH)) {
                    fileSize := FileGetSize(Log.FILE_PATH)
                    if (fileSize > Log.MAX_FILE_SIZE) {
                        Log.rotateFile()
                    }
                }
                
                ; Append to log file
                FileAppend(logEntry . "`n", Log.FILE_PATH, "UTF-8")
            } catch Error as e {
                ; If file logging fails, show error toast
                showToast("Log write failed: " . e.Message, 2000)
            }
        }
        
        ; Show toast if requested or for ERROR/FATAL levels
        if (showToast || level >= Log.ERROR) {
            toastDuration := (level >= Log.ERROR) ? 3000 : 1500
            showToast("[" . levelStr . "] " . message, toastDuration)
        }
    }
    
    ; File rotation method
    static rotateFile() {
        try {
            ; Move existing backup files
            Loop Log.BACKUP_COUNT {
                currentBackup := Log.FILE_PATH . "." . A_Index
                nextBackup := Log.FILE_PATH . "." . (A_Index + 1)
                
                if (A_Index == Log.BACKUP_COUNT) {
                    ; Delete oldest backup
                    if (FileExist(currentBackup)) {
                        FileDelete(currentBackup)
                    }
                } else {
                    ; Move backup file
                    if (FileExist(currentBackup)) {
                        FileMove(currentBackup, nextBackup, true)
                    }
                }
            }
            
            ; Move current log to .1 backup
            if (FileExist(Log.FILE_PATH)) {
                FileMove(Log.FILE_PATH, Log.FILE_PATH . ".1", true)
            }
        } catch Error as e {
            showToast("Log rotation failed: " . e.Message, 2000)
        }
    }
    
    ; Utility method to convert arrays to string representation
    static arrayToString(arr, separator := ", ") {
        if (Type(arr) != "Array") {
            return String(arr)
        }
        
        if (arr.Length == 0) {
            return "[]"
        }
        
        result := "["
        for index, value in arr {
            if (index > 1) {
                result .= separator
            }
            result .= String(value)
        }
        result .= "]"
        
        return result
    }
}

; ----- HOTKEY DEFINITIONS -----

; Switch to application windows or launch them if not found
^!w:: switchToWindow("FAIR - Microsoft​ Edge", "msedge.exe", 'msedge.exe --profile-directory="Default"', true)
^!e:: switchToWindow("Personal", "msedge.exe", 'msedge.exe --profile-directory="Profile 1"', true)
^!v:: switchToWindow("Visual Studio Code", "Code.exe", LOCAL_PROGRAMS_PATH "Microsoft VS Code\Code.exe", true)
^!t:: switchToWindow("", "WindowsTerminal.exe", WINDOWS_APPS_PATH "wt.exe")
^!s:: switchToWindow("Slack", "slack.exe", WINDOWS_APPS_PATH "Slack.exe", true)
^!n:: switchToWindow("Motion", "Motion - Projects, Tasks, and Calendar.exe", WINDOWS_APPS_PATH "motion---projects,-tasks,-and-calendar.exe"
)
^!g:: switchToWindow("FAIR Consulting Group Mail", "msedge.exe",
    MSEDGE_PROXY_PATH ' --profile-directory="Default" --app-id=fmgjjmmmlfnkbppncabfkddbjimcfncm --app-url=https://mail.google.com/mail/?usp=installed_webapp --app-title="Gmail" --app-launch-source=4',
    true)
^!c:: switchToWindow("Google Calendar", "msedge.exe",
    MSEDGE_PROXY_PATH ' --profile-directory="Default" --app-id=kjbdgfilnfhdoflbpgamdcdgpehopbep --app-url=https://calendar.google.com/calendar/r --app-title="Google Calendar" --app-launch-source=4',
    true)
^!k:: switchToWindow("Kagi Assistant", "msedge.exe",
    MSEDGE_PROXY_PATH ' --profile-directory="Profile 1" --app-id=oafeghdgfnbkcilmbhphalhjimlhkcdc --app-url=https://kagi.com/assistant --app-title="Kagi Assistant"'
)
^!j:: switchToWindow("JIRA", "msedge.exe",
    MSEDGE_PROXY_PATH ' --profile-directory="Default" --app-id=ejpflhkiicffhpomkffalllpffbaggio --app-url=https://faircg.atlassian.net/jira --app-title="JIRA"',
    true
)
^!b:: switchToWindow("Mailbird", "Mailbird.exe", '"C:\Program Files\Mailbird\Mailbird.exe"', true)
^!o:: switchToWindow("", "Obsidian.exe", LOCAL_PROGRAMS_PATH "Obsidian\Obsidian.exe", true)
^!m:: switchToWindow("", "Miro.exe", WINDOWS_APPS_PATH "Miro.exe", true)

; Window management hotkeys
#!Down:: minimizeActiveWindow()
#!Up:: maximizeActiveWindow()

; Virtual Desktop hotkeys (the ones with Right-ALT are for binding to Razer Keyboard special keys)
^#numpad0:: VD.goToDesktopNum(1)  ;Terminal
^>!numpad0:: VD.goToDesktopNum(1)  ;Terminal (Right Alt)
^#0:: VD.goToDesktopNum(1)  ;Terminal (standard number key)
^#numpad1:: VD.goToDesktopNum(2)  ;Primary Desktop
^>!numpad1:: VD.goToDesktopNum(2)  ;Primary Desktop (Right Alt)
^#1:: VD.goToDesktopNum(2)  ;Primary Desktop (standard number key)
^#numpad2:: VD.goToDesktopNum(3)  ;Secondary Desktop
^>!numpad2:: VD.goToDesktopNum(3)  ;Secondary Desktop (Right Alt)
^#2:: VD.goToDesktopNum(3)  ;Secondary Desktop (standard number key)
^#numpad3:: VD.goToDesktopNum(4)  ;Video Conference Desktop
^>!numpad3:: VD.goToDesktopNum(4)  ;Video Conference Desktop (Right Alt)
^#3:: VD.goToDesktopNum(4)  ;Video Conference Desktop (standard number key)
^#NumpadDot:: showToast(getDesktopName()) ; Show current desktop name
^#.:: showToast(getDesktopName()) ; Show current desktop name (standard period key)

; Move window to desktop
#numpad0:: VD.MoveWindowToDesktopNum("A", 1) ; Move active window to Terminal desktop
#numpad1:: VD.MoveWindowToDesktopNum("A", 2) ; Move active window to Primary desktop
#numpad2:: VD.MoveWindowToDesktopNum("A", 3) ; Move active window to Secondary desktop
#numpad3:: VD.MoveWindowToDesktopNum("A", 4) ; Move active window to Video Conference desktop

; ---- FUNCTION DEFINITIONS -----

; Function to get all windows matching criteria
getAllMatchingWindows(winCriteria) {
    Log.message(Log.DEBUG, "getAllMatchingWindows() - Entry", false, Map("winCriteria", winCriteria))
    
    windows := []
    
    ; Save current settings
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    bak_TitleMatchMode := A_TitleMatchMode
    
    try {
        ; Enable detection of hidden windows (windows on other desktops)
        DetectHiddenWindows true
        SetTitleMatchMode "2"
        
        ; Get all windows matching the criteria across all desktops
        windowList := WinGetList(winCriteria)
        
        for hwnd in windowList {
            ; Verify the window still exists and is valid
            if (WinExist("ahk_id " . hwnd)) {
                windows.Push(hwnd)
            }
        }
    } catch Error as e {
        ; Fallback: check only current desktop if WinGetList fails
        try {
            hwnd := WinExist(winCriteria)
            if (hwnd) {
                windows.Push(hwnd)
            }
        }
    } finally {
        ; Restore original settings
        SetTitleMatchMode bak_TitleMatchMode
        DetectHiddenWindows bak_DetectHiddenWindows
    }
    
    Log.message(Log.DEBUG, "getAllMatchingWindows() - Exit", false, Map("windowCount", windows.Length))
    return windows
}

; Function to switch to the desktop containing the specified window
switchToWindowDesktop(hwnd) {
    Log.message(Log.DEBUG, "switchToWindowDesktop() - Entry", false, Map("hwnd", hwnd))
    
    desktopOfWindow := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
    currentDesktop := VD.getCurrentDesktopNum()
    
    ; Switch to the target desktop if needed
    if (desktopOfWindow != -1 && desktopOfWindow != currentDesktop) {
        VD.goToDesktopNum(desktopOfWindow)
        ; Wait for desktop change to complete with timeout
        timeout := A_TickCount + 2000 ; 2 second timeout
        while (VD.getCurrentDesktopNum() != desktopOfWindow && A_TickCount < timeout) {
            Sleep(10)
        }
        ; Additional delay to ensure desktop switch is fully complete
        Sleep(100)
        result := (VD.getCurrentDesktopNum() == desktopOfWindow)
        Log.message(Log.DEBUG, "switchToWindowDesktop() - Exit", false, Map("result", result, "targetDesktop", desktopOfWindow))
        return result
    }
    
    Log.message(Log.DEBUG, "switchToWindowDesktop() - Exit", false, Map("result", true, "noSwitchNeeded", true))
    return true
}

; Function to cycle through windows matching criteria
cycleMatchingWindows(winCriteria, maximiseWindow := false) {
    Log.message(Log.DEBUG, "cycleMatchingWindows() - Entry", false, Map("winCriteria", winCriteria, "maximiseWindow", maximiseWindow))
    
    ; Static variable to track window cycling state
    static windowCycleState := Map()
    
    windows := getAllMatchingWindows(winCriteria)
    
    if (windows.Length == 0) {
        Log.message(Log.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "noWindows"))
        return false ; No windows found
    }
    
    ; Only one window - switch to its desktop first
    if (windows.Length == 1) {
        targetWindow := windows[1]
        if (!switchToWindowDesktop(targetWindow)) {
            Log.message(Log.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "desktopSwitchFailed"))
            return false ; Desktop switch failed
        }
        result := activateWindow(targetWindow, maximiseWindow)
        Log.message(Log.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", result, "singleWindow", true))
        return result
    }
    
    ; Multiple windows - cycle through them
    currentTime := A_TickCount
    cycleKey := winCriteria
    
    ; Initialize or get cycle state for this criteria
    if (!windowCycleState.Has(cycleKey)) {
        windowCycleState[cycleKey] := {index: 0, lastTime: 0, windows: []}
    }
    
    cycleData := windowCycleState[cycleKey]
    
    ; Reset cycle if it's been more than 5 seconds since last activation
    ; or if the window list has changed
    if (currentTime - cycleData.lastTime > 5000 || 
        cycleData.windows.Length != windows.Length) {
        cycleData.index := 0
        cycleData.windows := windows.Clone()
    } else {
        ; Move to next window in cycle
        cycleData.index := Mod(cycleData.index + 1, windows.Length)
    }
    
    ; Update last activation time
    cycleData.lastTime := currentTime
    
    ; Activate target window
    targetWindow := windows[cycleData.index + 1] ; Arrays are 1-based
    if (!switchToWindowDesktop(targetWindow)) {
        Log.message(Log.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "desktopSwitchFailed"))
        return false ; Desktop switch failed
    }
    result := activateWindow(targetWindow, maximiseWindow)
    Log.message(Log.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", result, "cycleIndex", cycleData.index))
    return result
}

; Function to minimize the active window with error handling
minimizeActiveWindow() {
    Log.message(Log.DEBUG, "minimizeActiveWindow() - Entry")
    
    try {
        hwnd := WinGetID("A")
        if (hwnd) {
            WinMinimize(hwnd)
        } else {
            showToast("No active window to minimize", 1000)
        }
    } catch Error as e {
        showToast("Failed to minimize window: " . e.Message, 2000)
    }
    
    Log.message(Log.DEBUG, "minimizeActiveWindow() - Exit")
}

; Function to maximize the active window with error handling
maximizeActiveWindow() {
    Log.message(Log.DEBUG, "maximizeActiveWindow() - Entry")
    
    try {
        hwnd := WinGetID("A")
        if (hwnd) {
            WinMaximize(hwnd)
        } else {
            showToast("No active window to maximize", 1000)
        }
    } catch Error as e {
        showToast("Failed to maximize window: " . e.Message, 2000)
    }
    
    Log.message(Log.DEBUG, "maximizeActiveWindow() - Exit")
}

; Function to launch an application and optionally maximize its window
launchApplication(launchCommand, winCriteria, maximiseWindow := false, exeName := "", winTitle := "") {
    Log.message(Log.DEBUG, "launchApplication() - Entry", false, Map("launchCommand", launchCommand, "winCriteria", winCriteria, "maximiseWindow", maximiseWindow, "exeName", exeName, "winTitle", winTitle))
    
    ; Determine target desktop for the application
    targetDesktop := 0
    appName := ""

    if (exeName) {
        ; Create compound key with exe name and window title
        compoundKey := exeName . "|" . winTitle

        if (APP_DESKTOP_MAP.Has(compoundKey)) {
            config := APP_DESKTOP_MAP[compoundKey]
            targetDesktop := config[1]
            appName := config[2]
        }
    }

    ; Switch to target desktop if configured
    if (targetDesktop > 0) {
        currentDesktop := VD.getCurrentDesktopNum()
        if (currentDesktop != targetDesktop) {
            VD.goToDesktopNum(targetDesktop)
        }
    }

    try {
        Run(launchCommand)
    } catch Error as e {
        showToast("Failed to launch: " . e.Message, 3000)
        Log.message(Log.ERROR, "launchApplication() - Launch failed", false, Map("error", e.Message, "command", launchCommand))
        return false
    }

    if (maximiseWindow) {
        ; Wait for the window to be active with error handling
        try {
            hwnd := WinWaitActive(winCriteria, "", 10)
            if (hwnd) {
                WinMaximize(hwnd)
            }
        } catch Error as e {
            showToast("Failed to maximize window: " . e.Message, 2000)
            Log.message(Log.WARN, "launchApplication() - Maximize failed", false, Map("error", e.Message))
        }
    }
    
    Log.message(Log.DEBUG, "launchApplication() - Exit", false, Map("targetDesktop", targetDesktop, "appName", appName))
    return true
}

; Function to release all modifier keys
releaseModifierKeys() {
    Log.message(Log.DEBUG, "releaseModifierKeys() - Entry")
    
    Sleep(1000) ; Give time in case the user still has keys pressed
    ;Send("{Ctrl up}{Alt up}{Shift up}{LWin up}{RWin up}")
    
    Log.message(Log.DEBUG, "releaseModifierKeys() - Exit")
}

; Function to activate a window and optionally maximize it
activateWindow(hwnd, maximiseWindow := false) {
    Log.message(Log.DEBUG, "activateWindow() - Entry", false, Map("hwnd", hwnd, "maximiseWindow", maximiseWindow))
    
    ; Verify the window still exists before attempting to activate
    if (!WinExist("ahk_id " . hwnd)) {
        Log.message(Log.DEBUG, "activateWindow() - Exit", false, Map("result", false, "reason", "windowNotFound"))
        return false
    }
    
    if (!maximiseWindow) {
        ; Minimize all windows first when NOT maximizing to show desktop background
        try {
            Send("#m")
            Sleep(100) ; Brief pause to ensure minimize completes
        } catch Error as e {
            Log.message(Log.WARN, "activateWindow() - Minimize all failed", false, Map("error", e.Message))
        }
    }

    try {
        ; Try to activate the window with a timeout
        WinActivate("ahk_id " . hwnd)
        
        ; Wait for activation with timeout
        timeout := A_TickCount + 2000 ; Increased to 2 seconds for slower systems
        while (!WinActive("ahk_id " . hwnd) && A_TickCount < timeout) {
            Sleep(50) ; Increased sleep interval to reduce CPU usage
        }
        
        ; Check if activation was successful
        if (!WinActive("ahk_id " . hwnd)) {
            Log.message(Log.WARN, "activateWindow() - Activation timeout", false, Map("hwnd", hwnd))
            return false
        }

        if (maximiseWindow) {
            WinMaximize("ahk_id " . hwnd)
        }
        
    } catch Error as e {
        showToast("Failed to activate window: " . e.Message, 2000)
        Log.message(Log.ERROR, "activateWindow() - Activation failed", false, Map("result", false, "error", e.Message))
        return false
    }
    
    Log.message(Log.DEBUG, "activateWindow() - Exit", false, Map("result", true))
    return true
}

; Function to switch to a window or launch an application if not found
switchToWindow(winTitleSubstring, exeName, launchCommand, maximiseWindow := false) {
    Log.message(Log.DEBUG, "switchToWindow() - Entry", false, Map("winTitleSubstring", winTitleSubstring, "exeName", exeName, "launchCommand", launchCommand, "maximiseWindow", maximiseWindow))
    
    winCriteria := winTitleSubstring " ahk_exe " exeName

    ; Try to cycle through matching windows first
    if (cycleMatchingWindows(winCriteria, maximiseWindow)) {
        releaseModifierKeys()
        return
    }
    
    ; No matching windows found, launch the application
    launchApplication(launchCommand, winCriteria, maximiseWindow, exeName, winTitleSubstring)
    releaseModifierKeys()
    
    Log.message(Log.DEBUG, "switchToWindow() - Exit")
}

; Function to get the name of the current virtual desktop
getDesktopName() {
    Log.message(Log.DEBUG, "getDesktopName() - Entry")
    
    ; Create a Map object (more reliable than object literals for key access)
    static names := Map()
    if !names.Count {  ; Initialize only once
        names[1] := "Terminal"
        names[2] := "Primary"
        names[3] := "Secondary"
        names[4] := "Video Conference"
    }

    ; Get current desktop number
    num := VD.getCurrentDesktopNum()

    ; Return the name if it exists, otherwise return generic name
    result := ""
    if names.Has(num)
        result := names[num]
    else
        result := "Desktop " num
    
    Log.message(Log.DEBUG, "getDesktopName() - Exit", false, Map("result", result, "desktopNum", num))
    return result
}

; Function to show a toast message
showToast(msg, duration := 1000, width := 300, height := 60) {
    Log.message(Log.DEBUG, "showToast() - Entry", false, Map("msg", msg, "duration", duration, "width", width, "height", height))
    
    try {
        toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        toastGui.BackColor := "333333"               ; dark grey
        toastGui.SetFont("s12 cWhite", "Segoe UI")   ; white text
        toastGui.AddText("w" width " h" height " Center", msg)

        ; center on screen
        x := (A_ScreenWidth - width) / 2  ; Fixed calculation using actual width
        y := (A_ScreenHeight - 150)

        toastGui.Show("NoActivate x" x " y" y)
        SetTimer(() => toastGui.Destroy(), duration)
    } catch Error as e {
        ; Fallback for toast display errors - use built-in message
        MsgBox("Toast Error: " . e.Message . "`nOriginal Message: " . msg, "AutoHotkey", "T3")
    }
    
    Log.message(Log.DEBUG, "showToast() - Exit")
}

