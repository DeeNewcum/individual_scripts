#!/usr/bin/perl

# There are several ANSI escape codes that can be used between the server and client for
# query/reply.  This utility shows how your current terminal responds to a particular query.

    use strict;
    use warnings;

    use Time::HiRes qw[time];
    #use Term::ReadKey;

    use Data::Dumper;
    #use Devel::Comments;           # uncomment this during development to enable the ### debugging statements

    use constant TIMEOUT => 2.0;        # total seconds to wait for a reply


@ARGV or die "$0 <query> [<response_end_character>]\n";

my ($query, $response_end_character) = @ARGV;

$query = perl_string_decode($query);


## cooked mode, echo off
#Term::ReadKey::ReadMode(2);
system "stty", '-icanon', '-echo', 'eol', "\001";

my $start_time = time();
print $query;
$|++;
#xxd($query);

#print perl_string_encode($query), "\n";

my ($rin, $rout, $input) = ('', '', '');
vec($rin, fileno(STDIN), 1) = 1;

FINISHED_INPUTTING:
 while (0) {
    # wait for a key to be pressed
    my $numchars = 0;
    while (1) {
        #print length($input);
        print ".";
        last if $numchars = select($rout=$rin, undef, undef, 0.5);
        last FINISHED_INPUTTING  if (time() - $start_time > TIMEOUT);
    }
    #print "\n$numchars char(s) in buffer\n";
    #for (1..$numchars) {
    #$input .= getc();
    while (my $c = getc()) {
        $input .= $c;
        last FINISHED_INPUTTING  if (defined($response_end_character) && substr($input, -1) eq $response_end_character);
    }
}

eval {
    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm(TIMEOUT);
    while (1) {
        if (defined(my $c = getc())) {
            #print ".";
            $input .= $c;
            last if (defined($response_end_character) && $c eq $response_end_character);
        }
        #last if (time() - $start_time > TIMEOUT);
    }
};
if ($@) {
    die $@      unless ($@ eq "alarm\n");
}


print "     query:  ", perl_string_encode($query), "\n";
print "  response:  ", perl_string_encode($input), "\n";


if (0) {
    print "\n\n<press enter>\n";
    my $residual = <STDIN>;
    $residual =~ s/\n$//s;
    print "  residual:  >>", perl_string_encode($residual), "<<\n";
}

## reset tty mode before exiting
#Term::ReadKey::ReadMode(0);         
system 'stty', 'icanon', 'echo', 'eol', chr(0);





# turn things like "\e" and "\033" into their single-character equivalents, using the normal perl
# string-literal rules
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
