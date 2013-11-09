; Things I always want to be running.


#SingleInstance force
#Persistent


; Windows+V -- parse clipboard as plaintext         (the same that Ctrl-Shift-V does in a few applications, but this works everywhere)
#v::
    _clipboard := Clipboard
    _clipboard := RegExReplace(_clipboard, "\r", "")
    _clipboard := RegExReplace(_clipboard, "s)^([^\n]*)\n+$", "$1")     ; If it's just a single line, trim off the newline(s) from the end
    if (RegExMatch(_clipboard, "s)^[^\n]*$")) {
        _clipboard := RegExReplace(_clipboard, "\s+$", "")      ; If it's just a single line, trim off the spaces from the end
    }
    SendRaw, %_clipboard%
    Return


