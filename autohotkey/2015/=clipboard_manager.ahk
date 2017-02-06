; I tried Ditto, it was too slow.
; This is my pared-down clipboard manager, that hopefully works very quickly.
;
; NOTE: Num-lock MUST be on for this to work.

;==============================================================================
; Windows-Numpad-1:     copy current clipboard into slot#1
; Ctrl-Numpad-1:        paste the contents of slot#1
; Windows-Numpad-2:     copy current clipboard into slot#2
; Ctrl-Numpad-2:        paste the contents of slot#2
; Windows-Numpad-3:     copy current clipboard into slot#3
; Ctrl-Numpad-3:        paste the contents of slot#3
;==============================================================================

#SingleInstance force
#Persistent

SetKeyDelay, 0

#Numpad1::  Slot1 := CleanupClipboard(Clipboard)
^Numpad1::  SendRaw, %Slot1%

#Numpad2::  Slot2 := CleanupClipboard(Clipboard)
^Numpad2::  SendRaw, %Slot2%

#Numpad3::  Slot3 := CleanupClipboard(Clipboard)
^Numpad3::  SendRaw, %Slot3%

#Numpad4::  Slot4 := CleanupClipboard(Clipboard)
^Numpad4::  SendRaw, %Slot4%

#Numpad5::  Slot5 := CleanupClipboard(Clipboard)
^Numpad5::  SendRaw, %Slot5%

#Numpad6::  Slot6 := CleanupClipboard(Clipboard)
^Numpad6::  SendRaw, %Slot6%

#Numpad7::  Slot7 := CleanupClipboard(Clipboard)
^Numpad7::  SendRaw, %Slot7%

#Numpad8::  Slot8 := CleanupClipboard(Clipboard)
^Numpad8::  SendRaw, %Slot8%

#Numpad9::  Slot9 := CleanupClipboard(Clipboard)
^Numpad9::  SendRaw, %Slot9%



; make a few changes that are desirable by me    (though it's possible they're not desirable by others, or in every situation)
CleanupClipboard(clip)
{
    clip := RegExReplace(clip, "\r", "")            ; fix duplicate newlines, we only need one of "\n" and "\r" per line when Send()ing
    clip := RegExReplace(clip, "s)^([^\n]*)\n$", "$1")       ; if it's simply one line, with a newline at the end, remove the newline
    return clip
}



; In Putty, the Numpad-Enter doesn't work as a normal enter.  Fix this.
#IfWinActive ahk_class PuTTY
NumpadEnter::Send {enter}
