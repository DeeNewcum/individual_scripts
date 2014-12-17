## TODO: use Term::ANSIColor, so we can use color names instead of numbers ##

# hil #

<tt>hil</tt> is a command-line utility that adds ANSI color hilighting to text.

## Arguments ##

<tt>hil</tt> reads text from stdin, adds ANSI codes, and sends the modified text to stdout.  Example:

    cat file | hil .... | less -R

The arguments to <tt>hil</tt> are in pairs:

* First of pair — A regular expression that matches text you want to hilight.
* Second of pair — The ANSI color(s) you want to hilight that text in.

See examples below.

## Argument order ##

Note that *order matters*, with leftmost patterns getting higher precedence.  Once a piece of text has been hilighted, that text can no longer be hilighted by other patterns.

For example, using <tt>'.*' 0</tt> as a pattern will prevent all later patterns from matching.

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

Use [Perl's regular expression syntax](http://perldoc.perl.org/perlre.html).

Note that capturing parentheses can *not* be used (they will break hil's internals); use non-capturing parens instead (ie. <tt>(?:...)</tt> ).

To match case-insensitively, add <tt>(?i)</tt> to a pattern.

To match across newlines, add <tt>(?s)</tt> to a pattern.

## Examples ##

    cat /etc/passwd | hil   ':' 96    '[^:]+$' '44;97'

Hilight the field-separators in cyan, and hilight the shell field with a white foreground and blue background.

    diff -U 9999999 file1 file2 | hil    '^\+.*' 92    '^-.*' 91

Show the changes to a file, with the added lines hilighted in green and the deleted lines in red.

## See also

Other programs that do something similar include:

* [multitail](https://en.wikipedia.org/wiki/MultiTail)
* [generic colouriser](http://manpages.ubuntu.com/manpages/trusty/man1/grcat.1.html)
* [ccze](http://manpages.ubuntu.com/manpages/trusty/man1/ccze.1.html)
* [pycolor](http://manpages.ubuntu.com/manpages/trusty/man1/pycolor.1.html)
* [colortail](http://manpages.ubuntu.com/manpages/trusty/man1/colortail.1.html)
* [GNU source-hilight](http://manpages.ubuntu.com/manpages/trusty/man1/source-highlight.1.html)
* ... and countless others  [[1]](https://bitbucket.org/linibou/colorex/wiki/Home) [[2]](https://github.com/nicoulaj/rainbow) [[3]](https://github.com/armandino/TxtStyle)

The main benefit to hil is that it can run on [damn near any Unix, without installing anything](http://paperlined.org/dev/perl/portability.html).
