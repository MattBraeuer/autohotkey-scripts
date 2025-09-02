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

; ----- LOGGING CONSTANTS -----
class LogLevel {
    static DEBUG := 1
    static INFO := 2
    static WARN := 3
    static ERROR := 4
    static FATAL := 5
    
    static ToString(level) {
        switch level {
            case 1: return "DEBUG"
            case 2: return "INFO"
            case 3: return "WARN"
            case 4: return "ERROR"
            case 5: return "FATAL"
            default: return "UNKNOWN"
        }
    }
}

; Logging configuration
CURRENT_LOG_LEVEL := LogLevel.DEBUG  ; Set minimum log level to show
LOG_FILE_PATH := A_ScriptDir "\autohotkey.log"
LOG_TO_FILE := true
LOG_MAX_FILE_SIZE := 5242880  ; 5MB in bytes
LOG_BACKUP_COUNT := 3

; ---- FUNCTION DEFINITIONS -----

; Logging function
logMessage(level, message, showToast := false, variables := "") {
    ; Skip if below current log level
    if (level < CURRENT_LOG_LEVEL) {
        return
    }
    
    ; Format timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
    levelStr := LogLevel.ToString(level)
    
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
    if (LOG_TO_FILE) {
        try {
            ; Check file size and rotate if necessary
            if (FileExist(LOG_FILE_PATH)) {
                fileSize := FileGetSize(LOG_FILE_PATH)
                if (fileSize > LOG_MAX_FILE_SIZE) {
                    rotateLogFile()
                }
            }
            
            ; Append to log file
            FileAppend(logEntry . "`n", LOG_FILE_PATH, "UTF-8")
        } catch Error as e {
            ; If file logging fails, show error toast
            showToast("Log write failed: " . e.Message, 2000)
        }
    }
    
    ; Show toast if requested or for ERROR/FATAL levels
    if (showToast || level >= LogLevel.ERROR) {
        toastDuration := (level >= LogLevel.ERROR) ? 3000 : 1500
        showToast("[" . levelStr . "] " . message, toastDuration)
    }
}

; Log file rotation function
rotateLogFile() {
    try {
        ; Move existing backup files
        Loop LOG_BACKUP_COUNT {
            currentBackup := LOG_FILE_PATH . "." . A_Index
            nextBackup := LOG_FILE_PATH . "." . (A_Index + 1)
            
            if (A_Index == LOG_BACKUP_COUNT) {
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
        if (FileExist(LOG_FILE_PATH)) {
            FileMove(LOG_FILE_PATH, LOG_FILE_PATH . ".1", true)
        }
    } catch Error as e {
        showToast("Log rotation failed: " . e.Message, 2000)
    }
}

; Function to get all windows matching criteria
getAllMatchingWindows(winCriteria) {
    logMessage(LogLevel.DEBUG, "getAllMatchingWindows() - Entry", false, Map("winCriteria", winCriteria))
    
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
    
    logMessage(LogLevel.DEBUG, "getAllMatchingWindows() - Exit", false, Map("windowCount", windows.Length))
    return windows
}

; Function to switch to the desktop containing the specified window
switchToWindowDesktop(hwnd) {
    logMessage(LogLevel.DEBUG, "switchToWindowDesktop() - Entry", false, Map("hwnd", hwnd))
    
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
        logMessage(LogLevel.DEBUG, "switchToWindowDesktop() - Exit", false, Map("result", result, "targetDesktop", desktopOfWindow))
        return result
    }
    
    logMessage(LogLevel.DEBUG, "switchToWindowDesktop() - Exit", false, Map("result", true, "noSwitchNeeded", true))
    return true
}

; Function to cycle through windows matching criteria
cycleMatchingWindows(winCriteria, maximiseWindow := false) {
    logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Entry", false, Map("winCriteria", winCriteria, "maximiseWindow", maximiseWindow))
    
    ; Static variable to track window cycling state
    static windowCycleState := Map()
    
    windows := getAllMatchingWindows(winCriteria)
    
    if (windows.Length == 0) {
        logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "noWindows"))
        return false ; No windows found
    }
    
    ; Only one window - switch to its desktop first
    if (windows.Length == 1) {
        targetWindow := windows[1]
        if (!switchToWindowDesktop(targetWindow)) {
            logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "desktopSwitchFailed"))
            return false ; Desktop switch failed
        }
        result := activateWindow(targetWindow, maximiseWindow)
        logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", result, "singleWindow", true))
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
        logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", false, "reason", "desktopSwitchFailed"))
        return false ; Desktop switch failed
    }
    result := activateWindow(targetWindow, maximiseWindow)
    logMessage(LogLevel.DEBUG, "cycleMatchingWindows() - Exit", false, Map("result", result, "cycleIndex", cycleData.index))
    return result
}

; Function to minimize the active window with error handling
minimizeActiveWindow() {
    logMessage(LogLevel.DEBUG, "minimizeActiveWindow() - Entry")
    
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
    
    logMessage(LogLevel.DEBUG, "minimizeActiveWindow() - Exit")
}

; Function to maximize the active window with error handling
maximizeActiveWindow() {
    logMessage(LogLevel.DEBUG, "maximizeActiveWindow() - Entry")
    
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
    
    logMessage(LogLevel.DEBUG, "maximizeActiveWindow() - Exit")
}

; Function to launch an application and optionally maximize its window
launchApplication(launchCommand, winCriteria, maximiseWindow := false, exeName := "", winTitle := "") {
    logMessage(LogLevel.DEBUG, "launchApplication() - Entry", false, Map("launchCommand", launchCommand, "winCriteria", winCriteria, "maximiseWindow", maximiseWindow, "exeName", exeName, "winTitle", winTitle))
    
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

    Run(launchCommand)

    if (maximiseWindow) {
        ; Wait for the window to be active
        hwnd := WinWaitActive(winCriteria, "", 10)

        try {
            WinMaximize(hwnd)
        } catch Error as e {
            showToast(e.Message, 2000, 300) ; Show error message for 2 seconds
        }
    }
    
    logMessage(LogLevel.DEBUG, "launchApplication() - Exit", false, Map("targetDesktop", targetDesktop, "appName", appName))
}

; Function to release all modifier keys
releaseModifierKeys() {
    logMessage(LogLevel.DEBUG, "releaseModifierKeys() - Entry")
    
    Sleep(1000) ; Give time in case the user still has keys pressed
    ;Send("{Ctrl up}{Alt up}{Shift up}{LWin up}{RWin up}")
    
    logMessage(LogLevel.DEBUG, "releaseModifierKeys() - Exit")
}

; Function to activate a window and optionally maximize it
activateWindow(hwnd, maximiseWindow := false) {
    logMessage(LogLevel.DEBUG, "activateWindow() - Entry", false, Map("hwnd", hwnd, "maximiseWindow", maximiseWindow))
    
    ; Verify the window still exists before attempting to activate
    if (!WinExist("ahk_id " . hwnd)) {
        logMessage(LogLevel.DEBUG, "activateWindow() - Exit", false, Map("result", false, "reason", "windowNotFound"))
        return false
    }
    
    if (!maximiseWindow) {
        ; Minimize all windows first when NOT maximizing to show desktop background
        Send("#m")
        Sleep(100) ; Brief pause to ensure minimize completes
    }

    try {
        ; Try to activate the window with a timeout
        WinActivate("ahk_id " . hwnd)
        
        ; Wait for activation with timeout
        timeout := A_TickCount + 1000 ; 1 second timeout
        while (!WinActive("ahk_id " . hwnd) && A_TickCount < timeout) {
            Sleep(10)
        }
        
        ; Check if activation was successful
        if (!WinActive("ahk_id " . hwnd)) {
            return false
        }

        if (maximiseWindow) {
            WinMaximize("ahk_id " . hwnd)
        }
        
    } catch Error as e {
        showToast(e.Message, 2000, 300) ; Show error message for 2 seconds
        logMessage(LogLevel.DEBUG, "activateWindow() - Exit", false, Map("result", false, "error", e.Message))
        return false
    }
    
    logMessage(LogLevel.DEBUG, "activateWindow() - Exit", false, Map("result", true))
    return true
}

; Function to switch to a window or launch an application if not found
switchToWindow(winTitleSubstring, exeName, launchCommand, maximiseWindow := false) {
    logMessage(LogLevel.DEBUG, "switchToWindow() - Entry", false, Map("winTitleSubstring", winTitleSubstring, "exeName", exeName, "launchCommand", launchCommand, "maximiseWindow", maximiseWindow))
    
    winCriteria := winTitleSubstring " ahk_exe " exeName

    ; Try to cycle through matching windows first
    if (cycleMatchingWindows(winCriteria, maximiseWindow)) {
        releaseModifierKeys()
        return
    }
    
    ; No matching windows found, launch the application
    launchApplication(launchCommand, winCriteria, maximiseWindow, exeName, winTitleSubstring)
    releaseModifierKeys()
    
    logMessage(LogLevel.DEBUG, "switchToWindow() - Exit")
}

; Function to get the name of the current virtual desktop
getDesktopName() {
    logMessage(LogLevel.DEBUG, "getDesktopName() - Entry")
    
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
    
    logMessage(LogLevel.DEBUG, "getDesktopName() - Exit", false, Map("result", result, "desktopNum", num))
    return result
}

; Function to show a toast message
showToast(msg, duration := 1000, width := 150, height := 20) {
    logMessage(LogLevel.DEBUG, "showToast() - Entry", false, Map("msg", msg, "duration", duration, "width", width, "height", height))
    
    toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    toastGui.BackColor := "333333"               ; dark grey
    toastGui.SetFont("s12 cWhite", "Segoe UI")   ; white text
    toastGui.AddText("w" width " h" height " Center", msg)

    ; center on screen
    x := (A_ScreenWidth - 300) / 2
    y := (A_ScreenHeight - 150)

    toastGui.Show("NoActivate x" x " y" y)
    SetTimer(() => toastGui.Destroy(), duration)
    
    logMessage(LogLevel.DEBUG, "showToast() - Exit")
}

