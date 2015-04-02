#!/usr/bin/perl

# Brute-force solver for Minesweeper / Mamono Sweeper.
# 
# The code is quick-n-dirty.  To use it, look for the three "EDIT THIS" lines.

    use strict;
    use warnings;

    use Algorithm::Combinatorics qw[variations_with_repetition];

    use Data::Dumper;


# EDIT THIS.  "Clues" are the spaces in between the mines.
#       digits      clues
#       .           don't care
#       #           mines
my $clues = parse_board(<<'EOF');
    
    . 1 1 4 .
    . # # # .
    . . . . .

EOF

# EDIT THIS.  These are mines we already know about.  If all of them are covered, it should at
# least match the size from above.
my $mines = parse_board(<<'EOF');

    . . . . .
    . # # # .
    . . . . .
EOF

#!print_board($clues, $mines); exit;


                                                    ##  vv EDIT THIS -- number of covered cells
my $iter = variations_with_repetition( [0, 1, 2, 3, 4], 3 );
while (my $permutation = $iter->next()) {
    #! print join(' ', @$c), "\n";

    ## EDIT THIS, to indicate where the covered cells are.  Coordinates are (Y,X).
    $mines->[1][1] = shift @$permutation;
    $mines->[1][2] = shift @$permutation;
    $mines->[1][3] = shift @$permutation;

    my $new_clues = calculate_clues($mines);
    if (compare_clues($new_clues, $clues)) {
    #if (compare_clues($new_clues, $new_clues)) {
        print_board($new_clues, $mines);
    }
}




########################################[ Board moves/consistency ]########################################

sub calculate_clues {
    my ($mines) = @_;
    my $clues = [];

    my $width = scalar(@{$mines->[0]});
    my $height = scalar(@$mines);
    for (my $y=0; $y<$height; $y++) {
        for (my $x=0; $x<$width; $x++) {
            my $m = $mines->[$y][$x];
            next unless $m =~ /^\d+$/;

            for (my $_y=$y-1; $_y<=$y+1; $_y++) {
                for (my $_x=$x-1; $_x<=$x+1; $_x++) {
                    next if ($_y == $y && $_x == $x);
                    next if ($_y < 0 || $_y >= $height);
                    next if ($_x < 0 || $_x >= $width);
                    $clues->[$_y][$_x] += $m;
                }
            }
        }
    }
    return $clues;
}


# Okay, so we calculated the new clues.  Do they match the expected clues?
# Returns true or false (the clues match, or they don't);
sub compare_clues {
    my ($current_clues, $expected_clues) = @_;
    my $width = scalar(@{$current_clues->[0]});
    my $height = scalar(@$current_clues);
    #!print "==== ($width, $height) ====\n";
    for (my $y=0; $y<$height; $y++) {
        for (my $x=0; $x<$width; $x++) {
            #my $c = $current_clues->[$y][$x];
            #my $e = $expected_clues->[$y][$x];
            #next if (($current_clues->[$y][$x] || '') !~ /^\d+$/
            #     && ($expected_clues->[$y][$x] || '') !~ /^\d+$/);
            next if (($expected_clues->[$y][$x] || '') !~ /^\d+$/);

            return 0 if ($current_clues->[$y][$x]
                    ne $expected_clues->[$y][$x]);
        }
    }
    return 1;
}


########################################[ lowest-layer Board ]########################################


sub parse_board {
    my $text = shift;
    my @rows = grep /\S/, split /[\n\r]+/, $text;
    @rows = map { [ split ' ', $_ ] } @rows;
    return \@rows;
}


our($reverse, $reset);
BEGIN {
    $reverse = "\e[7m";
    $reset   = "\e[0m";
}
sub print_board {
    if (@_ == 2) {
        my ($clues, $mines) = @_;
        #!print Dumper $clues;  print Dumper $mines;  exit;
        my $width = scalar(@{$clues->[0]});
        for (my $y=0; $y<scalar(@$clues); $y++) {
            for (my $x=0; $x<$width; $x++) {
                #!print STDERR "---- ($x, $y) ----\n";
                my $m = $mines->[$y][$x];
                if ($m =~ /^\d+$/) {
                    printf "%s%2s%s ", $reverse, $m, $reset;
                } else {
                    printf "%2s ", $clues->[$y][$x];
                }
            }
            print "$reset\n";
        }
    } elsif (@_ == 1) {
        my $board = shift;
        print map {
            join(" ", @$_) . "\n";
        } @$board;
    }
    print "\n";
}
