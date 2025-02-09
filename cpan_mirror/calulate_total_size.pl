#!/usr/bin/env perl

use strict;
use warnings;

use MetaCPAN::Client ();
use Number::Bytes::Human;

my $mc = MetaCPAN::Client->new( version => 'v1' );

my $file = $mc->all(
    'files',
    {
        aggregations => { aggs => { sum => { field => 'stat.size' } } },
    }
);

print "A CPAN mirror would consume ",
    Number::Bytes::Human::format_bytes( $file->aggregations->{aggs}{value} ), "\n";

__END__
=pod

=head1 DESCRIPTION

Get the size of CPAN + BackPAN, when it's unpacked.

=cut
