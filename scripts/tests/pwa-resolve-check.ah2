#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\default.ah2

f3::ExitApp

; Show resolved {profile, appId} for every configured PWA key on this machine
f2:: {
    lines := "Host: " A_ComputerName "`n`n"
    for pwaKey in DEFAULT_PWA_PARAMS {
        try {
            p := resolvePwaParams(pwaKey)
            lines .= pwaKey ": profile=`"" p.profile "`"  appId=" p.appId "`n"
        } catch Error as e {
            lines .= pwaKey ": ERROR - " e.Message "`n"
        }
    }
    MsgBox(lines, "PWA Param Resolution Check")
}

; Verify the fail-loud path for an unconfigured key
f1:: {
    try {
        resolvePwaParams("Nonexistent PWA")
        MsgBox("FAIL: expected an error to be thrown")
    } catch Error as e {
        MsgBox("OK - error thrown as expected:`n" e.Message)
    }
}
