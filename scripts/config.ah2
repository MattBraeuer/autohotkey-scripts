#Requires AutoHotkey v2.0

; Desktop number to display name mapping.
DESKTOP_NAMES := Map(
    1, "Terminal",
    2, "Work",
    3, "Admin",
    4, "Social",
    5, "Client Workspace"
)

; ----- PATH CONSTANTS -----
USER_PROFILE := EnvGet("USERPROFILE")
MSEDGE_PROXY_PATH := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge_proxy.exe"
CHROME_PROXY_PATH := "C:\Program Files\Google\Chrome\Application\chrome_proxy.exe"
WINDOWS_APPS_PATH := USER_PROFILE "\AppData\Local\Microsoft\WindowsApps\"
LOCAL_PROGRAMS_PATH := USER_PROFILE "\AppData\Local\Programs\"
WINDOWS_APP_LAUNCHER := "explorer.exe shell:AppsFolder\"

; Application to desktop mapping configuration.
; Key format: "exeName|windowTitle" (partial title match). Value: [desktopNum, displayName]
APP_DESKTOP_MAP := Map(
    "Code.exe|Visual Studio Code", [2, "VS Code"],                    ; VS Code -> Work Desktop
    "WindowsTerminal.exe|", [1, "Windows Terminal"],                   ; Windows Terminal -> Terminal Desktop
    "warp.exe|", [2, "Warp"],                                          ; Warp -> Work Desktop
    "msedge.exe|FAIR - Microsoft​ Edge", [2, "Microsoft Edge (Work)"], ; Work Edge -> Work Desktop
    "msedge.exe|Personal", [2, "Microsoft Edge (Personal)"],          ; Personal Edge -> Work Desktop
    "chrome.exe|Google Calendar", [3, "Google Calendar"],             ; Google Calendar -> Admin Desktop
    "chrome.exe|Google Meet", [4, "Google Meet"],                     ; Google Meet -> Social Desktop
    "msedge.exe|FAIR Consulting Group Mail", [3, "Gmail"],            ; Gmail -> Admin Desktop
    "msedge.exe|Kagi Assistant", [2, "Kagi Assistant"],               ; Kagi Assistant -> Work Desktop
    "msedge.exe|JIRA", [3, "JIRA"],                                   ; JIRA -> Admin Desktop
    "msedge.exe|Rocketlane", [3, "Rocketlane"],                       ; Rocketlane -> Admin Desktop
    "slack.exe|Slack", [4, "Slack"],                                  ; Slack -> Social Desktop
    "Motion - Projects, Tasks, and Calendar.exe|Motion", [3, "Motion"], ; Motion -> Admin Desktop
    "Mailbird.exe|Mailbird", [3, "Mailbird"],                         ; Mailbird -> Admin Desktop
    "Obsidian.exe|Obsidian", [3, "Obsidian"],                         ; Obsidian -> Admin Desktop
    "Claude.exe|Claude", [2, "Claude"],                               ; Claude -> Work Desktop
    "Miro.exe|", [2, "Miro"],                                         ; Miro -> Work Desktop
    "Superhuman.exe|Superhuman", [3, "Superhuman"]                    ; Superhuman -> Admin Desktop
)

; Default/fallback PWA launch params, keyed by the winTitleSubstring used in that
; hotkey's switchToWindow() call. These are the values that already work on the
; original machine
DEFAULT_PWA_PARAMS := Map(
    "Rocketlane - Customer onboarding", { profile: "Default",   appId: "olhanhdjfagopdlkfbfikkjjddkaomni" },
    "FAIR Consulting Group Mail",       { profile: "Default",   appId: "fmgjjmmmlfnkbppncabfkddbjimcfncm" },
    "Google Calendar",                  { profile: "Default",   appId: "kjbdgfilnfhdoflbpgamdcdgpehopbep" },
    "Google Meet",                      { profile: "Default",   appId: "kjgfgldnnfoeklkmfkjfagphfepbbdan" },
    "Kagi Assistant",                   { profile: "Profile 1", appId: "oafeghdgfnbkcilmbhphalhjimlhkcdc" },
    "JIRA",                             { profile: "Default",   appId: "ejpflhkiicffhpomkffalllpffbaggio" }
)

; Per-machine overrides, keyed by A_ComputerName. Add an entry whenever a PWA's actual
; profile/app-id on that machine differs from DEFAULT_PWA_PARAMS (verified by inspecting
; %LOCALAPPDATA%\<Browser>\User Data\<Profile>\Web Applications\_crx_<app-id> folders and
; that profile's Preferences JSON). Always supply both fields even if only one differs.
PWA_MACHINE_OVERRIDES := Map(
    "NIOBE", Map(
        "Kagi Assistant",  { profile: "Default", appId: "oafeghdgfnbkcilmbhphalhjimlhkcdc" }, ; same appId, default's profile was wrong
        "Google Calendar", { profile: "Default", appId: "bfogiafebfohielmmehodmfbbebbbpei" }  ; profile OK, default's appId was wrong
    )
)
