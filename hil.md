# hil #

hil is a command-line utility that adds ANSI color hilighting to text.

## Arguments ##

Hil reads text from stdin, adds ANSI codes, and spits the modified text out on stdout.  Example:

    cat file | hil .... | less -R

The arguments to hil are in pairs:

* First of pair -- A regular expression that matches text you want to hilight.
* Second of pair -- The ANSI color(s) you want to hilight that text in.

Note that *order matters*, with earlier patterns getting higher precedence.  Once a section of text has been hilighted, that text will no longer be used for other matches.

For example, using <tt>'.*' 0</tt> as the first pattern will prevent any trailing patterns from matching.

## ANSI colors ##

One or more numbers.  These are the numbers that are used in the [\<ESC\>\[...m](http://www.termsys.demon.co.uk/vtansi.htm#colors) ANSI escape code.

|         | foreground | bright foreground | background | bright background |
|--------:|:----------:|:-----------------:|:----------:|:-----------------:|
|   black |     30     |         90        |     40     |        100        |
|     red |     31     |         91        |     41     |        101        |
|   green |     32     |         92        |     42     |        102        |
|  yellow |     33     |         93        |     43     |        103        |
|    blue |     34     |         94        |     44     |        104        |
| magenta |     35     |         95        |     45     |        105        |
|    cyan |     36     |         96        |     46     |        106        |
|   white |     37     |         97        |     47     |        107        |

Additionally, there are:

* 0 - reset all attributes
* 1 - bright
* 2 - dim
* 4 - underscore 
* 5 - blink
* 7 - reverse

You can use more than one attribute by combining them with semicolons.  Example:

    cat /etc/passwd | hil   ':' '37;45'

## Regular expressions ##

Use Perl's regular expression syntax.

To match case-insensitively, add <tt>(?i)</tt> to a pattern.

To match across newlines, add <tt>(?s)</tt> to a pattern.

## Examples ##

    cat /etc/passwd | hil   ':' 96    '[^:]+$' 91

    diff -U 9999999 file1 file2 | hil    '^\+.*' 92    '^-.*' 91
