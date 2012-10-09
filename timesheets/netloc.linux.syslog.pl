#!/usr/bin/perl

# Scans the network logins from syslog, and try to guess where (geolocation) each login occurred.
# 
# This can help you in filling out timeslips, by figuring out where my computer was at the given time.

# NOTE: for this to work properly, you *must* customize geolocation() below so that it recognizes
#       the networks that you personally attach to frequently



# TODO:
#       - when we connect to a WIFI access point, the AP's MAC address is recorded...
#           we should try to parse this out, if possible.
#                   (search for:  /wpa_supplicant.*: Associated with/ )

    use strict;
    use warnings;

    use Date::Parse;
    use POSIX qw[strftime];

    use Data::Dumper;
    #use Devel::Comments;           # uncomment this during development to enable the ### debugging statements


my @accum;

foreach my $syslog_filename (reverse glob ("/var/log/syslog*")) {
    # ## $syslog_filename
    open my $fin, "-|", "gzip", "-dcf", $syslog_filename        or die $!;
    my $last_bound = '';
    while (<$fin>) {
        if (/NetworkManager\[\d+\]: <info>   /) {
            if (/NetworkManager\[\d+\]: <info>   address \S+$/) {
                #print;
                process_login(@accum)   if (@accum);
                @accum = ($last_bound, $_);
            } else {
                push(@accum, $_);
            }
        } elsif (/NetworkManager\[\d+\]: <info> .* -> (?:bound|renew|reboot)$/) {
            $last_bound = $_;
        }
    }
}
process_login(@accum)   if (@accum);


sub process_login {
    my @lines = @_;
    #print "-"x80, "\n", join ("", @lines), "\n"; return;

    ## figure out the network adapter
    my $firstline = shift @lines;
    my ($interface) = ($firstline =~ /NetworkManager\[\d+\]: <info> \((.*?)\)/);
    my ($dhcp_state) = (split ' ', $firstline)[-1];

    ## parse the fields
    my ($time) = ($lines[0] =~ /^(\S+\s+\S+\s+\S+)/);
    my $parsed_time = str2time($time);
    my $time_human = strftime('%a %b %e %H:%M', localtime($parsed_time));

    my %fields;
    foreach (@lines) {
        s/^.*NetworkManager\[\d+\]: <info>   //;
        s/^([a-z ]+[a-z])\s+//s;
        (my $field = $1) =~ s/ /_/g;
        chomp;
        s/^'(.*)'$/$1/s;
        push(@{$fields{$field}}, $_);
    }
    $fields{other} = {
            time       => $time,
            interface  => $interface,
            dhcp_state => $dhcp_state,
        };
    #print Dumper \%fields; return;

    ## determine geolocation
    my $geolocation = geolocation(\%fields);
    if ($geolocation =~ /^\?/) {
        print "ERROR: Unknown network.  You should customize geolocation() to recognize your network.\n";
        print Dumper \%fields;
    }

    ## output conclusion
    if ($geolocation) {
        $interface = "????"     if (!defined($interface));
        print "$time_human      $interface      $geolocation\n";
        #print "\t\t", scalar(localtime($parsed_time)), "\n";
    }
}


# determine the location of the IP address and such
#       (this is really designed to be user-edited)
sub geolocation {
    my %fields = %{ shift() };
    if ($fields{gateway}[0] =~ /\.254$/ && $fields{domain_name}[0] =~ /^(?:am|comm)\.mot\.com$/) {
        return 'Motorola';
    }
    return "Pumping Station One"        if ($fields{domain_name}[0] eq 'pumpingstationone.org');
    if ($fields{gateway}[0] eq '192.168.15.1' && $fields{domain_name}[0] eq 'local.tld') {
        return 'Clear modem';
    }
    return "? -- $fields{domain_name}[0]";
}
