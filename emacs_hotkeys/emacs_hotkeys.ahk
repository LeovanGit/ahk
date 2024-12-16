; AHK cheatsheet
; ! - Alt
; + - Shift
; ^ - Ctrl
; # - Win

; TODO:
; delete\move over words: M-f M-b
; ddelete\move over paragraph
; delete\move over sentence
; hotkey to enable\disable this script
; text selection using mouse don't change is_mark_set state
; upper and lower case region (C-x C-u and C-x C-l)
; C-l

; ===========================================================================
; GLOBALS
; ===========================================================================
global icon_path := "emacs.ico"
global is_mark_set := 0

; ===========================================================================
; STARTUP SETTINGS
; ===========================================================================
Menu, Tray, Icon, %icon_path%

GroupAdd WIN_LIST, ahk_exe emacs.exe
GroupAdd WIN_LIST, ahk_exe mstsc.exe
GroupAdd WIN_LIST, ahk_exe AnyDesk.exe
GroupAdd WIN_LIST, ahk_exe Code.exe
GroupAdd WIN_LIST, ahk_exe RustClient.exe

; disable this script for windows from list
#IfWinNotActive, ahk_group WIN_LIST

; #IfWinNotActive, ahk_exe emacs.exe

; ===========================================================================
; FUNCTIONS
; ===========================================================================
moveForward()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{right}
    }
    else
    {
        send {right down}{right up}
    }
}

moveBackward()
{
    global is_mark_set
    
    if (is_mark_set)
    {
        send +{left}
    }
    else
    {
        send {left down}{left up}
    }
}

moveUp()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{up}
    }
    else
    {
        send {up down}{up up}
    }
}

moveDown()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{down}
    }
    else
    {
        send {down down}{down up}
    }
}

moveToLineBegin()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{home}
    }
    else
    {
        send {home down}{home up}
    }
}

moveToLineEnd()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{end}
    }
    else
    {
        send {end down}{end up}
    }
}

pageDown()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{PgDn}
    }
    else
    {
        send {PgDn down}{PgDn up}
    }
}

pageUp()
{
    global is_mark_set

    if (is_mark_set)
    {
        send +{PgUp}
    }
    else
    {
        send {PgUp down}{PgUp up}
    }
}

switchMark()
{
    ; mark logic is a little another than in emacs!
    global is_mark_set := !is_mark_set

    ; to deselect text
    if (!is_mark_set)
    {
        ; TODO: its always move cursor to the end of selected text
        ; but emacs don't move cursor in this case
        ; also we can use moveBackward() to move cursor to begin of selected
        moveForward()
    }
}

cutText()
{
    send ^x
    if (is_mark_set)
        switchMark()
}

copyText()
{
    send ^c
    if (is_mark_set)
        switchMark()
}

pasteText()
{
    send ^v
}

killTextToTheLineEnd()
{
    send {shift down}{end down}{end up}{shift up}{ctrl down}{c}{del}
}

undo()
{
    global is_mark_set
    if (is_mark_set)
    {
        switchMark()
    }

    send ^z
}

selectAll()
{
    send ^a
}

searchText()
{
    send ^f
}

saveFile()
{
    send ^s
}

closeFile()
{
    winclose, A
}

openFile()
{
    send ^o
}

; ===========================================================================
; HOTKEYS
; ===========================================================================
; Navigation
^f::moveForward() return
^b::moveBackward() return
^p::moveUp() return
^n::moveDown() return
^a::moveToLineBegin() return
^e::moveToLineEnd() return
^v::pageDown() return
!v::pageUp() return

; Work with Text
^space::switchMark() return
^k::killTextToTheLineEnd() return
^w::cutText() return
!w::copyText() return
^y::pasteText() return
^/::undo() return

; Work with Files
^s::searchText() return

; C-x hotkeys
$^x::
suspend on ; suspend all other hotkeys (threads)
critical ; don't suspend this hotkey (from another threads)

; traytip, ,C-x-, 10, 17

input char, L1 M T10
transform code, asc, %char%

; debug info:
; msgbox was pressed: %char% (%code%)

; for unknown reason this don't work: if(char = "^m")
; so, if was pressed ctrl + key (code <= 26, because of M option)
; we need to separate key from ctrl and add ctrl as ^
if (code <= 26)
{
    ; "C-a" code is 1
    ; "a" code is 97
    ; so, we need to add 96 to get key code
    code += 96
    transform key, chr, %code%
    hotkey = ^%key%
}
else
{
    hotkey = %char%
}

; Work with Text
if (hotkey = "h" or hotkey = "р")
    selectAll()

; Work with Files
else if (hotkey = "^s")
    saveFile()
else if (hotkey = "^c")
    closeFile()
else if (hotkey = "^f")
    openFile()

suspend off
return

; C-u
^u::
input num, L4, {Enter}{Esc}
IfInString ErrorLevel, EndKey:
{
    input str, L1000, {Enter}{Esc}
    IfInString ErrorLevel, EndKey:
    {
        while (num)
        {
            send %str%
            --num
        }
    }
}
return

