; TODO:
; ATTENTION: you should start this script on the first virtual desktop!
; After switch from WIn+Tab script can break down
; RDP takes control when connected and hotkeys stop working:
; send, {Ctrl Down}{Alt Down}{Home Down}{Home Up}{Alt Up}{Ctrl Up}

; The script will Reload if launched while already running
#SingleInstance Force

global icon_path = "virtual_desktops.png"
Menu, Tray, Icon, %icon_path%

global CURRENT_DESKTOP := 1
global MIN_DESKTOPS := 1
global MAX_DESKTOPS := 9

; next after MAX_DESKTOPS is MIN_DESKTOPS and vice versa
global IS_RING_BUFFER := 0

; ==============================================================================
; copied from https://github.com/pmb6tz/windows-desktop-switcher
; ==============================================================================
getSessionId()
{
    ProcessId := DllCall("GetCurrentProcessId", "UInt")
    if ErrorLevel
    {
        OutputDebug, Error getting current process id: %ErrorLevel%
        return
    }
    OutputDebug, Current Process Id: %ProcessId%

    DllCall("ProcessIdToSessionId", "UInt", ProcessId, "UInt*", SessionId)
    if ErrorLevel
    {
        OutputDebug, Error getting session id: %ErrorLevel%
        return
    }
    OutputDebug, Current Session Id: %SessionId%
    return SessionId
}

updateDesktopsFromRegistry()
{
    global CURRENT_DESKTOP, MAX_DESKTOPS

    IdLength := 32
    SessionId := getSessionId()
    if (SessionId)
    {
        RegRead CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, CurrentVirtualDesktop
        if ErrorLevel
        {
            RegRead CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\%SessionId%\VirtualDesktops, CurrentVirtualDesktop
        }
        
        if (CurrentDesktopId)
        {
            IdLength := StrLen(CurrentDesktopId)
        }
    }

    RegRead DesktopList, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, VirtualDesktopIDs
    if (DesktopList)
    {
        DesktopListLength := StrLen(DesktopList)
        MAX_DESKTOPS := floor(DesktopListLength / IdLength)
    }
    else
    {
        MAX_DESKTOPS := 1
    }

    i := 0
    while (CurrentDesktopId and i < MAX_DESKTOPS)
    {
        StartPos := (i * IdLength) + 1
        DesktopIter := SubStr(DesktopList, StartPos, IdLength)
        OutputDebug, The iterator is pointing at %DesktopIter% and count is %i%.

        if (DesktopIter = CurrentDesktopId)
        {
            CURRENT_DESKTOP := i + 1
            OutputDebug, Current desktop number is %CURRENT_DESKTOP% with an ID of %DesktopIter%.
            break
        }
        i++
    }
}
; ==============================================================================
; ==============================================================================
; ==============================================================================

goto_next_desktop()
{
    global CURRENT_DESKTOP, MIN_DESKTOPS, MAX_DESKTOPS

    updateDesktopsFromRegistry()

    if (CURRENT_DESKTOP < MAX_DESKTOPS)
    {    
        send {Ctrl Down}{LWin Down}{Right}{LWin Up}{Ctrl Up}
        ++CURRENT_DESKTOP
    }
    else if (IS_RING_BUFFER)
    {
        goto_desktop(MIN_DESKTOPS)
    }
    
    return
}

goto_prev_desktop()
{
    global CURRENT_DESKTOP, MIN_DESKTOPS, MAX_DESKTOPS

    updateDesktopsFromRegistry()

    if (CURRENT_DESKTOP > MIN_DESKTOPS)
    {
        send {Ctrl Down}{LWin Down}{Left}{LWin Up}{Ctrl Up}
        --CURRENT_DESKTOP
    }
    else if (IS_RING_BUFFER)
    {
        goto_desktop(MAX_DESKTOPS)
    }
    
    return
}

goto_desktop(desktop_number)
{
    global CURRENT_DESKTOP, MIN_DESKTOPS, MAX_DESKTOPS    

    updateDesktopsFromRegistry()

    ; its a little weird, but:
    ; direction := desktop_number - CURRENT_DESKTOP
    ; steps = abs(direction)
    ; don't want to work
    move_forward := (desktop_number > CURRENT_DESKTOP)
    steps := abs(desktop_number - CURRENT_DESKTOP)

    while(steps)
    {
        if (move_forward)
        {
            goto_next_desktop()
        }
        else
        {
            goto_prev_desktop()
        }

        --steps
    }
    
    return
}

#n::goto_next_desktop() return
#p::goto_prev_desktop() return

#1::goto_desktop(1) return 
#2::goto_desktop(2) return 
#3::goto_desktop(3) return 
#4::goto_desktop(4) return 
#5::goto_desktop(5) return 
#6::goto_desktop(6) return 
#7::goto_desktop(7) return 
#8::goto_desktop(8) return 
#9::goto_desktop(9) return 
