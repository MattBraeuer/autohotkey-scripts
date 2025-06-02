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

; ----- HOTKEY DEFINITIONS -----

; Switch to application windows or launch them if not found
^!w:: switchToWindow("FAIR - Microsoft​ Edge", "msedge.exe", 'msedge.exe --profile-directory="Default"', true)
^!e:: switchToWindow("Personal", "msedge.exe", 'msedge.exe --profile-directory="Profile 1"', true)
^!v:: switchToWindow("Visual Studio Code", "Code.exe",
    '"C:\Users\MattB\AppData\Local\Programs\Microsoft VS Code\Code.exe"', true)
^!t:: switchToWindow("", "WindowsTerminal.exe", '"C:\Users\MattB\AppData\Local\Microsoft\WindowsApps\wt.exe"')
^!s:: switchToWindow("Slack", "slack.exe", '"C:\Users\MattB\AppData\Local\Microsoft\WindowsApps\Slack.exe"', true)
^!n:: switchToWindow("Motion", "Motion - Projects, Tasks, and Calendar.exe",
    "C:\Users\MattB\AppData\Local\Microsoft\WindowsApps\motion---projects,-tasks,-and-calendar.exe",
    true)
^!g:: switchToWindow("FAIR Consulting Group Mail", "msedge.exe",
    '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe" --profile-directory="Default" --app-id=fmgjjmmmlfnkbppncabfkddbjimcfncm --app-url=https://mail.google.com/mail/?usp=installed_webapp --app-title="Gmail" --app-launch-source=4',
    true)
^!c:: switchToWindow("Google Calendar", "msedge.exe",
    '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe" --profile-directory="Default" --app-id=kjbdgfilnfhdoflbpgamdcdgpehopbep --app-url=https://calendar.google.com/calendar/r --app-title="Google Calendar" --app-launch-source=4',
    true)
^!k:: switchToWindow("Kagi Assistant", "msedge.exe",
    '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe" --profile-directory="Profile 1" --app-id=oafeghdgfnbkcilmbhphalhjimlhkcdc --app-url=https://kagi.com/assistant --app-title="Kagi Assistant"'
)
^!j:: switchToWindow("JIRA", "msedge.exe",
    '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe" --profile-directory="Default" --app-id=ejpflhkiicffhpomkffalllpffbaggio --app-url=https://faircg.atlassian.net/jira --app-title="JIRA"'
)
^!b:: switchToWindow("Mailbird", "Mailbird.exe", '"C:\Program Files\Mailbird\Mailbird.exe"', true)

; Window management hotkeys
#!Down:: WinMinimize("A") ; Minimise the active window

; Virtual Desktop hotkeys (the ones with Right-ALT are for binding to Razer Keyboard special keys)
^#numpad0:: VD.goToDesktopNum(1)  ;Terminal
^>!numpad0:: VD.goToDesktopNum(1)  ;Terminal (Right Alt)
^#numpad1:: VD.goToDesktopNum(2)  ;Primary Desktop
^>!numpad1:: VD.goToDesktopNum(2)  ;Primary Desktop (Right Alt)
^#numpad2:: VD.goToDesktopNum(3)  ;Secondary Desktop
^>!numpad2:: VD.goToDesktopNum(3)  ;Secondary Desktop (Right Alt)
^#numpad3:: VD.goToDesktopNum(4)  ;Video Conference Desktop
^>!numpad3:: VD.goToDesktopNum(4)  ;Video Conference Desktop (Right Alt)
^#NumpadDot:: showToast(getDesktopName()) ; Show current desktop name

; Move window to desktop
#numpad1:: VD.MoveWindowToDesktopNum("A", 2)
#numpad2:: VD.MoveWindowToDesktopNum("A", 3)
#numpad3:: VD.MoveWindowToDesktopNum("A", 4)

; ----- FUNCTION DEFINITIONS -----

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
            Run(launchCommand)
        }
    }

    if (maximiseWindow) {
        ; Wait for the window to be active
        if !hwnd {
            hwnd := WinWaitActive(winCriteria, "", 10)
        }

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
    y := (A_ScreenHeight - 150) ; 100 pixels from the top

    toastGui.Show("NoActivate x" x " y" y)
    SetTimer(() => toastGui.Destroy(), duration)
}
