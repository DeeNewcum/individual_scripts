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
open ANC_FREQ, "-|", "unzip -p ANC-all-count.zip";
my (undef, undef, undef, $freq_max) = split /\t/, <ANC_FREQ>;
$freq_max =~ s/[\n\r]+$//;
                    ### $freq_max

#### filter words that have a good pronunciation
my %words;
my $fricatives = 1;
my $stops = 0.1;
my %cmu_phoneme_value = (
    ## fricative phonemes
    'F'  => $fricatives,
    'V'  => $fricatives,
    'TH' => $fricatives,
    'DH' => $fricatives,
    'S'  => $fricatives,
    'Z'  => $fricatives,
    'SH' => $fricatives,
    'ZH' => $fricatives,
    'HH' => $fricatives,

    ## stop phonemes
    'P' => $stops,
    'B' => $stops,
    'T' => $stops,
    'D' => $stops,
    'K' => $stops,
    'G' => $stops,
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
    if ($phoneme_value >= 3) {
        $words{$word} = $phoneme_value;
        #printf "%2d  %s\n",  $phoneme_value, $word;
    }
}


#### sort words by frequency
while (<ANC_FREQ>) {
    s/[\n\r]$//;        # chomp, but for DOS-formatted .txt files
    my ($word) = split /\t/, $_;
    if (exists $words{$word}) {
        my $phoneme_value = $words{$word};
        printf "%4.1f  %s\n",  $phoneme_value, $word;
    }
}
