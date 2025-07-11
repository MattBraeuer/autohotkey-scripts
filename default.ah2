﻿#Requires AutoHotkey v2.0

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
    "Mailbird.exe|Mailbird", [3, "Mailbird"]                         ; Mailbird -> Secondary Desktop
)

; ----- HOTKEY DEFINITIONS -----

; Switch to application windows or launch them if not found
^!w:: switchToWindow("FAIR - Microsoft​ Edge", "msedge.exe", 'msedge.exe --profile-directory="Default"', true)
^!e:: switchToWindow("Personal", "msedge.exe", 'msedge.exe --profile-directory="Profile 1"', true)
^!v:: switchToWindow("Visual Studio Code", "Code.exe", LOCAL_PROGRAMS_PATH "Microsoft VS Code\Code.exe", true)
^!t:: switchToWindow("", "WindowsTerminal.exe", WINDOWS_APPS_PATH "wt.exe")
^!s:: switchToWindow("Slack", "slack.exe", WINDOWS_APPS_PATH "Slack.exe", true)
^!n:: switchToWindow("Motion", "Motion - Projects, Tasks, and Calendar.exe", WINDOWS_APPS_PATH "motion---projects,-tasks,-and-calendar.exe",
    true)
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
    MSEDGE_PROXY_PATH ' --profile-directory="Default" --app-id=ejpflhkiicffhpomkffalllpffbaggio --app-url=https://faircg.atlassian.net/jira --app-title="JIRA"'
)
^!b:: switchToWindow("Mailbird", "Mailbird.exe", '"C:\Program Files\Mailbird\Mailbird.exe"', true)

; Window management hotkeys
#!Down:: WinMinimize("A") ; Minimise the active window
#!Up:: WinMaximize("A") ; Maximise the active window

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

; ----- FUNCTION DEFINITIONS -----

; Function to launch an application and optionally maximize its window
launchApplication(launchCommand, winCriteria, maximiseWindow := false, exeName := "", winTitle := "") {
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
}

; Function to switch to a window or launch an application if not found
switchToWindow(winTitleSubstring, exeName, launchCommand, maximiseWindow := false) {
    winCriteria := winTitleSubstring " ahk_exe " exeName

    ; Check current desktop
    hwnd := WinExist(winCriteria)

    if hwnd && WinActive(hwnd) {
        ; If the window is already active, do nothing
        return
    } else if hwnd {
        ; If the window exists but is not active, activate it
        try {
            WinActivate(hwnd)
        } catch Error as e {
            showToast(e.Message, 2000, 300) ; Show error message for 2 seconds
        }
    } else {
        ; If the window is not found, check other desktops
        desktopOfWindow := VD.getDesktopNumOfWindow(winCriteria)

        if desktopOfWindow != -1 {
            ; If the window is on another desktop, switch to that desktop
            VD.goToDesktopNum(desktopOfWindow)
            WinActivate(winCriteria)
        } else {
            ; If the window is not found, launch the application
            launchApplication(launchCommand, winCriteria, maximiseWindow, exeName, winTitleSubstring)
            return
        }
    }

    if (maximiseWindow && hwnd) {
        try {
            WinMaximize(hwnd)
        } catch Error as e {
            showToast(e.Message, 2000, 300) ; Show error message for 2 seconds
        }
    }
}

; Function to get the name of the current virtual desktop
getDesktopName() {
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
    if names.Has(num)
        return names[num]
    else
        return "Desktop " num
}

; Function to show a toast message
showToast(msg, duration := 1000, width := 150, height := 20) {
    toastGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    toastGui.BackColor := "333333"               ; dark grey
    toastGui.SetFont("s12 cWhite", "Segoe UI")   ; white text
    toastGui.AddText("w" width " h" height " Center", msg)

    ; center on screen
    x := (A_ScreenWidth - 300) / 2
    y := (A_ScreenHeight - 150)

    toastGui.Show("NoActivate x" x " y" y)
    SetTimer(() => toastGui.Destroy(), duration)
}
