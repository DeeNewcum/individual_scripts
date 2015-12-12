#!/bin/sh
    . $(perl -e'print((getpwnam"interiot")[7])')/oraenv      # source ~interiot/oraenv
    exec ${ORAPERL:-$ORACLE_HOME/perl/bin/perl} -x "$0" "$@";  exit
#!/usr/bin/perl
#line 6

## This is a "Hello World"-level example of running a query via Oracle, within Perl.
## The first three lines ensure that it works even when running from within Cron,
## or when run by a user who doesn't have an 'oraenv' properly setup.

    use DBI;
    use Data::Dumper;

my $database = "database";
my $user     = "username";
my $passwd   = "password";

my $dbh = DBI->connect("dbi:Oracle:$database", $user, $passwd)
        or die "Couldn't connect to database: " . DBI->errstr;

my $example_query = "SELECT DISTINCT owner FROM all_objects";
my @results = $dbh->selectall_listofhashes($example_query);

print Dumper \@results;


# DBI has selectall_arrayref() and selectall_hashref(), but no selectall_listofhashes().  Fix that.
sub DBI::db::selectall_listofhashes {my($dbh,$stmt,$attr,@bind)=@_;@{$dbh->selectall_arrayref($stmt,{%{$attr||{}},Slice=>{}},@bind)}}
sub DBI::st::fetchall_listofhashes {my($sth,$max_rows)=@_;@{$sth->fetchall_arrayref({},$max_rows)}}
