#!/usr/bin/perl

# This is one portion of a two-part strategy to encourage me to keep my website blocks enabled on my
# work computer. Part one -- be able to block various websites, both via the Windows 'hosts' file,
# and via Windows Defender Firewall. See
# https://paperlined.org/life_skills/work_productivity/website_blockers_2022_Aug.md for more.
#
# However, it's extremely difficult to create a lock that I myself can't unlock. And in practice, I
# sometimes have a strong motivation to disable the website blocks.
#
# That's where part two comes in -- the "Accountability Logger". It simply records what percentage
# of the day that the website blocks are enabled. The reason this works is that I have much less
# motivation to disable this particular program in the moment.
#
# This script is intended to be run under Cygwin, but Strawberry Perl might work as well.





# To create a new Cygwin service for this script:
# 
# 1. make sure the Cygwin packages 'perl-Win32-API' and 'perl-Path-Tiny' are installed
#
# 2. start Cygwin with Administrator privileges (right-click and choose "Run as administrator")
#
# 3. run:
#
# cygrunsrv.exe -I AccountabilityLogger -d "CYGWIN AccountabilityLogger" --user AD\\newcum -p /home/newcum/src/pl/accountability_logger/accountability_logger.pl --type auto
#
#
#
# To remove the service:
#
# cygrunsrv.exe -R AccountabilityLogger



# Where I left off:
# 
# The event viewer provides this information about why the service fails to start:
#
#   "This computer is configured as a member of a workgroup, not as a member of a domain. The
#   Netlogon service does not need to run in this configuration."
#
# OOOOh damn. Using end-user logons for Services might actually be explicitely disabled.
#       https://learn.microsoft.com/en-us/system-center/scsm/enable-service-log-on-sm?view=sc-sm-2022

    use strict;
    use warnings;

    use 5.10.0;         # the defined-or operator is awfully handy

    use FindBin ();
    use List::Util qw(min);
    use Net::Ping ();
    use Path::Tiny;
    use POSIX qw(strftime);
    use Socket qw(inet_ntoa);
    use Storable ();
    
    BEGIN {
        eval "use Win32::API";
        if ($@) {
            if ($^O eq 'cygwin') {
                print STDERR "You need to install the Cygwin package 'perl-Win32-API'.\n";
            } else {
                print STDERR "Module Win32::API is unavailable.\n";
            }
            exit;
        }

        eval "use Path::Tiny";
        if ($@) {
            if ($^O eq 'cygwin') {
                print STDERR "You need to install the Cygwin package 'perl-Path-Tiny'.\n";
            } else {
                print STDERR "Module Path::Tiny is unavailable.\n";
            }
            exit;
        }
    }

    use Data::Dumper;


if (getpwuid($<) eq 'SYSTEM') {
    # Unfortunately GetLastInputInfo() won't work properly unless it's run as your own account.
    die "This must be run under your NORMAL USER ACCOUNT, otherwise this won't be able\n"
        . "to monitor your idle time.\n";


    ## TODO -- erase this whole section
    # If we're running as a service, then restart ourselves, running under the desired user.
    # This MUST be the same user as the real-live person logged in, otherwise the
    # GetLastInputInfo() call below will fail.
    #my $cygwin_bat = `cygpath -w /Cygwin.bat`;
    #my $bash_from_windows = `cygpath -w \$(type -p bash)`;
    #my $cmd = "runas /user:newcum\@ad $bash_from_windows";
    #print "running -- $cmd\n";
    #exec $cmd;
    #die "failed to exec: $!\n";
}

print "uid: $<\n";
print "username: ", scalar(getpwuid($<)), "\n";


# is one of the long list of DNS names located in C:\Windows\System32\drivers\etc\hosts blocked?
sub is_one_DNS_blocked {
    my $hostname = shift;

    my $packed_ip = gethostbyname($hostname);
    my $ip = inet_ntoa($packed_ip);
    #print "$hostname  >>$ip<<\n";

    return ($ip eq '127.0.0.1');
}


# are the long list of DNS names located in C:\Windows\System32\drivers\etc\hosts blocked?
sub is_DNS_blocked {
    # return true only if all of these hostnames are blocked
    foreach my $hostname (qw(facebook.com reddit.com vox.com twitter.com feedly.com)) {
        if (!is_one_DNS_blocked($hostname)) {
            #print STDERR "is_DNS_blocked() bailing because of hostname >>$hostname<<\n";
            return 0;
        }
    }
    return 1;
}


# is the IP address for paperlined.org blocked within Windows Defender Firewall?
sub is_paperlined_org_blocked {
    my $p = Net::Ping->new("tcp", 2);
    # Try connecting to the ssh port instead of the echo port
    $p->port_number(scalar(getservbyname("ssh", "tcp")));
    return !$p->ping('paperlined.org');
}


# run a check on both DNS and paperlined.org, and summarize the results
#
# returns:
#   0 -- neither DNS nor paperlined.org blocked
#   1 -- just DNS is blocked
#   2 -- just paperlined.org is blocked
#   3 -- both DNS and paperlined.org are blocked
sub is_blocked {
    my $dns = is_DNS_blocked();
    my $paperlined = is_paperlined_org_blocked();

    return ($dns ? 1 : 0) + ($paperlined ? 2: 0);
}


# Generate the name of the file that the Storable data should go into. There's a separate file for
# each day.
sub day_filename {
    # the first argument is optional, and defaults to the current time
    my $when = shift // time();
    my $path = Path::Tiny::path($FindBin::RealBin);
    return $path->child(POSIX::strftime('%Y%m%d.storable', localtime($when)))->stringify;
}


# run a check about what is blocked, and then update the log file
sub check_and_log {
    # check...
    my $blocked = is_blocked();

    # ...and log
    my $filename = day_filename();
    my $storable = -e $filename ? Storable::retrieve($filename) : {records => []};
    push @{$storable->{records}}, [time(), $blocked];
    summarize_records($storable);
    Storable::nstore($storable, $filename);

    update_calendar_report();
}


# runs _summarize_records_bitmask() for each of the three bitmasks
sub summarize_records {
    my $storable = shift;

    foreach my $bitmask (1..3) {
        _summarize_records_bitmask($storable, $bitmask);
    }
}


# Scan over the entire $storable->{records} for one 24-hour day, and generate the info found in
# $storable->{summary}.
#
# This generates a number from 0.0 to 1.0, indicating the fraction of the day that the blocks were
# enabled.
sub _summarize_records_bitmask {
    my $storable = shift;
    my $bitmask = shift;

    # Two options:
    #   - count the total number of seconds, from the first record to the last record, and compare
    #     to the total number of "false" seconds
    #   - count the total number of seconds in the day (9am to 5pm), compare to the total number of
    #     "true" seconds

    my $true_seconds = 0;
    my $false_seconds = 0;
    if (1) {
        # option #1 -- count the total number of seconds, from the first record to the last record,
        #              and compare to the total number of "false" seconds

        if (@{$storable->{records}}) {
            my $ctr;
            for ($ctr=0; $ctr<@{$storable->{records}}-1; $ctr++) {
                my $duration = $storable->{records}[$ctr+1][0] - $storable->{records}[$ctr][0];
                # if there's a gap in reports that's longer than 120 seconds, then only count the first
                # 120 seconds of that gap
                $duration = min($duration, 120);
                my $state = ($storable->{records}[$ctr][1] & $bitmask) == $bitmask;
                if ($state) {
                    $true_seconds += $duration;
                } else {
                    $false_seconds += $duration;
                }
                #printf "%5d  %5d\n", $true_seconds, $false_seconds;
            }

            my $final_state = ($storable->{records}[$ctr][1] & $bitmask) == $bitmask;
            my $duration = 120;        # we don't know how long the last duration lasted, so we'll assume 120 seconds
            if ($final_state) {
                $true_seconds += $duration;
            } else {
                $false_seconds += $duration;
            }
            #printf "%5d  %5d\n", $true_seconds, $false_seconds;
        }
    } else {
        # option #2 -- count the total number of seconds in the day (9am to 5pm), compare to the
        # total number of "true" seconds
        die "TODO: implement this";
    }


    my $total_seconds = $true_seconds + $false_seconds;
    if ($total_seconds == 0) {
        # this would have resulted in a divide-by-zero error
        $storable->{summary}{$bitmask} = 0;
    } else {
        $storable->{summary}{$bitmask} = $true_seconds / $total_seconds;
    }
    $storable->{summary}{total} = $total_seconds;
    #printf "==== %f\n", $storable->{summary}
}


# update the last-30-days report, the one that looks like a calendar
sub update_calendar_report {
    my $report_filename = Path::Tiny::path($FindBin::RealBin)->child('report.html')->stringify;
    open my $report, '>', $report_filename
        or die "Unable to open '$report_filename': $!\n";
    my $curtime = time();

    state $is_first_time = 1;
    if ($is_first_time) {
        print "Writing report to $report_filename\n";
        $is_first_time = 0;
    }

    # we need to depict a visual calendar, in HTML
    print $report <<'EOF';
<style>
    table {
        font-size: 140%;
    }
    td.pre_table {
        border: none;
        font-size: 120%;
        padding-bottom: 0.5em;
    }
    th {
        font-size: 90%;
    }
    td {
        width: 2.8em;
        vertical-align: top;
        text-align: center;
    }
    td div.daynum {
        font-size: 70%;
        color: #b08400;
        text-align: left;
    }
    td.outofbounds {background-color:#ddd}
    td.evenmonth {background-color:#deffe1}
    td.oddmonth  {background-color:#ffdefd}
    td.post_table {
        text-align: justify;
        border: none;
        padding: 1.5em 0;
        font-size: 80%;
    }

    /* --==##  table cells have a nice border  ##==-- */
    table {border-collapse:collapse}
    table td, table th {border:1px solid #aaa; padding:0.3em}
    table th {background-color:#666; color:#fff}
    table th a {color:#aaf}
    table th a:visited {color:#faf}
    table tr.header td, table thead td {border:#fff}
</style>
<body>
<table>
<tr><td colspan=7 class="pre_table">Accountability Logger
<tr><th>Sun <th>Mon <th>Tue <th>Wed <th>Thu <th>Fri <th>Sat
<tr>
EOF

    # add any padding spaces needed before the first day
    my $first_day = $curtime - 30*86400;
    my $first_wday = (localtime($first_day))[6];
    if ($first_wday > 0) {      # we don't need to pad if the first day is Sunday0
        for (my $ctr=0; $ctr<$first_wday; $ctr++) {
            print $report "<td class='outofbounds'>\n";
        }
    }

    foreach my $day_offset (-30..0) {
        my $day = $curtime + $day_offset * 86400;
        my @day = localtime($day);
        my %day;
        @day{qw[sec min hour mday mon year wday yday isdst]} = @day;
        my $storable_filename = day_filename($day);
        my $storable = -e $storable_filename ? Storable::retrieve($storable_filename) : {};

        if ($day{wday} == 0 && $day > $first_day) {
            print $report "<tr>";
        }

        my $day_num = $day{mday};
        # the number for the first day should be replaced with the abbreviated month name
        if ($day{mday} == 1 || $day == $first_day) {
            $day_num = POSIX::strftime("%b", @day);
        }

        my $month_class = $day{mon} % 2 ? 'evenmonth' : 'oddmonth';

        my $black_text = '<br><br>';
        if (exists($storable->{summary}{3})) {
            $black_text = sprintf("%d:%02d<br>%d%%",
                        $storable->{summary}{total} / 3600,             # hours
                        int($storable->{summary}{total} / 60) % 60,     # minutes
                        100 * $storable->{summary}{3});
        }

        print $report "<td class='$month_class'><div class='daynum'>$day_num</div>$black_text</td>\n";
    }

    # add any padding spaces after the last day
    my $last_wday = (localtime($curtime))[6];
    foreach my $ctr (($last_wday+1)..6) {
        print $report "<td class='outofbounds'>\n";
    }

    my $timestamp = POSIX::strftime("%I:%M %p", localtime($curtime));
    $timestamp =~ s/^0//;
    #print $report "</table>\n";
    print $report "<tr><td colspan='7' class='post_table'>\n";
    print $report "The top number is the total time that my work laptop was actively used. ";
    print $report "The bottom number is the percentage of that time that the website blocks were enabled.\n";
    print $report "<p>There are numerous caveats, among them — that websites being blocked doesn't necessarily equate ",
                  "to productivity, and that time spent on my cellphone and personal laptop isn't captured here. ",
                  "Keep in mind Campbell's law, which says ",
                  "\"The more a metric is used, the more likely it is to corrupt the process it is intended to monitor\". ",
                  "Basically, metrics will inevitably be gamed, in ways large and small.\n";
    print $report "<p><span style='color:#ccc'>last updated $timestamp</span>\n";

    close $report;
}


BEGIN {
    my $GetLastInputInfo = Win32::API->new("user32.dll",'GetLastInputInfo','P','I');
    my $GetTickCount = Win32::API->new("kernel32.dll",'GetTickCount','','I');

    # TODO: from the manual, "However, GetLastInputInfo does not provide system-wide user input
    #       information across all running sessions. Rather, GetLastInputInfo provides
    #       session-specific user input information for only the session that invoked the function."
    # https://cygwin.com/pipermail/cygwin/2001-December/067466.html

    sub get_user_idle_time {
        my $buffer = pack "VV", 8,0;
        $GetLastInputInfo->Call($buffer)
            or die "Couldn't call GetLastInputInfo: $^E";
        my ($size,$time) = unpack "VV", $buffer;
        my $now = $GetTickCount->Call;

        # Adjust time to return a reference in seconds
        return int (($now-$time) / 1000);
    }
}



# work as a "modulino", as brian d foy defines it
# https://www.drdobbs.com/scripts-as-modules/184416165
if (!caller()) {

    # this is what should be considered the main() function

    #print Dumper [is_DNS_blocked(), is_paperlined_org_blocked()];
    #print Dumper [is_blocked()];
    #print day_filename(), "\n";
    #update_calendar_report();

    while (1) {
        my $seconds_idle = get_user_idle_time();
        if ($seconds_idle < 2 * 60) {
            check_and_log();
            $|++;
            print ".";
        } else {
            $|++;
            print "X";
        }
        sleep(60);
    }

} else {
    # We were called via 'do' for testing purposes, not called as a normal script. Load in the code
    # at the bottom of this file.
    eval join('', <DATA>);      # slurp in all lines at once
}






__DATA__


# work as a "modulino", as brian d foy defines it
# https://www.drdobbs.com/scripts-as-modules/184416165
#
# to run all test routines, run this at the command-line:
#       perl -e'do "./accountability_logger.pl"; tests();'
sub tests {
    one_test(<<'EOF');

        1670613052	3
        1670613102	1
        1670613242	1
        1670613332	3
        1670613342	3
        1670613482	0
        1670613612	3
        1670613652	1
        1670613742	0

EOF
}

sub one_test {
    my ($here_doc) = @_;
    my $storable = test_parse_records($here_doc);
    summarize_records($storable, 3);
    print Dumper $storable;
}


sub test_parse_records {
    my ($here_doc) = @_;
    my $storable = {};
    foreach my $line (split /[\n\r]+/s, $here_doc) {
        $line =~ s/^\s+|\s+$//sg;
        my @fields = split ' ', $line;
        push @{$storable->{records}}, [int($fields[0]), int($fields[1])];
    }
    #print Dumper $storable;
    return $storable;
}
