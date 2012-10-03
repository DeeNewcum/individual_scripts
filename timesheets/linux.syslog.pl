#!/usr/bin/perl

# Calculate computer boot/shutdown times from /var/log/syslog*.
# 
# It can detect these events:
#       - system boot
#       - system shutdown
#       - sleep-enter
#       - sleep-exit
#       - (probably more, but that's all that's tested right now)


    use strict;
    use warnings;

    use HTTP::Date;         # VERY likely to be installed, since it's a dependency of CPAN and LWP
    use POSIX;
    use Data::Dumper;


my $last_day = '';

scan_syslogs(sub {
    my ($date, $event) = @_;

    my $this_day = POSIX::strftime('%F', localtime($date));
    print "\n" if ($this_day ne $last_day);
    $last_day = $this_day;

    printf "%-20s %s\n",
        POSIX::strftime('%a %b %d  %H:%M', localtime($date)),
        $event;
});



# scan all the syslogs, looking for events having to do with startup/shutdown or sleep/wake
sub scan_syslogs {
    my ($callback) = @_;

    foreach my $syslog (sort {firstnum($b) <=> firstnum($a)} glob '/var/log/syslog*') {
        my $fin;
        if ($syslog =~ /\.gz$/) {
            open $fin, '-|', 'gzip', '-dc', $syslog      or die $!;
        } else {
            open $fin, '<', $syslog      or die $!;
        }
        while (<$fin>) {
            my %entry = %{parse_syslog_line($_) or next};
            my $status;
            if ($entry{program} eq 'rsyslogd') {
                $entry{text} =~ s/^(\[.*?\])\s*//  and $entry{origin} = $1;
                next unless ($entry{text} eq 'exiting on signal 15.' || $entry{text} eq 'start');
                #print Dumper \%entry;
                if ($entry{text} eq 'start') {
                    $status = 'boot';
                } else {
                    $status = 'shutdown';
                }
            }
            if ($entry{program} eq 'kernel') {
                $entry{text} =~ s/^\[(.*?)\]\s*//  and $entry{time_since_boot} = $1;
                #print $entry{line};
                #print Dumper \%entry;
                if ($entry{text} eq 'PM: Preparing system for mem sleep') {
                    $status = 'sleep';
                } elsif ($entry{text} eq 'PM: Finishing wakeup.') {
                    $status = 'wake';
                } elsif ($entry{text} =~ /init: tty1 main process \(\d+\) killed by TERM signal/) {
                    $status = 'shutdown';
                }
            }
            if (defined($status)) {
                $callback->($entry{date}, $status);
            }
        }
    }
}


# parse one line of text from /var/log/syslog
sub parse_syslog_line {
    # see full regexp at Parse::Syslog::_next_syslog()
    $_[0] =~ /^(\S{3}\s+\d+\s\S+)\s+([-\w\.\@:]+)\s+([^:]+?)(?:\[(\d+)\])?:\s+(.*)/
        and {date_human => $1, date => str2time($1), host => $2, program => $3, pid => $4, text => $5, line => $_[0]};
}


# extract the first number found within a string
sub firstnum {(shift =~ /(\d+)/)[0] || 0}
