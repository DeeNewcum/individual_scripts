#!/usr/bin/perl

    use strict;
    use warnings;

    use Data::Dumper;
    #use Devel::Comments;           # uncomment this during development to enable the ### debugging statements

my $timestamp = time();
my $state = int(rand(2)) * 3;
printf "%d\t%d\n", $timestamp, $state;

my $num_samples = int(rand(10)) + 3;
for (my $ctr=1; $ctr<$num_samples; $ctr++) {
    $timestamp += int(rand(14))*10 + 10;
    #$state = int(rand(2)) * 3;
    $state = int(rand(4));
    printf "%d\t%d\n", $timestamp, $state;
}
