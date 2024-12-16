; getSessionId() and updateDesktopsFromRegistry() was copied from https://github.com/pmb6tz/windows-desktop-switcher
; This script depends on VirtualDesktopAccessor.dll (read more info in github)

; The script will Reload if launched while already running
#SingleInstance Force

global icon_path = "virtual_desktops.png"
Menu, Tray, Icon, %icon_path%

global MIN_DESKTOP := 1 ; always 1
global MAX_DESKTOP := 9 ; desktops count (will be calculated in updateDesktopsFromRegistry())
global USE_RING_BUFFER := 1 ; next (prev) desktop after MAX_DESKTOP (MIN_DESKTOP) is MIN_DESKTOP (MAX_DESKTOP)
global CURRENT_DESKTOP := 1
global PREV_DESKTOP := 1

getSessionId()
{
    ; https://www.autohotkey.com/docs/v1/lib/DllCall.htm
    ; Call GetCurrentProcessId() from winapi
    ; returns PID of the current script (you can see it in the task manager: AutoHotkey.exe)
    ProcessId := DllCall("GetCurrentProcessId", "UInt")

    ; https://learn.microsoft.com/en-us/windows/win32/termserv/terminal-services-sessions
    ; Call ProcessIdToSessionId() from winapi
    ; returns id of the Remote Desktop Services session associated with ProcessId to SessionId
    DllCall("ProcessIdToSessionId", "UInt", ProcessId, "UInt*", SessionId)

    return SessionId
}

; calculate MAX_DESKTOP and CURRENT_DESKTOP
; should be called before each operation with virtual desktops to update this variables
; (because user can use Win+Tab, start script not from first desktop or smth else)
updateDesktopsFromRegistry()
{
    global MAX_DESKTOP, CURRENT_DESKTOP

    ; ===[ CALCULATE MAX_DESKTOP ]===
    ; write to CurrentDesktopId current virtual desktop ID (looks like 32 chars string: "0C33B7D2CADF5C4595B894D1AD5DE990")
    RegRead CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, CurrentVirtualDesktop
    if ErrorLevel
    {
        SessionId := getSessionId()
        RegRead CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\%SessionId%\VirtualDesktops, CurrentVirtualDesktop
    }

    ; desktop ID len (usually 32)
    IDLength := StrLen(CurrentDesktopId)

    ; write to DesktopList IDs of all desktops (looks like concatenated string: "0C33B7D2CADF5C4595B894D1AD5DE990C517A4AF09B99947994A3CEB2F689D955A880704D38066499556FDB2A71EDB844F77D89A4944654EB5362E82BC28D176A987E1D278314B45BB0BF8856036FB3C")
    RegRead DesktopList, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, VirtualDesktopIDs

    DesktopListLength := StrLen(DesktopList)
    MAX_DESKTOP := floor(DesktopListLength / IDLength)

    ; ===[ CALCULATE CURRENT_DESKTOP ]===
    i := 0
    while (CurrentDesktopId and i < MAX_DESKTOP)
    {
        StartPos := (i * IDLength) + 1
        DesktopIter := SubStr(DesktopList, StartPos, IDLength)

        if (DesktopIter = CurrentDesktopId)
        {
            CURRENT_DESKTOP := i + 1
            break
        }
        ++i
    }
}

goToRightDesktop()
{
    global CURRENT_DESKTOP, PREV_DESKTOP, MIN_DESKTOP, MAX_DESKTOP

    updateDesktopsFromRegistry()

    PREV_DESKTOP := CURRENT_DESKTOP

    if (CURRENT_DESKTOP < MAX_DESKTOP)
    {    
        send {Ctrl Down}{LWin Down}{Right}{LWin Up}{Ctrl Up} ; default Windows hotkey for switching virtual desktops
        ++CURRENT_DESKTOP
    }
    else if (USE_RING_BUFFER)
    {
        goToDesktop(MIN_DESKTOP)
    }
    
    return
}

goToLeftDesktop()
{
    global CURRENT_DESKTOP, PREV_DESKTOP, MIN_DESKTOP, MAX_DESKTOP

    updateDesktopsFromRegistry()

    PREV_DESKTOP := CURRENT_DESKTOP

    if (CURRENT_DESKTOP > MIN_DESKTOP)
    {
        send {Ctrl Down}{LWin Down}{Left}{LWin Up}{Ctrl Up} ; default Windows hotkey for switching virtual desktops
        --CURRENT_DESKTOP
    }
    else if (USE_RING_BUFFER)
    {
        goToDesktop(MAX_DESKTOP)
    }
    
    return
}

goToDesktop(desktopNumber)
{
    global CURRENT_DESKTOP, PREV_DESKTOP, MIN_DESKTOP, MAX_DESKTOP

    updateDesktopsFromRegistry()

    ; save it here, because goToRightDesktop() and goToLeftDesktop() will change both: CURRENT_DESKTOP and PREV_DESKTOP
    prev := CURRENT_DESKTOP

    isMoveForward := (desktopNumber > CURRENT_DESKTOP)
    steps := abs(desktopNumber - CURRENT_DESKTOP)

    ; TODO: is there a way to move to desktop N immediately, without calling goToRightDesktop()/goToLeftDesktop() in a loop?
    while (steps)
    {
        if (isMoveForward)
        {
            goToRightDesktop()
        }
        else
        {
            goToLeftDesktop()
        }

        --steps
    }

    PREV_DESKTOP := prev
    
    return
}

; switching before last two desktops
; (for example, if we switched from desktop 2 to 5, then it will return to 2)
; WARNING! This func will work wrong if you switch desktops using Win+Tab,
; because it will not be able to get the PREV_DESKTOP value
goToPrevDesktop()
{
    global PREV_DESKTOP

    goToDesktop(PREV_DESKTOP)

    return
}

; Ctrl + n/p/o/1-9
#n::goToRightDesktop() return
#p::goToLeftDesktop() return

#o::goToPrevDesktop() return

#1::goToDesktop(1) return 
#2::goToDesktop(2) return 
#3::goToDesktop(3) return 
#4::goToDesktop(4) return 
#5::goToDesktop(5) return 
#6::goToDesktop(6) return 
#7::goToDesktop(7) return 
#8::goToDesktop(8) return 
#9::goToDesktop(9) return
; add more if you need to support more than 9 desktops