; Lets you peek at a window and then quickly hide it again.

;#SingleInstance force
;#Persistent
;#WinActivateForce
;#MaxThreadsPerHotkey 2      ; make quick double-taps work
;#MaxThreadsBuffer on
;#InstallKeybdHook


; we need the numlock to be on for this script to work
;SetNumLockState, AlwaysOn

; This variable (and associated statements sprinkled throughout) are necessary to avoid AHK's
; assinine way that it handles key-repeats.
; I really want to deal ONLY with onKeyDown and onKeyUp, and not have to deal with key repeat
; events.  However, AHK doesn't support this.  So I have to filter out the spurious key repeat
; events myself.
long_press_just_ended := false


Numpad1::          ; ====[ numlock on ]====
Numpad2::
Numpad3::
Numpad4::
Numpad5::
Numpad6::
Numpad7::
Numpad8::
Numpad9::


NumpadIns::         ; Numpad0       ====[ numlock off ]====
NumpadEnd::         ; Numpad1
NumpadDown::        ; Numpad2
NumpadPgDn::        ; Numpad3
NumpadLeft::        ; Numpad4
NumpadClear::       ; Numpad5
NumpadRight::       ; Numpad6
NumpadHome::        ; Numpad7
NumpadUp::          ; Numpad8
NumpadPgUp::        ; Numpad9

;Appskey::       ; AKA "menu key"
    if long_press_just_ended {
        long_press_just_ended := false
        return
    }
    long_press_just_ended := false
    KeyWait, %A_ThisHotkey%, T1       ; Wait until the key is released.
    if (ErrorLevel == 1) {
        ; the key was held down
        hwnd_%A_ThisHotkey% := WinExist("A")     ; remember what window is associated with this key
        WinGetPos, x, y, width, height, A
        ToolTip, window assigned to this hotkey, width/2, height/2
        KeyWait, %A_ThisHotkey%     ; wait until it's fully released this time
        sleep 2
        Tooltip,
        ;target_hwnd := hwnd_%A_ThisHotkey%
        ;MsgBox, hwnd_%A_ThisHotkey% = %target_hwnd%
        long_press_just_ended := true
    }
    else {
        ; the key wasn't held down
        cur_hwnd := WinExist("A")
        target_hwnd := hwnd_%A_ThisHotkey%
        ;msgbox currently focused on: %cur_hwnd%`nwant to focus on: %target_hwnd%
        if (cur_hwnd != target_hwnd) {
            WinActivate, ahk_id %target_hwnd%
            ;tooltip,raised %target_hwnd% to the top
        } else {
            ; The window is currently focused.  So we'll hide it.
            WinMinimize, ahk_id %target_hwnd%
            WinSet, Bottom, , ahk_id %target_hwnd%     ; remove it from the alt-tab order
            ;tooltip,lowered %target_hwnd% to the bottom
        }
    }
    return

