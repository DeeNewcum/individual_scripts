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
#
# The goal isn't for my cats/rats to actually understand words or sentences.  Rather, the goal is to
# train them to recognize a certain word as a command. To them, it will be interpretted as a
# certain pattern of sounds, but it will be a pattern that humans can easily reproduce.
#
# Because each command (word) would be made up of multiple ultrasonic "beats" strung together, it
# will hopefully be possible to communicate a broader range of commands than when using only a single
# ultrasonic sound.


# Example output:
#        3.2  specific
#        3.2  hybridization
#        3.4  sophisticated
#        3.1  philosophical
#        3.2  demonstrations
#        4.1  hypothesis
#        5.2  specifications
#
# (where the main number indicates how many fricatives, and the decimal indicates the number of
#  stops)   (mostly)

    use strict;
    use warnings;

    use Data::Dumper;
    #use Devel::Comments;           # uncomment this during development to enable the ### debugging statements


#### pronunciation dictionary
if (! -e "IPhODv2.0_REALS.zip") {
    print "IPhODv2.0_REALS.zip not found.  Please download it with this command:\n";
    print "        wget http://www.iphod.com/download/IPhODv2.0_REALS.zip\n";
    exit;
}
open IPHOD, "-|", "unzip -p IPhODv2.0_REALS.zip IPhOD2_Words.txt";
$_ = <IPHOD>;        # discard the header line

#### word-frequency dictionary
if (!-e "ANC-all-count.zip") {
    print "ANC-all-count.zip not found.  Please download it with this command:\n";
    print "        wget http://www.anc.org/SecondRelease/data/ANC-all-count.zip\n";
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
                # These are iphod.com's own way to code various phonemes.  See the translation key at
                # http://www.iphod.com/download/CMU_pronunciation_key.pdf
# How much ultrasound does a specific phoneme produce?
my %iphod_phoneme_value = (
    ## fricative phonemes
    'F'  => $fricatives,
    'TH' => $fricatives,
    'DH' => $fricatives,
    'S'  => $fricatives,
    'Z'  => $fricatives,
    'SH' => $fricatives,
    'ZH' => $fricatives,
    'HH' => $fricatives,
    'V'  => $fricatives / 2,        # This doesn't have much ultrasound, does it?

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
    my (undef, $word, $iphod_pronounce) = split /\t/, $_;

    my $phoneme_value = 0;
    foreach my $iphod_phoneme (split /\./, $iphod_pronounce) {
        $phoneme_value += $iphod_phoneme_value{$iphod_phoneme} || 0;
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
    if (exists $words{lc $word}) {      # lc() because the ANC dictionary *never* capitalizes words
        my $phoneme_value = delete $words{lc $word};
        if ($word =~ /[^aeiouy](i?e)?s$/) {
            # Skip plurals.  This is entirely optional, and should be a user configuration.
            # The reason one might want to do this is that there's SO many plurals, and IMHO
            # they're a little less natural for others (friends who are just introduced to the rats)
            # to say.
            next;
        }
        printf "%4.1f  %s\n",  $phoneme_value, $word;
    }
}
# Are there any words that weren't in the frequency-dictionary?  Print those too.
print "-------------------------------\n";
my @sort = sort {$words{$b} <=> $words{$a}} keys %words;
foreach my $word (@sort) {
    my $phoneme_value = $words{$word};
    printf "%4.1f  %s\n",  $phoneme_value, $word;
}
