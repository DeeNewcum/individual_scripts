#SingleInstance force
#Persistent

; This script has the following behavior:
;
; BOTH Escape and CapsLock are mapped to Escape.  Basically, CapsLock can't be used.
;           But I almost *never* use CapsLock, so this is okay.  The benefit of disabling it
;           completely, is that my precious Escape key will ALWAYS work, automatically, regardless
;           of whether I connect through Citrix or not.
;
;           (this script should permanently disable CapsLock...  but unfortunately that's sometimes a little glitchy)
;
; If you do a long-press of Escape or CapsLock, it will take some extra steps to ensure that
; CapsLock is disabled, and it clears the status of the left-shift and right-shift keys.


SetCapsLockState, AlwaysOff

; remap capslock to escape
    ; Capslock::Esc

$Capslock::
$Esc::
; $~Esc::
    if (A_ThisHotkey != "$~Esc") {
        IfWinActive ahk_class IMWindowClass
            return
        IfWinActive ahk_class HwndWrapper[TabbedConversations.exe`;`;01e54440-cf02-4d50-b98f-601493ef3b29]
            return
        Send {esc}
    }

    ; If the hotkey is held down for >1000ms, then reset the caps/shift keys.
    ; This is useful in case the keys are glitchy and inadvertently get stuck down.
    ThisHotkey := RegExReplace(A_ThisHotkey, "^[\$~]+", "")     ; KeyWait reacts badly to the $~ prefix
    KeyWait, %ThisHotkey%, T1         ; wait until the key is released
    if (ErrorLevel == 1) {
        ; go to great lengths to reset the CapsLock key-down status
        SetCapsLockState, On
        SetCapsLockState, Off
        SetCapsLockState, AlwaysOff
        ; reset key-down status for -- left shift
        Send, {lshift down}
        Send, {lshift up}
        ; reset key-down status for -- right shift
        Send, {rshift down}
        Send, {rshift up}
        ; indicate to the user that it was reset
        tooltip, caps/shift keys reset
        sleep, 1000
        tooltip
    }
    return






;== Office Communicator normally closes chat windows with the 'Escape' key.  Neuter this terrible behavior.
; http://bit.ly/15f4a9I
#IfWinActive ahk_class IMWindowClass
#IfWinActive ahk_class HwndWrapper[TabbedConversations.exe`;`;01e54440-cf02-4d50-b98f-601493ef3b29]
Escape::return
Capslock::return            ; sometimes this is necessary to block, because AHK is confused about whether Capslock is escape or not, due to my capslock<=>escape swapping


