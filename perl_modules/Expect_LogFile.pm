package Expect::LogFile;
our $VERSION = '0.90';

=head1 NAME

Expect::LogFile - add ability to send Expect.pm debug logs to a file

=head1 SYNOPSIS

  use Expect::LogFile;      # MUST be loaded before Expect.pm is
  use Expect;

  Expect::LogFile::logto("/tmp/somefilename");
  $Expect::Exp_Internal = 1;
  my $exp = Expect->spawn($command, @params);

=head1 DESCRIPTION

Expect.pm normally outputs its debug logs with a combination of STDERR and cluck().  This adds the
ability to redirect those to a file, without redirecting STDERR and hiding other STDERR
warnings/errors you might be interested in showing to the user.

Unfortunately, it's not possible to log messages from only one $exp object -- parts of Expect.pm
operate across multiple Expect objects at once.  As such, ALL log messages generated are sent to the
same file.

=head1 AUTHOR

Dee Newcum

=cut


    use strict;
    use File::Spec;
    use Symbol;

our $log_filehandle;

BEGIN {
    if (exists $INC{'Expect.pm'}) {
        # too late
        warn "ERROR:  Expect::LogFile *must* be loaded before loading Expect.pm.\n";
        exit;
    }
}

# inspired by https://metacpan.org/module/everywhere
use lib sub {
    my ($self, $file) = @_;
    if ($file =~ /^Expect\.pm$/) {
        foreach my $dir (@INC) {
            next if ref $dir;
            my $full = File::Spec->catfile($dir, $file);
            if(open my $fh, "<", $full) {
                my @lines = <$fh>;
                close $fh;
                unshift @lines, "#line 1 \"$full\"\n";
                @lines = modify_file(@lines);
                my $changed = join('', @lines);
                open my $fh_changed, '<', \$changed or die $!;
                return $fh_changed;
            }
        }
    }
    return undef;
};


sub modify_file {
    my @lines = @_;

    for (my $ctr=0; $ctr<=$#lines; $ctr++) {
        local $_ = $lines[$ctr];
        if (/^\s*package\s+Expect\b/) {
            $ctr++;
            splice(@lines, $ctr, 0,
                    q{      sub STDERR_logger {Expect::LogFile::log(@_)}      } . "\n");
        }
        $lines[$ctr] =~ s/^(\s*)print\s+STDERR\s/$1STDERR_logger /;
        $lines[$ctr] =~ s/^(\s*)cluck\b/$1STDERR_logger /;
    }

    #print $fout join('', @lines); exit;

    return @lines;
}


sub logto {
    my ($filename) = @_;
    open $log_filehandle, '>>', $filename   or die $!;
}


sub log {
    print $log_filehandle @_;
}

1;
