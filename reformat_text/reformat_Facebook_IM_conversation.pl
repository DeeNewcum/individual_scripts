#!/usr/bin/perl

# THIS SCRIPT IS NOT POLISHED.  I wrote it pretty quickly.  I may clean it up later, but 
# there's no guarantees that this will work well currently.
# 
#
#
# If you copy-n-paste a Facebook IM conversation into a plain-text editor, the format is a little
# wonky.  This fixes it somewhat.
#
# NOTE: You should copy the text using https://www.facebook.com/messages/ instead of the standard
#           web-based IM.
#
# This script acts as a standard Unix filter, so you need to pipe something in and redirect the
# output.

    use strict;
    use warnings;

    use Data::Dumper;

if (!@ARGV && -t STDIN) {
    die "This acts as a standard Unix filter.  You need to pipe the text in and redirect the output.\n";
}

my %people;
while (<>) {
    chomp;
    (my $sans4 = $_)
        =~ s/^(    )(?=\S)//;       # when copying from Firefox, every line has 4 spaces at the beginning  (but isn't present in Chrome)

    if ($sans4 =~ /^
            ( \d+ \/ \d+ , \s+ )?       # day
            \d+ : \d\d [ap] m           # time
            $
        /x)
    {
        ## ==== time/date header ====
        #!print "date -- $sans4\n"; next;

        my $time = $sans4;

        my $person = <>;
        chomp $person;
        $person =~ s/^(    )(?=\S)//;
        $people{$person} = 1;
        
        print "==== $person    $time ====\n";

    } elsif (exists $people{$sans4}) {
        ## ==== person header ====
        #!print "person -- $sans4\n"; next;
        # skip -- it seems to get repeated more times than we need;

    } elsif ($sans4 =~ /
        ^ (
            Today  |
            Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday  |
            (January|February|March|April|May|June|July|August|September|October|November|December) \s+\d+
        ) $/x)
    {
        ## ==== new-day header ====
        ## skip -- we don't care about these superfluous headers

    } else {
        ## ==== text from the actual conversation ====
        next unless %people;        # wait until we see the first time-header, because otherwise we
                                    # have no way to know if this is conversation text or a name-header
        print "$sans4\n"    if /\S/;
    }
}
