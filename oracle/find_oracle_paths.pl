#!/usr/bin/perl

# Looks for an Oracle Instant Client laying around somewhere, and figures out what environment
# settings are needed to use it.  If possible, it tries to get Perl's DBD::Oracle working.
#
# This script is a bit of a hacky heuristic, so it's not guaranteed to work.  But if it does work,
# it can save the user a lot of time.
#
# The information generated here can be put into the 'oraenv' file.

    use strict;
    use warnings;

    use Data::Dumper;

my @so_locations;
if (0 && $^O eq 'linux') {
    @so_locations = qx[ locate Oracle.so ];
} else {
    @so_locations = qx[ find    /usr/opt/oracle /usr/oracle  -name Oracle.so -print 2>/dev/null ];
            # note              ^^^^^^^^^^^^^^^^^^^^^^^^^^^
            #           These locations are just a heuristic, based on where Oracle seems to be
            #           found on our systems.  Oracle could easily be located elsewhere, so beware
            #           that this may fail to find Oracle sometimes.
}
@so_locations = map {s/\s*$//s; $_} @so_locations;
#print Dumper \@so_locations; exit;

if (!@so_locations) {
    die "No Oracle.so files found.  Looks like Oracle isn't installed here.\n";
}

if (0) {
    print "==== .so ====\n";
    print join("\n", @so_locations), "\n\n";
}

my @perl5libs = map {local $_=$_; s|/auto/DBD/Oracle/Oracle\.so$||; $_} @so_locations;

# ======== $ORACLE_HOME ========
my @oracle_homes = map {local $_=$_; s|/perl(-[^/]+)?/lib/.*|/|; $_} @perl5libs;
@oracle_homes = grep {-e "$_/bin/sqlplus"} @oracle_homes;

foreach my $oracle_home (@oracle_homes) {
    print "\n";
    print "# these values are determined with help from find_oracle_paths.pl\n";
    print "ORACLE_HOME=$oracle_home\n";
    my @exports = ("ORACLE_HOME");

    # ======== $PERL5LIB ========
    my @these_perl5libs = grep /^\Q$oracle_home\E/, @perl5libs;
    my ($perl_home) = uniq(map {local $_=$_; s|(/perl(-[^/]+)?/)lib/.*|$1|; $_} @these_perl5libs);
    my $perlbin = "${perl_home}bin/perl";
    @these_perl5libs = uniq(@these_perl5libs, construct_PERL5LIB($perlbin, "${perl_home}lib/"));
    #print_multiple_options('PERL5LIB', @these_perl5libs);
    my $PERL5LIB = join ":", @these_perl5libs;

    my @missing_libclntsh;
    my @these_so_locations = grep /^\Q$oracle_home\E/, @so_locations;
    foreach my $so (@these_so_locations) {
        push @missing_libclntsh, list_missing_dependencies($so);
    }
    @missing_libclntsh = uniq(@missing_libclntsh);
    #print Dumper \@missing_libclntsh;  exit;


    # ======== $LD_LIBRARY_PATH / $LIBPATH ========
    my $libpath_varname;
    if ($^O eq 'aix') {
        $libpath_varname = "LIBPATH";
    } else {
        $libpath_varname = "LD_LIBRARY_PATH";
    }
    my @libpaths;
    if (!@missing_libclntsh) {
        print "\t# ($libpath_varname not needed)\n";
    } else {
        #my $homes = join " ", map {"${_}lib*"} @oracle_homes;
        my $homes = join " ", map {"${_}lib*"} $oracle_home;
        my $missing = join " -o ", map {"-name $_"} @missing_libclntsh;
        my @found_libclntsh = qx[ find $homes $missing -print 2>/dev/null ];
        @found_libclntsh = map {s/\s*$//s; $_} @found_libclntsh;
        @libpaths = map {s|[^/]*$||s; $_} @found_libclntsh;
        #print "\t", join("\n\t", @libpaths), "\n";
        #print_multiple_options($libpath_varname, @libpaths);

        # test if all the above recommendations actually work
        my $found_good_libpath = 0;
        outer: foreach my $perl5lib_needed (0, 1) {
            foreach my $libpath ("", @libpaths) {
                my $p5l = "";
                if ($perl5lib_needed) {
                    $p5l = "PERL5LIB=$PERL5LIB";
                }
                my $lp = "";
                $lp = "$libpath_varname=$libpath" if ($libpath);
                system qq[$p5l $lp $perlbin -MDBI -e 'DBI->data_sources("Oracle")' 2>/dev/null ];
                if (! ($? >> 8)) {
                    $found_good_libpath = 1;
                    if ($perl5lib_needed) {
                        #print_multiple_options('PERL5LIB', @these_perl5libs);
                        push @exports, 'PERL5LIB';
                        print "PERL5LIB=\$(printf '\%s:\%s:\%s:\%s:\%s:\%s:\%s:\%s:\%s:\%s:\%s:\%s'\\\n";
                        print join(" \\\n",  map {"\t$_"} @these_perl5libs), " )\n";
                    }
                    print "$lp\n";
                    push @exports, $libpath_varname     if ($libpath);
                    print "export ", join(" ", @exports), "\n";

                    print "\t# (verified good)\n";
                    last outer;
                    #print "success!!\n";
                } else {
                    #print "\nfailed...\n";
                }
            }
        }
        if (!$found_good_libpath) {
            print_multiple_options('PERL5LIB', @these_perl5libs);
            print "$libpath_varname=        (unsure which is good)\n";
            print "\t", join("\n\t", @libpaths), "\n";
        }
    }
    print "\n\n";
}


# used when one environment variable might have different options, and we want to let the user choose which
sub print_multiple_options {
    my $env_var = shift;

    if (@_ == 0) {
        print "(no values found for $env_var)\n";
    } elsif (@_ == 1) {
        print "$env_var=$_[0]\n";
    } else {
        print "$env_var=\n";
        print "\t", join("\n\t", @_), "\n";
    }
}



# run ldd, find any missing deps
sub list_missing_dependencies {
    my ($bin) = @_;

    if ($^O eq 'aix') {
        my @missing = qx[ ldd "$bin" 2>&1 >/dev/null];
        @missing = grep /^\S/, @missing;
        @missing = grep /^Cannot find /, @missing;
        @missing = map {/^Cannot find ([^\(]*)/; $1} @missing;
        return @missing;
    } elsif ($^O eq 'linux') {
        my @missing = qx[ ldd "$bin" ];
        @missing = grep / => not found$/, @missing;
        @missing = map {s/ => not found\s*$//s; s/^\s*//; $_} @missing;
        return @missing;
    } elsif ($^O eq 'solaris') {
        my @missing = qx[ ldd "$bin" ];
        @missing = grep /\(file not found\)$| - wrong ELF class:/, @missing;
        @missing = map {s/^\s*//; s/ =>\s.*//s; $_} @missing;
        #print Dumper \@missing; exit;
        return @missing;
    } else {
        die "no support written for >>$^O<< yet";
    }
}



# This is purely a heuristic.  It should NOT be relied upon for production, unless a human first
# validates it.
sub construct_PERL5LIB {
    my ($perlbin, $libdir) = @_;

    # find the specific Config.pm
    (my $Config_pm = (qx[find "$libdir" -type f -name "Config.pm" -exec grep -l "package Config;" {} \\;])[0]) =~ s/\s*$//s;

    # load the Config.pm values
    #print "$perlbin\n"; exit;
    my %Config = split chr(0), qx[$perlbin -e 'require "$Config_pm"; print join(chr(0), \%Config::Config);'];
    $Config{archname} or die "Can't find Config.pm.\n";
    #print "(Config.pm)  $Config_pm\n";
    $Data::Dumper::Sortkeys = 1;
    if (0) {
        open FOUT, ">", "/tmp/config.pm";
        print FOUT Dumper \%Config;
        close FOUT;
    }
    #print Dumper \%Config; exit;
    0 && print "\$Config{prefix} = ",
       # $Config{prefix} || $Config{installprefix} || "",
        $Config{installprefix} || "",
        "\n";
    #print "\$Config{version} = $Config{version}\n";

    # look for all archname-related dirs
    my @arch = map {s/\s*$//s; $_} qx[find "$libdir" -type d -name "$Config{archname}*" -print];
    my @INC = uniq(@arch, map {local $_=$_; s|/[^/]*$||s; $_} @arch);

    # look for all dirs that have 'auto' under them
    my @auto = map {s/\s*$//s; $_} qx[find "$libdir" -type d -name "auto" -print];
    #print Dumper \@auto; exit;
    push @INC, map {s|/auto$||; $_} @auto;
    @INC = uniq(@INC);

    @INC = grep m/\/\Q$Config{version}\E(\/|$)/, @INC;

    #print Dumper \@INC; exit;

    return @INC;
}


# Removes duplicate elements from a list
sub uniq {my %seen; grep {!$seen{$_}++} @_}


