#!/usr/bin/perl

# A script that searches some machine-readable dictionaries, and finds words that have the highest
# amount of ultrasonic components.
#
# After playing with my bat detector (a Magenta Bat 4), I realized that many of the sounds that I
# had started using to comminucate with my cat were sounds that had a great deal of sound in the
# 30 - 50 kHz range (eg. hissss, kissing noises).  I had inadvertently stumbled on these only
# because my cat responded to them.
#
# Experimenting more, I found that certain phonemes generate more ultrasonic components than others.
# These are the fricative phonemes (the "hiss" type sounds), and to a lesser extent the stop phonemes.

    use strict;
    use warnings;

    use Data::Dumper;
    #use Devel::Comments;           # uncomment this during development to enable the ### debugging statements


    ## LEFT OFF -- god, the SCOWL database is kind of a pain to use, its words are scattered across
    #              many files.  Perhaps I can find a better one to use?
    #                   http://corpus.byu.edu/corpora.asp
    #                   http://www.wordfrequency.info/purchase.asp



#### pronunciation dictionary
if (! -e "IPhODv2.0_REALS.zip") {
    print "IPhODv2.0_REALS.zip not found\n";
    print "wget http://www.iphod.com/download/IPhODv2.0_REALS.zip\n";
    exit;
}
open IPHOD, "-|", "unzip -p IPhODv2.0_REALS.zip IPhOD2_Words.txt";
$_ = <IPHOD>;        # discard the header line

#### word-frequency dictionary
if (!-e "ANC-all-count.zip") {
    print "ANC-all-count.zip not found.\n";
    print "wget http://www.anc.org/SecondRelease/data/ANC-all-count.zip\n";
    exit;
}
if (0) {
    my $scowl_filename = glob("scowl-*.*.*.tar.gz");
    if (!$scowl_filename) {
        print "scowl-*.tar.gz not found.\n";
        print "please download the latest .tar.gz from http://wordlist.aspell.net/\n";
        exit;
    }
    open SCOWL, '<', $scowl_filename;
}

#### filter words that have a good pronunciation
my %words;
my %cmu_phoneme_value = (
    ## fricative phonemes
    'F'  => 3,
    'V'  => 3,
    'TH' => 3,
    'DH' => 3,
    'S'  => 3,
    'Z'  => 3,
    'SH' => 3,
    'ZH' => 3,
    'HH' => 3,

    ## stop phonemes
    'P' => 1,
    'B' => 1,
    'T' => 1,
    'D' => 1,
    'K' => 1,
    'G' => 1,
);
while (<IPHOD>) {
    chomp;
    my (undef, $word, $cmu_pronounce) = split /\t/, $_;

    #print ">> $_ <<\n";
    #print Dumper \@fields;
    #print ">> $word -- $cmu_pronounce <<\n";

    my $phoneme_value = 0;
    foreach my $cmu_phoneme (split /\./, $cmu_pronounce) {
        $phoneme_value += $cmu_phoneme_value{$cmu_phoneme} || 0;
    }
    if ($phoneme_value >= 11) {
        printf "%2d  %s\n",  $phoneme_value, $word;
    }
}
