#!/bin/bash



# Wow, the method I was using before was overly complex.
#
# If you run this:
#       last | tac | perl -ple '/(?<=.{39})(.{10})/; print "\n" unless $seen{$1}++' | less
#       last | tac | perl -ple 's/(?<=.{39})(.{10})//; print "\n========[ $1 ]=======" unless $seen{$1}++'
#
# You see that the data we need is pretty much already available, on the 'reboot' lines.
#
# The 'tac' command makes it more intuitively obvious perhaps?  Anyway, the data was right there all along!


(last; last -f /var/log/wtmp.1) | tac | grep system.boot | perl -ple 's/^.{38}(.{12})//; print "\n====[ $1 ]===" unless $seen{$1}++'
