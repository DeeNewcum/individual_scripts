;@echo off
;rem This header is actually DOS commands, allowing this script to run on computers that don't have AutoHotkey setup completely.
;start "title" "%CDI_APPDRIVE%\source\Business\AutoHotkey-1-0-48-05\R1\Program Files\AutoHotkey\AutoHotkey.exe" %0 %*
;GOTO:eof



; Sometimes our group chat is really chatty.
;
; This provides one key (Pause) that you can tap once to show the group chat, and
; tap again to hide the group chat, letting you quickly get back to work if the message wasn't for
; you.
;
; Pressing the Pause key *only* affects the group chat window, it doesn't do anything with
; other IM windows.
;
; This is also a quick way to clear the window's flashing state, in cases where you're busy with
; something else, and can't pay attention to the group chat right that moment.  Press Pause twice.



; TODO:
;       - if no group chat is found, pop a message saying so
;       - release this to the group, since it's fairly useful


#SingleInstance force
#Persistent
#InstallKeybdHook
#WinActivateForce
            ; ^^ Sometimes switching away actually causes it to flash again.  This command fixes that problem.


Pause::
; Media_Play_Pause::                          ; on my keyboard at home, the 'Pause' key requires two keys to be pressed, while media forward/play/back are only one key
NumpadDot::
NumpadDel::
    hwnd := FindGroupChatWindow()
    if (hwnd > 0) {
        IfWinActive ahk_id %hwnd%       ; if the group-chat is already focused, then pressing the key again hides it
        {
            WinMinimize, ahk_id %hwnd%
            WinSet, Bottom, , ahk_id %hwnd%     ; remove it from the alt-tab order
            KeyWait,NumpadSub
            return
        } else {
            WinActivate, ahk_id %hwnd%
        }
    }
    return





FindGroupChatWindow()
{
    ;SetTitleMatchMode, 2
    ;IfWinExist, AO - DIST CHAT ahk_class IMWindowClass
        ;return WinExist("")     ; return the hwnd of the last-found window


    ; look through all chat windows, find the one that seems most likely to be the group chat
    WinGet, hwnds, list,,, ahk_class IMWindowClass
    best_window := -1
    best_window_score := 0
    Loop, %hwnds%
    {
        this_score := ChatWindowScore(hwnds%A_Index%)
        if (this_score > best_window_score) {
            best_window := hwnds%A_Index%
            best_window_score := this_score
        }
    }

    return best_window
}


; Calculate a heuristic score that estimates the likelihood that this particular chat window is the AO group chat window.
ChatWindowScore(hwnd)
{
    score := 0
    WinGetTitle, this_title, ahk_id %hwnd%

    ; number of participants
    if (RegExMatch(this_title, "(\d+) Participants", Captured)) {
        score := score + Captured1
    }

    ; has the title been changed?
    if (not Instr(this_title, "Group Conversation")) {      ; and have changed the title
        score := score * 1.1
    }

    ; does the title start with "AO", or contain the word "dist"?
    if (RegExMatch(this_title, "i)^AO|dist")) {
        score := score * 1.5
    }

    ; does the title include the word "BED", "FED", "BEN", or "FEN"?
    if (RegExMatch(this_title, "\b[FB]E[DN]\b")) {
        score := score * 1.5
    }

    return score
}
