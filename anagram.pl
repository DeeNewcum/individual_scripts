#!/usr/bin/perl
    
    use strict;
    use warnings;

    use Data::Dumper;


if (@ARGV < 2) {
    print <<"EOF";
usage:  $0 word length  < /usr/share/dict/words

<length> can be something like:
        5
        4..6
        4..
EOF
    exit 1;
}
if (-t STDIN) {
    print <<"EOF";
Something must be piped in to this, for example:
    $0 word length  < /usr/share/dict/words
EOF
    exit 1;
}

my ($word, $length) = @ARGV;

my ($regexp_exact_length, $regexp_longer, $regexp_shorter)
    = anagram_regexp($word);

my ($length_lower, $length_upper) = split /\.\./, $length;
if ($length !~ /\.\./) {
    $length_upper = $length_lower;
}

my $wordlen = length($word);
my @regexps;
if ($length_lower < $wordlen) {
    my $my_upper = min($length_upper, $wordlen);        # even if the upper is larger than wordlen, we still want to cover as much as we can
    my $re = $regexp_shorter;
    $re =~ s/<<<LENGTH>>>/$length_lower,$my_upper/;
    push @regexps, $re;
}
if ($length_lower <= $wordlen && $length_upper >= $wordlen) {
    push @regexps, $regexp_exact_length;
}
if ($length_upper > $wordlen) {
    my $my_lower = max($length_lower, $wordlen);        # even if the upper is larger than wordlen, we still want to cover as much as we can
    my $re = $regexp_longer;
    $re =~ s/<<<LENGTH>>>/$my_lower,$length_upper/;
    push @regexps, $re;
}

print Dumper @regexps;# exit;

while (<STDIN>) {
    foreach my $re (@regexps) {
        print if /^$re$/;
    }
}

exit;





# Given a word, this returns three regular expressions:
#       #1 -- matches a word of the exact lenght
#       #2 -- matches a word that's longer
#       #3 -- matches a word that's shorter
sub anagram_regexp {
    my $word = shift;

    my @letters = split('', $word);

    my %letters;
    foreach (@letters) {
        $letters{$_}++;
    }

    my @order_seen;
    my %seen;
    foreach my $l (@letters) {
        next if ($seen{$l}++);
        push(@order_seen, $l);
    }


    #print "inclusive\n\t";
    #foreach my $l (sort keys %letters) {
    my $str;
    my $negstr;
    foreach my $l (@order_seen) {
        $str .= join('', '(?=', ".*$l" x $letters{$l}, ')');
        $negstr .= join('', '(?!', ".*$l" x ($letters{$l}+1), ')');
    }
    #print "exact length:  ", $str, "[^a-z]*([a-z][^a-z]*){", length($word), "}\$/i\n";
    #print "longer:        ", $str, "[^a-z]*([", @order_seen, "][^a-z]*){", length($word), "}\$/i\n";
    #print "shorter:       ", $negstr, "[^a-z]*([", @order_seen, "][^a-z]*){", length($word), "}\$/i\n";

    my $regexp_exact_length = "$str\[^a-z]*([a-z][^a-z]*){<<<LENGTH>>>}";
    my $regexp_longer       = "$str\[^a-z]*([" . join('', @order_seen) . "][^a-z]*){<<<LENGTH>>>}";
    my $regexp_shorter      = "$negstr\[^a-z]*([" . join('', @order_seen) . "][^a-z]*){<<<LENGTH>>>}";
    #print "\n";


    #print "exclusive\n\t";
    #print "^[^a-z]*([", join("", @order_seen), "][^a-z]*){", length($word), "}\$\n";
    return ($regexp_exact_length, $regexp_longer, $regexp_shorter);
}

sub max {
    my ($a, $b) = @_;
    return $a > $b ? $a : $b;
}

sub min {
    my ($a, $b) = @_;
    return $a < $b ? $a : $b;
}
