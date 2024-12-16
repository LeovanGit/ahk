; This script use functions from VirtualDesktopAccessor.dll

; Some code was copied from:
; https://github.com/pmb6tz/windows-desktop-switcher
; https://github.com/Ciantic/VirtualDesktopAccessor
; https://github.com/sdias/win-10-virtual-desktop-enhancer

#SingleInstance Force ; The script will Reload if launched while already running
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases
#KeyHistory 0 ; Ensures user privacy when debugging is not needed
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability
SetKeyDelay, 75

global icon_path = "virtual_desktops.png"
Menu, Tray, Icon, %icon_path%

hVirtualDesktopAccessor := DllCall("LoadLibrary", "Str", A_ScriptDir . "\VirtualDesktopAccessor.dll", "Ptr")
global GoToDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GoToDesktopNumber", "Ptr")
global IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")

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

getTopWindowOnCurrentDesktop()
{
    ; crutch: we switch focus to the taskbar before desktop switching,
    ; so it will be the first in windowsIDList, so we need to return second one window from windowsIDList
    ; (not first like mentioned below)
    WinActivate, ahk_class Shell_TrayWnd

    ; https://ahk-wiki.ru/winget#:~:text=%D0%BE%D0%BA%D0%BE%D0%BD%20(%D0%BA%D0%BE%D0%BC%D0%B0%D0%BD%D0%B4%D0%B0%20DetectHiddenWindows).-,List.,-%D0%92%D0%BE%D0%B7%D0%B2%D1%80%D0%B0%D1%89%D0%B0%D0%B5%D1%82%20ID%20%D0%B2%D1%81%D0%B5%D1%85
    ; windowsIDList contains IDs of all windows in OS (access via windowsIDList1, windowsIDList2, ...)
    ; also they are ordered from the top to the bottom for each desktop (so we can take first ID on desired Desktop)
    WinGet windowsIDList, list

    ; windowsIDList is array length
    Loop %windowsIDList%
    {
        ; %A_Index% is iterator (from 1 to %windowsIDList%)
        windowID := windowsIDList%A_Index%

        isWindowOnCurrentDesktop := DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, windowID)

        ; found top window on current Desktop
        if (isWindowOnCurrentDesktop == 1)
            ; return next window after it (because of crutch)
            nextIndex := A_Index + 1
            return windowsIDList%nextIndex%
    }
}

; WARNING! This func will work wrong if you switch desktops using Win+Tab
; TODO: Can work wrong because of non-trivial background processes (like NVidia Share.exe)
; maybe WinGet Transparent/ExStyle can solve this problem
focusTopWindowOnCurrentDesktop()
{
    topWindowID := getTopWindowOnCurrentDesktop()

    ; for debug:
    ; WinGet name, ProcessName, ahk_id %topWindowID%
    ; MsgBox, %name%

    ; https://ahk-wiki.ru/winget#:~:text=%D0%B4%D0%BE%D0%BB%D0%B6%D0%B5%D0%BD%20%D0%B1%D1%8B%D1%82%D1%8C%20%D0%BB%D0%BE%D0%BA%D0%B0%D0%BB%D1%8C%D0%BD%D1%8B%D0%BC).-,MinMax,-.%20%D0%9E%D0%BF%D1%80%D0%B5%D0%B4%D0%B5%D0%BB%D1%8F%D0%B5%D1%82%20%D1%81%D0%BE%D1%81%D1%82%D0%BE%D1%8F%D0%BD%D0%B8%D0%B5%20%D0%BE%D0%BA%D0%BD%D0%B0
    ; windowState:
    ; -1 window is minimized
    ;  1 window is maximized
    ;  0 window is not minimized and not maximized
    WinGet windowState, MinMax, ahk_id %topWindowID%

    if windowState != -1:
        WinActivate, ahk_id %topWindowID%
}

goToDesktop(desktopNumber)
{
    global CURRENT_DESKTOP, PREV_DESKTOP

    updateDesktopsFromRegistry()

    PREV_DESKTOP := CURRENT_DESKTOP

    ; https://github.com/pmb6tz/windows-desktop-switcher/pull/19#:~:text=Can%20you%20explain%20this%20change%20a%20bit%3F%20I%20don%27t%20quite%20understand%20how%20this%20alone%20improves%20performance%3F
    ; focus taskbar before switching (increase switch speed and fix some bugs, read more by the link above):
    WinActivate, ahk_class Shell_TrayWnd

    ; call GoToDesktopNumberProc() from VirtualDesktopAccessor.dll:
    DllCall(GoToDesktopNumberProc, Int, desktopNumber - 1)

    focusTopWindowOnCurrentDesktop()

    return
}

goToRightDesktop()
{
    global CURRENT_DESKTOP, MIN_DESKTOP, MAX_DESKTOP

    updateDesktopsFromRegistry()

    if (CURRENT_DESKTOP < MAX_DESKTOP) 
        goToDesktop(CURRENT_DESKTOP + 1)
    else if (USE_RING_BUFFER)
        goToDesktop(MIN_DESKTOP)
    
    return
}

goToLeftDesktop()
{
    global CURRENT_DESKTOP, MIN_DESKTOP, MAX_DESKTOP

    updateDesktopsFromRegistry()

    if (CURRENT_DESKTOP > MIN_DESKTOP)
        goToDesktop(CURRENT_DESKTOP - 1)
    else if (USE_RING_BUFFER)
        goToDesktop(MAX_DESKTOP)
    
    return
}

; WARNING! This func will work wrong if you switch desktops using Win+Tab,
; because it will not be able to get the PREV_DESKTOP value
returnToPrevDesktop()
{
    global PREV_DESKTOP

    goToDesktop(PREV_DESKTOP)

    return
}

; Ctrl + n/p/o/1-9
#n::goToRightDesktop() return
#p::goToLeftDesktop() return

#o::returnToPrevDesktop() return

; TODO: we can replace this lines with a loop
;generateHotkeys()
;{
;    Loop 9
;    {
;        fn := goToDesktop.Bind(A_Index)
;        Hotkey("^#Numpad" A_Index, fn, "On")
;    }
;}
#1::goToDesktop(1) return 
#2::goToDesktop(2) return 
#3::goToDesktop(3) return 
#4::goToDesktop(4) return 
#5::goToDesktop(5) return 
#6::goToDesktop(6) return 
#7::goToDesktop(7) return 
#8::goToDesktop(8) return 
#9::goToDesktop(9) return
