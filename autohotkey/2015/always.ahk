; Things I want to always be running.
;
; ==============================================================================
; F10          -- Bash init
; Shift-F10    -- Ksh init
; Ctrl-F10     -- homeless init
; Windows-F10  -- shell init after SU
; Alt-F10      -- .bashrc
; Ctrl-Shift-F10     -- list SUDO
;
; Windows+V    -- paste clipboard as plaintext
; Windows+A    -- toggle always-on-top
; ==============================================================================

#SingleInstance force
#Persistent
#MaxThreadsPerHotkey 1

#Include c:\src\ahk\individual_pieces\numpad_peek.ahk
    #IfWinActive
#Include c:\src\ahk\individual_pieces\escape_caps_swap.ahk
    #IfWinActive
    SetTitleMatchMode, 1


comment =
(
    set foldmethod=expr | set foldexpr=(getline(v:lnum)=~'^;==')?'>1':'=' | set foldlevel=0
)


SetKeyDelay, 0


SetCapsLockState, alwaysoff


;== Windows+V -- paste clipboard as plaintext  
#v::
    _clipboard := Clipboard
    _clipboard := RegExReplace(_clipboard, "\r", "")
    _clipboard := RegExReplace(_clipboard, "s)^([^\n]*)\n+$", "$1")       ; if it's simply one line, with a newline at the end, remove the newline
    if (RegExMatch(_clipboard, "s)^[^\n]*$")) {
        _clipboard := RegExReplace(_clipboard, "\s+$", "")          ; trim off trailing spaces, if it's only one line
    }
    SendRaw, %_clipboard%
    Return


;== Windows+A    -- toggle always-on-top
#a::    WinSet, AlwaysOnTop, Toggle, A


;== F10 -- Bash init
F10::
    if F10_documentation() {
        return
    }
    SetKeyDelay, 0
    target_window := WinExist("A")
    TargetSendRaw("######## hotkey F10 -- basic Bash initialization ########`n")
    Sleep 50
    ShInitCommon()
    TargetSendRaw("[ -z ""$BASH"" ] && (! which bash 2>/dev/null 1>/dev/null && awk 'NR==2 {exit}') || exec bash`n")
    Sleep 50
    BashInitCommon()
    TargetSendRaw("[ ""$(uname)"" == ""Linux"" ] && alias ls='ls -F --color' && export GREP_OPTIONS='--color'`n")
    return


;== BashInitCommon()
; lines that are used in both "Bash init" and ".bashrc"
BashInitCommon()
{
    sending =
( % ` LTrim
    set -o vi;  bind -m vi-insert \C-l:clear-screen;  export PS1="\[\033]0;\h -- \u -- $(uname)\007\]\[\033[102;30m\]\[\ek\${TITLE:-\h}\e\\\\\]\t $(date +%Z) \u@\h:\w \$\[\033[00m\] "
    export HISTTIMEFORMAT='%h %d %H:%M:%S  '
    alias cp='cp -i';  alias mv='mv -i';  alias rm='rm -i'
)
    SendWithNewlineDelay(50, sending)
}


;== ShInitCommon()
; lines that are used in Bash init and KSH init
ShInitCommon()
{
    sending =
( % `
which scpp >/dev/null 2>&1 || scpp() { perl -MCwd -le '$h=qx[hostname];chomp$h;$p=Cwd::abs_path shift;$ENV{USER}||=$ENV{LOGNAME};print"$ENV{USER}\@$h:$p\nscp://$ENV{USER}\@$h//$p"' "$1"; }
[ -e /home/interiot/opt/bin ] && export PATH="$PATH:/home/interiot/opt/bin"

)
    ; which scpp >/dev/null 2>&1 || scpp() { echo "${USER:-$LOGNAME}@$(hostname):$(perl -MCwd -le 'print Cwd::abs_path shift' "$1")"; }
    TargetSendRaw(sending)
; if [ ! -e "$HOME" ]; then [ -e /var/tmp/homeless.interiot ] || mkdir /var/tmp/homeless.interiot; [ -e /var/tmp/homeless.interiot ] && export HOME=/var/tmp/homeless.interiot; cd; fi 
}


;== Alt-F10 -- .bashrc
!F10::
    target_window := WinExist("A")
    SetKeyDelay, 0
    sending =
( % `
# add to .profile:
# [ -n "$PS1" -a -z "$BASH" -a -e /usr/bin/bash ] && exec /usr/bin/bash

[ -z "$PS1" ] && return
[ -f /etc/bashrc ] && . /etc/bashrc

)
    TargetSendRaw(sending)

    BashInitCommon()
    sending =
(
which less >/dev/null 2>&1 && export PAGER=less LESS=-i
if [ "$(uname)" == "Linux" ]; then
    alias ls='ls -F --color'
    export GREP_OPTIONS='--color'
else
    locate_() {  nice -n +19 find / -type f -name "$1"  2>/dev/null; }
    watch_() { while :; do clear; eval "$@"; sleep 5; done; }
fi
[[ "$(uname)" == "SunOS" && -d /usr/sfw/bin/ ]] && export PATH="/usr/sfw/bin/:$PATH"
[ -f ~/.bash_aliases ] && . ~/.bash_aliases
[ -e ~/bin/ ] && export PATH=~/bin:$PATH
[ -e ~/opt/bin/ ] && export PATH=$PATH:~/opt/bin/
[ -e ~/opt/bin/ls ] && alias ls='~/opt/bin/ls -F --color'
[ -e ~interiot/oraenv ] && eval "$(sed 's/^PERL5LIB/_perl5lib/' ~interiot/oraenv)"

# find the most capable termcap entry
for term in    xterm-256color xtermc dtterm xterm vt100
do if tput -T$term colors >/dev/null 2>/dev/null; then export TERM=$term; break; fi; done

[ "$(uname)" != "Linux" ] && alias md5sum="perl -MDigest::MD5 -le 'foreach(@ARGV){open\$fh,\$_ or next;print Digest::MD5->new->addfile(\$fh)->hexdigest,qq[  \$_]}'"

)
    TargetSendRaw(sending)

    ShInitCommon()

    sending =
(

# for ~/.sudo_bashrc, do this in Vi:
#     `%s/\~/\/home\/interiot/g

)
    TargetSendRaw(sending)

    return


;== Shift-F10 -- Ksh init
+F10::
    target_window := WinExist("A")
    SetKeyDelay, 0
    KeyWait, %A_ThisHotkey%
    Clipboard := ""     ; right now, we have a bug that causes the current contents of the clipboard
                        ; to be sometimes pasted at the very end of this...   this is bad because it
                        ; can contain passwords...  so clear the clipboard
    sending =
( % ` LTrim
    ######## hotkey shift-F10 -- basic Ksh initialization ########
    typeset -RZ2 _x1 _x2 _x3; let SECONDS=$(date '+3600*%H+60*%M+%S'); _s='(_x1=(SECONDS/3600)%24)==(_x2=(SECONDS/60)%60)==(_x3=SECONDS%60)'; TIME='"${_d[_s]}$_x1:$_x2:$_x3"'
    export HOSTNAME=$(hostname|sed 's/\..*//')
    export SHVER=$(if [ "$BASH" ]; then echo BASH; elif [ "$ERRNO" ]; then echo KSH88; elif [ "$(builtin)" ]; then echo KSH93; else echo PDKSH; fi)
    export PS1="$(printf "\033]0;${HOSTNAME} -- \${USER:-$LOGNAME} -- $(uname)\007\033k\${TITLE:-$HOSTNAME}\033\\\\\\\\\033[102;30m\${_d[_s]}\$_x1:\$_x2:\$_x3 \${USER:-$LOGNAME}@${HOSTNAME}:\${PWD} [$SHVER] $\033[0m ")"
    export COLUMNS=$(stty -a | perl -nle 'print "$1$2" if /\bcolumns (?:= )?(\d+)|(\d+) columns/')
    alias cp='cp -i'; alias mv='mv -i'; alias rm='rm -i'
    set -o vi
    ctrl_l() { if [[ ${.sh.edchar} == $'\014' ]]; then clear; eval "print -n \"$PS1${.sh.edtext}\""; .sh.edchar=$'\0'; fi; }; [ "$SHVER" = "KSH93" ] && trap ctrl_l KEYBD
    [ -r /home/interiot/opt/bin/ls ] && alias ls='/home/interiot/opt/bin/ls -F --color=auto'
    export FCEDIT=$(/usr/bin/which vi)
    unset SSH_AUTH_SOCK; unalias cd

)
    ;if [ -e /usr/bin/ksh93 ]; then exec perl -e 'exec {"/usr/bin/ksh93"} "-"'; elif [ -e /bin/ksh93 ]; then exec perl -e 'exec {"/bin/ksh93"} "-"'; fi
    ;history | perl -ne's/^\S+\s+//;print if/^###/..0' | grep -v 'history.*perl'
    ;SendWithNewlineDelay(150, sending)
    ;SendWithNewlineDelay(0, sending)
    TargetSendRaw(sending)

    ShInitCommon()
    return


;== Ctrl-F10     -- homeless init
^F10::
    target_window := WinExist("A")
    SetKeyDelay, 0
    Send,if [ -e /var/tmp/interiot_homeless/.bashrc ]`; then export HOME=/var/tmp/interiot_homeless/`; cd $HOME`; . $HOME/.bashrc`; fi{enter}
    ; Send,[ -e /var/tmp/interiot_homeless/.bashrc ] && . /var/tmp/interiot_homeless/.bashrc{enter}
    return

;== Ctrl-Shift-F10 -- list SUDO
^+F10::
    target_window := WinExist("A")
    SetKeyDelay, 0
    Send,{#}{#}{#}{#}{#}{#}{#}{#} hotkey ctrl-F10 -- list sudo {#}{#}{#}{#}{#}{#}{#}{#}{enter}
    Sleep 50
    ; SendRaw,sudo -l | perl -nle 'while (/(?<![=\S])(\/[^, ]*)/g) {@g = map {"sudo $_"} glob $1 and print join "\n", @g}'
    ; SendRaw,sudo -l | perl -nle 'while (/(?<![=\S])(\/[^, ]*)/g) {@g = map {(-e $_ ? "  " : "X ") . "sudo $_"} glob $1 and print join "\n", @g}' | sort
    ;SendRaw,lsu() { sudo -l | ARGS="$*" perl -nle 'while (/(?<![=\S])(\/[^, ]*)/g) {@g = map {(-e $_ ? "  " : "X ") . sprintf "sudo `%-50s `%s", $_, $ENV{ARGS}} glob $1 and print join "\n", @g}' | sort`; }
    Send,[ -e /usr/local/bin/sudo ] && export PATH=$PATH:/usr/local/bin{enter}
    SendRaw,lsu() { sudo -l |  ARGS="$*" perl -nle '/\((.*?)\)/ and $user=$1`; while (/(?<![=\S])(\/[^, ]*)/g) {@g = map {(-e $_ ? "  " : "X ") . sprintf "sudo -u `%-10s `%-50s `%s", $user, $_, $ENV{ARGS}} glob $1 and print join "\n", @g}' | sort`; }
    Send,{enter}lsu{enter}
    return


;== Windows-F10 -- shell init after SU
#F10::
    ; if ~/.sudo_profile is setup, then DON'T exec to bash
    ; if ~/.sudo_bashrc is setup, then DO exec to bash
    ; if neither is setup, then *try* to exec to bash

    target_window := WinExist("A")
    sending =
( % ` LTrim
    ######## hotkey win-F10 -- shell initialization after SUing ########
    export PATH=$PATH:/home/interiot/opt/bin
    [ -n "$PS1" -a -z "$BASH" ] && which bash >/dev/null 2>/dev/null && exec bash
    [ -n "$BASH" -a -f /home/interiot/.sudo_bashrc ] && . /home/interiot/.sudo_bashrc; [ -z "$BASH" -a -f /home/interiot/.sudo_profile ] && . /home/interiot/.sudo_profile
)
    SendWithNewlineDelay(50, sending)
    return



;== make mouse clicks visible -- http://superuser.com/a/106885
; ~LButton:: Send {Ctrl}



;;== Office Communicator normally closes chat windows with the 'Escape' key.  Neuter this terrible behavior.
;; http://bit.ly/15f4a9I
#IfWinActive ahk_class IMWindowClass
#IfWinActive ahk_class HwndWrapper[TabbedConversations.exe`;`;01e54440-cf02-4d50-b98f-601493ef3b29]
;Escape::return
;Capslock::return            ; sometimes this is necessary to block, because AHK is confused about whether Capslock is escape or not, due to my capslock<=>escape swapping



;== Ctrl-F -- refresh Communicator 2007 window
;                   (this also runs whenever Ctrl-W is used)
^f::
~^w::
    sleep 200
    ; scroll to the bottom
    SendMessage, 0x115, 7, 0, Internet Explorer_Server1, A
    WinSet, Redraw, , A
    return




;== minor:  F9 usually gets gobbled by KeePass, but in some cases we want the application to still get it
#IfWinActive ahk_class IMWindowClass
*F9::
    return


;== minor:  F8 usually gets gobbled by KeePass, but in some cases we want the application to still get it
#IfWinActive Microsoft Visual Basic -
F8::    ControlSend, ,   {F8}, A
+F8::   ControlSend, ,  +{F8}, A
^+F8::  ControlSend, , ^+{F8}, A


;== F10_documentation()
F10_documentation() {
    KeyWait, F10, T1.5
    if (ErrorLevel == 0)        ; did KeyWait timeout?
        return false
    msgbox, , F10 Hotkey,
(
F10         Bash initialization
Shift-F10           KSH initialization
Windows-F10         Initialize after SUing
Alt-F10         .bashrc
Ctrl-F10        list sudo options
)
    return true
}


;== SendWithNewlineDelay()
; Send(), with a delay at every newline.
; I want delays, but SetKeyDelay slows things down too much.
SendWithNewlineDelay(interline_delay, lines) {
    ;TargetSendRaw(lines . "`n")
    Loop, Parse, lines, `n
    {
        ;SendRaw,%A_LoopField%
        ;Send,`n
        TargetSendRaw(A_LoopField . "`n")
        ;Sleep %interline_delay%
    }
}


;== TargetSend()
; A drop-in replacement for "send", but it sends its text to the predetermined window.
TargetSend(string) {
    global target_window
    ControlSend, , %string%, ahk_id %target_window%
    ;Send %string%
}


;== TargetSendRaw()
; A drop-in replacement for "SendRaw", but it sends its text to the predetermined window.
TargetSendRaw(string) {
    global target_window
    ;;;;    this has problems with shift keys getting stuck down  (as the manual points out)
    ;ControlSendRaw, , %string%, ahk_id %target_window%
    ;;;;    http://www.autohotkey.com/board/topic/25446-consolesend/
    ;ConsoleSend(string, "ahk_id " . target_window)
    ;;;;    this one actually works!
    PuttyPaste(target_window, string)
}


;== PuttyPaste()
; Works like  'Control, EditPaste' -- instead of simulating keys, it more directly sends the text
; string to the app.  However, it's tailored for Putty.
PuttyPaste(putty_hwnd, string) {
    SavedClipboard := ClipboardAll
    Clipboard := string
    sleep,200
    ControlClick, , ahk_id %putty_hwnd%, , RIGHT        ; right-click = paste
    sleep,200
    Clipboard := SavedClipboard
}
