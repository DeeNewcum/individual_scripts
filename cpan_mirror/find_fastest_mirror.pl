#!/usr/bin/perl

# Find the fastest CPAN mirror to you, in preparation for downloading everything via CPAN::Mini


# This takes ~15 minutes to run, becuase it downloads a 1mb file from EVERY mirror, to get a good
# measurement of how fast each is.
#
#
# The output is optimized somewhat -- rather than displaying the speed result for EVERY mirror it
# tests, it only mentions a mirror if it's in the top-5 fastest mirrors that it has seen so far.
# So the mirrors reported near the end are among the fastest that it sees.

    use strict;
    use warnings;

    #use LWP::Simple qw[];
    use LWP::UserAgent;
    use Time::HiRes;
    use File::Temp;

    use CPAN;
    use CPAN::Mirrors;
    use CPAN::HandleConfig;

    use Data::Dumper;



our $ua = LWP::UserAgent->new;
$ua->env_proxy();
$ua->timeout(5);

print "\t\tTo download a CPAN mirror:\n";
print "\t\t  cpanm CPAN::Mini\n\n";
print "\t\t  minicpan -r <remoteURL> -l .\n\n";


find_fastest_mirror();



sub find_fastest_mirror {
    ## load ~/.cpan/CPAN/MyConfig.pm or .../CPAN/Config.pm
    #do CPAN::HandleConfig->require_myconfig_or_config();
    #my $mirrored_by = File::Spec->catfile($CPAN::Config->{keep_source_where}, 'MIRRORED.BY');
    ### load the MIRRORED.BY file
    #if (!-f $mirrored_by) {
    #    #print "looking in  $mirrored_by\n";
    #    die "MIRRORED.BY file wasn't found.  Please run:\n\techo o conf init urllist | cpan\nor just initialize CPAN for the first time, if you haven't.\n";
    #}

    my ($fh, $mirrored_by) = File::Temp::tempfile();
    close $fh;
    utime(1, 1, $mirrored_by);
    $ua->mirror("http://www.cpan.org/MIRRORED.BY", $mirrored_by);

    my $mirrors = CPAN::Mirrors->new($mirrored_by);
    #print Dumper $mirrors; exit;

    my %speeds;
    my @mirrors = $mirrors->mirrors;
    @mirrors = sort {rand() < .8} @mirrors;     # shuffle the deck
    #print join("\n", map {$_->http} @mirrors), "\n"; exit;
    $| = 1;

    my $topN = 5;
    foreach my $mir (@mirrors) {
        #foreach my $prot (qw[ http ftp ]) {
        foreach my $prot (qw[ http ]) {
            if ($mir->{$prot}) {
                #my $kbps = kbps($mir->{$prot} . "/MIRRORED.BY");
                #print $mir->{$prot} . "/MIRRORED.BY", "\n";
                my $url = $mir->{$prot};
                my $kbps = kbps($url);
                if ($kbps) {
                    $speeds{$url} = $kbps;

                    my @top_speeds = sort {$a <=> $b} values(%speeds);
                    #print "\t\t\t\t\t", join("  ", map {int($_)} @top_speeds), "\n";
                    if (@top_speeds < $topN || $kbps > $top_speeds[-$topN]) {
                        #print "$url  ==>  ", int($kbps), "\n";
                        my $cmp = (@top_speeds >= $topN) ? int($top_speeds[-$topN]) : '<>';
                        print "\r\e[K";
                        print "$url  ==>  ", int($kbps), " kbps\n";          # , "        (comparing to $cmp)\n";
                    } else {
                        print ".";
                    }
                } else {
                    print ".";
                }
            }
        }
    }


    ##### unfortunately, CPAN::Mirrors::best_mirrors() doesn't work, because it relies on Net::Ping, which won't operate through a web proxy
    
    ###### yeah
    #my @best = $mirrors->best_mirrors(
    #    how_many => 3,
    #    verbose => 1,
    #    #callback => sub {
    #        #$CPAN::Frontend->myprint(".");
    #        #if ($cnt++>60) { $cnt=0; $CPAN::Frontend->myprint("\n"); }
    #    #},
    #);
    #print Dumper \@best;
    #my $urllist = [ map { $_->http } @best ];
}


sub kbps {
    my $mirror_root = shift;

    $mirror_root =~ s/\/?$/\//s;

    my $url = "${mirror_root}modules/02packages.details.txt.gz";

    my $start = Time::HiRes::time();
    my $response = eval {
        $ua->get($url, 'Cache-Control' => 'no-cache')       # if there's a proxy in between, we want don't want it to give us previous copies, because that'll muck up our numbers quite a bit
    };
    #my $large_file = LWP::Simple::get($url);
    my $duration = Time::HiRes::time() - $start;

    return if (!defined($response));        # timeout
    # this is the web proxy responding, not the remote server
    return if ($response->code == 503 && $response->content =~ /A communication error occurred: "Connection refused"/);
    return if ($response->code == 503 && $response->header('Refresh') =~ /block\.asp/);


    my $size = length($response->content || '');
    return unless ($size);
    if ($size < 1000000) {
        return;
        #print $response->as_string(); exit;
    }
    my $kbps = $size / $duration / 1024;

    #print "$url  ==>  ", int($kbps), "\n";

    #print "\tdownloaded $size in $duration seconds\n";

    return $kbps;
}
