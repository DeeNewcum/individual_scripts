#!/usr/bin/perl

    use strict;
    use warnings;

    #use Data::Dumper();   use Perl::Tidy;
    #sub Dumper {perltidy source=>\(Data::Dumper::Dumper@_),destination=>\(my$t);$t}

    use Data::Dumper;

    $Data::Dumper::Quotekeys = 0;
    $Data::Dumper::Sortkeys  = 1;



# find the list of all files to process
foreach my $ctr (reverse 1..99) {
    if (-e "/var/log/wtmp.$ctr") {
        process_wtmp("/var/log/wtmp.$ctr");
    } elsif (-e "/var/log/wtmp.$ctr.gz") {
        die "Please run this command:\n\tsudo gzip -d /var/log/wtmp.$ctr.gz\n";
    }
}
process_wtmp("/var/log/wtmp");





sub process_wtmp {
    my $filename = shift;

    my @entries = parse_wtmp($filename);
    #die Dumper \@entries;
    foreach my $entry (@entries) {
        #print Dumper $entry; next;
        printf "%-30s  %-15s  %-15s  %-20s  %-20s\n",
            $entry->{tv_human},
            $entry->{user},
            $entry->{line},
            $entry->{host},
            $entry->{type_str};
    }
}


        use constant UT_TYPE => {       # see 'ut_type' in wtmp(5)
            1 => 'RUN_LVL',        # Change in system run-level (see init(8))
            2 => 'BOOT_TIME',      # Time of system boot (in ut_tv)
            3 => 'NEW_TIME',       # Time after system clock change (in ut_tv)
            4 => 'OLD_TIME',       # Time before system clock change (in ut_tv)
            5 => 'INIT_PROCESS',   # Process spawned by init(8)
            6 => 'LOGIN_PROCESS',  # Session leader process for user login
            7 => 'USER_PROCESS',   # Normal process
            8 => 'DEAD_PROCESS',   # Terminated process
            9 => 'ACCOUNTING',     # Not implemented
        };
sub parse_wtmp {
    my ($filename) = shift  || '/var/log/wtmp';

    # 'c2ph' was used to generate this,
    # with help from dump_size_offset() to confirm/fix alignment:
    #       http://paperlined.org/dev/perl/modules/related_modules/more_complex_than_pack.html
    my ($fnames, $ftypes) = unzip(qw_comments(<<'EOF'));
        type    l           # short int                 type of login (0 through 9); see wtmp(5)
        pid     i           # pid_t                     PID of login process
        line    Z32         # char[UT_LINESIZE]         device name of TTY
        id      Z4          # char[4]                   terminal name suffix, or inittab ID
        user    Z32         # char[UT_NAMESIZE]         username
        host    A256        # char[UT_HOSTSIZE]         hostname (if remote login)
        exit    l           # struct exit_status        exit status of a process when ut_type==DEAD_PROCESS
        session l           # long int                  session ID, used for windowing
        tv_sec  i           # struct timeval.tv_sec     time this entry was made
        tv_usec i           # struct timeval.tv_usec
        addr_v6 a16         # int32_t[4]                internet address of remote host; IPv4 address uses just ut_addr_v6[0]
        unused  Z20         # char[20]                  reserved for future use
EOF
    $ftypes = join(" ", @$ftypes);
    open my $fin, '<', $filename    or die $!;
    local $/ = \(length pack $ftypes);       # read fixed-length records
    my @entries;
    while (<$fin>) {
        my %ent;
        @ent{@$fnames} = unpack $ftypes, $_;
        $ent{tv_human} = ~~localtime $ent{tv_sec};
        if (!grep {$_} unpack 'x4L3', $ent{addr_v6}) {     # if the last 12 bytes are all-zero, then it's an IPv4 address
            $ent{addr_human} = join '.', unpack 'C4', $ent{addr_v6};
        } else {
            $ent{addr_human} = join ':', unpack 'H4H4H4H4H4H4H4H4', $ent{addr_v6};
        }
        $ent{type_str} = UT_TYPE->{ $ent{type} };
        push @entries, \%ent;
    }
    return @entries;
}



# split [1,'a',2,'b',3,'c'] into [[1,2,3],['a','b','c']]
sub unzip {my($i,$j)=(0,0); [grep{++$i%2}@_],[grep{$j++%2}@_]}

# Like qw[...], but it allows use of comments (hash symbol).
sub qw_comments {local$_=shift;s/\s+#.*//gm;split}
