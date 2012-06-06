#!/usr/bin/perl

# There are several ANSI escape codes that can be used between the server and client for
# query/reply.  This utility shows how your current terminal responds to a particular query.

    use strict;
    use warnings;

    use Time::HiRes qw[alarm];
    #use Term::ReadKey;

    use Data::Dumper;

    use constant TIMEOUT => 1.0;        # total seconds to wait for a reply


@ARGV or die "$0 <query> [<response_end_character>]\n";

my ($query, $response_end_character) = @ARGV;

$query = perl_string_decode($query);


## cooked mode, echo off
#Term::ReadKey::ReadMode(2);
system "stty", '-icanon', '-echo', 'eol', "\001";


print $query;
$|++;


my $reply = '';
eval {
    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm(TIMEOUT);
    while (1) {
        if (defined(my $c = getc())) {
            #print ".";
            $reply .= $c;
            last if (defined($response_end_character)
                  && $c eq $response_end_character);
        }
    }
};
if ($@) {
    die $@      unless ($@ eq "alarm\n");
}


print "  query:  ", perl_string_encode($query), "\n";
print "  reply:  ", perl_string_encode($reply), "\n";


## reset tty mode before exiting
#Term::ReadKey::ReadMode(0);         
system 'stty', 'icanon', 'echo', 'eol', chr(0);





# turn things like "\e" and "\033" into their single-character equivalents, using standard perl string-literal rules
sub perl_string_decode {
    my $encoded = shift;
    my $decoded = eval "qq\000$encoded\000";
}


# turn things like chr(27) into '\e' -- into a visible presentation
sub perl_string_encode {
    my $decoded = shift;
    my $encoded = Data::Dumper::qquote($decoded);
    $encoded =~ s/^"|"$//sg;
    return $encoded;
}


# display a string to the user, via `xxd`
sub xxd {open my$xxd,"|xxd"or die$!;print$xxd $_[0];close$xxd}
