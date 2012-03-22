# This module allows you to capture all data that a CGI script is run as, when
# it's run from a normal browser.
#
# You can then "replay" that data against the same script, this time from the
# command line.  This allows you to see any error messages.   It also lets you
# see the output generated in real-time, so you can see timing of specific parts
# of the page.
#
# Or, you can apply the replay to an alternate (development) copy of the
# original script, which can allow you to debug problems.



# To capture some data, put this at the very top of your CGI script:
#       BEGIN {$^C or do "/home/myself/public_html/cgi-bin/replay/capture_CGI_input.pm"}
# and then run your script via the web.  The captured data will be dropped in
# the same directory as this script.
#
#
# There are two ways to replay a captured file:
#
#   1) From the command-line, go to the directory where the captured file is
#      at, and execute the capture file directly.  It will setup the environment
#      data, and then run the target script.
#
#   2) If the capture files are located under a /cgi-bin/, you can run them
#      directly from a web browser.  The original data overrides any data from
#      the new session (ie. the script thinks it's running under the original
#      user-agent, with the original POST data, etc).


    use strict;
    use warnings;


    use Cwd;
    use Data::Dumper;

sub capture_CGI_inputs {
    my ($restore_stdin, $filename) = @_;

    return if $ENV{RUNNING_INSIDE_CGI_REPLAY};

    local $Data::Dumper::Terse = 1;
    my %substitute = (
        PERL_BINARY => Cwd::abs_path($^X),
        ENV_CONTENTS => Dumper(\%ENV),
        CURDIR => Cwd::getcwd(),
        STDIN => "__DATA__\n" . do {local $/=undef; <STDIN>},
        CGI_SCRIPT => Dumper($0),
    );
    chomp $substitute{CGI_SCRIPT};

    my $out = <<'EOF';
#!<<PERL_BINARY>>

# pipe the __DATA__ section to this process's STDIN
if ($0 eq __FILE__ && $ARGV[0] eq 'DUMP_STDIN') {
    print <DATA>;
    exit;
}

%ENV = %{  <<ENV_CONTENTS>>  };
$ENV{RUNNING_INSIDE_CGI_REPLAY} = 1;        # don't capture again, if we're in the middle of replaying
open STDIN, '-|', $^X, __FILE__, 'DUMP_STDIN';        # pipe the __DATA__ section to this process's STDIN
chdir("<<CURDIR>>");

# if you pass an alternate script name (ie. for testing purposes), we'll run that instead
exec($ARGV[0] || <<CGI_SCRIPT>>);

<<STDIN>>
EOF

    $out =~ s/<<(\w+)>>/$substitute{$1}/eg;

    open CAPTURED, ">$filename" or http_error($! . " while trying to write to $filename");
    print CAPTURED $out;
    close CAPTURED;

    my $perm = (stat $filename)[2] & 07777;
    chmod($perm | 0111, $filename);       # chmod +x

    if ($restore_stdin) {
        # if we want to allow the currently-running CGI script to run unmolested, then we need to fix up the STDIN, since we've already gobbled it
        open STDIN, '-|', $^X, $filename, 'DUMP_STDIN';
    }
}


# only keep log files for a short time
sub expire_old_logs {
    my ($directory) = @_;

    my $max_age = 24 * 60 * 60;     # 24 hours (in seconds)

    foreach my $file (glob ("$directory/*.cgi")) {
        next unless -f $file;
        next unless ($file =~ m#/(\d+)\.\d+\.cgi$#);
        my $file_time = $1;
        #print "$file_time\t$file\n";
        next if ((time() - $file_time) <= $max_age);
        unlink($file);
    }
}


# for some reason, die() doesn't send logs to the right place
sub http_error {
    print "Content-type: text/plain\n\n", @_, "\n\n\n(generated from ", __FILE__, ")\n";
    exit;
}



# what directory is capture.pm located in?
my $this_dir = Cwd::abs_path(__FILE__);
$this_dir =~ s#[^/]+$##s;


capture_CGI_inputs(1, "$this_dir/" . time() . "." . $$ . ".cgi");

expire_old_logs($this_dir);

1;

