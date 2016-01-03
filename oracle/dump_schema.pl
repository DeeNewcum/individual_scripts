#!/bin/sh
                export PERL5LIB=
                . $(perl -e'print((getpwnam"interiot")[7])')/oraenv      # source ~interiot/oraenv
                exec $ORACLE_HOME/perl/bin/perl -x "$0" "$@";  exit
#!/usr/bin/perl
#line 6


##
## Will dump the schema of any DBI-supported database.
## That is, a list of databases, tables, columns, and column descriptions (if any).
##
## For a complex database, it can be useful to dump this to a .txt file, and refer to it often.
##

	use strict;
	use warnings;

	use DBI;
	use Data::Dumper;

my $database = "db_hostname";
my $user     = "interiot";





my $passwd = slurp("$ENV{HOME}/.password.$database.$user");
chomp $passwd;


my $dbh = do {
    local $SIG{INT};            # workaround the problem that Oracle libraries take over SIGINT
    my $dbh = DBI->connect("dbi:Oracle:$database", $user, $passwd)
        or die "Couldn't connect to database: " . DBI->errstr;
};


#my @results = $dbh->selectall_listofhashes("SELECT DISTINCT OWNER FROM ALL_OBJECTS");
#print Dumper \@results;


#my $sth = $dbh->table_info('', '%', '');
#my $schemas = $dbh->selectcol_arrayref($sth, {Columns => [2]});
#print "Schemas: ", join ', ', @$schemas;
#exit;



my $dumpschem = DumpSchema::Oracle->new($dbh);


print <<'EOF';
In Vim, to enable folding, run this:

    set foldmethod=expr | set foldexpr=(getline(v:lnum)=~'^##.*\\s')?'>1':(getline(v:lnum)=~'^==')?'>2':'=' | set foldlevel=0

EOF

my @toplevel = $dumpschem->list_top_level();
foreach my $toplevel (sort @toplevel) {
	print multiline_header("################################ $toplevel ################################", 2);
	print "\n";
	my @tables = $dumpschem->list_tables($toplevel);
	foreach my $table (sort @tables) {
		print "======== $table ========\n";
		my $descr = $dumpschem->describe_table($toplevel, $table);
		$descr =~ s/^/    /mg;
		print $descr;
		print "\n";
	}
}





# DBI has selectall_arrayref() and selectall_hashref(), but no selectall_listofhashes().  Fix that.
sub DBI::db::selectall_listofhashes {my($dbh,$stmt,$attr,@bind)=@_;@{$dbh->selectall_arrayref($stmt,{%{$attr||{}},Slice=>{}},@bind)}}
sub DBI::st::fetchall_listofhashes {my($sth,$max_rows)=@_;@{$sth->fetchall_arrayref({},$max_rows)}}

# quickly read a whole file         (does what File::Slurp and IO::All->slurp() do)
sub slurp {my$p=open(my$f,"$_[0]")or die"$! -- $_[0]\n";my@o=<$f>;close$f;waitpid($p,0);wantarray?@o:join("",@o)}




# prints a three-line header, with a character that surrounds on the left, right, top, and bottom
sub multiline_header {
	my ($middle_line, $num_above) = @_;
	$num_above = 1 	unless defined($num_above);
	my $top_bot_line = substr($middle_line, 0, 1) x length($middle_line) . "\n";
	$top_bot_line = $top_bot_line x $num_above;
	return "$top_bot_line$middle_line\n$top_bot_line";
}



package DumpSchema;

	use List::Util qw(max);


sub new {
	my ($class, $dbh) = @_;
	my $self = {
		dbh => $dbh,
	};
	bless $self, $class;
}


sub list_top_level {
	# This sub is expected to list a list of top-level items.
	# Often, the top-level is termed "databases", but different DBMSs have different terms for them.
	# (eg. in Oracle, they're "schemas")
}


sub list_tables {
	# List all the tables for the specified top-level item.
}


sub describe_table {
	# Describe the specified table in as much detail as possible.  The output
	# is a string scalar (or list, which will be combined with newlines to create a scalar).
	# 
	# The data is free-form, and isn't interpretted by the machine in any way.  Feel free
	# to make it only human-readable.
}


# Renders a table for human consumption, much like SQL*Plus or other text-based SQL results displayers.
# This calculates how wide each column needs to be, and then displays all the columns.
#
#	$column_order		array-ref, list of the column names
#	$table			list-of-hashes;  the list is a list of rows, and each hash is the contents of that row, with the key being the column name, and the value being the column value
sub render_table {
	my ($table, $column_order) = @_;
	my %whichcol;	# maps colname => col position
	for (my $ctr=0; $ctr<scalar(@$column_order); $ctr++) {
		$whichcol{$column_order->[$ctr]} = $ctr;
	}
	my @col_maxlen;		# maximum length of each column, in characters
	foreach my $col (@$column_order) {
		$col_maxlen[$whichcol{$col}] = length($col);
	}
	foreach my $row (@$table) {
		while (my ($col, $value) = each %$row) {
			$col_maxlen[$whichcol{$col}] = max(
				$col_maxlen[$whichcol{$col}],
				length(scalar($value || ''))
				);
		}
	}
	#print Data::Dumper::Dumper \@col_maxlen; exit;
	my $ret = "";
	$ret .= render_table_row(\@col_maxlen, $column_order);
	$ret .= render_table_row(\@col_maxlen, [ map {"-"x$_} @col_maxlen ]);
	foreach my $row (@$table) {
		my @cols;
		while (my ($col, $value) = each %$row) {
			$cols[$whichcol{$col}] = $value || '';
		}
		$ret .= render_table_row(\@col_maxlen, \@cols);
	}
	return $ret;
}
	sub render_table_row {
		my ($col_maxlen, $row) = @_;
		my $ret = "";
		for (my $ctr=0; $ctr<scalar(@$col_maxlen); $ctr++) {
			my $len = $col_maxlen->[$ctr];
			$ret .= sprintf "%-${len}s ", $row->[$ctr] || '';
		}
		$ret .= "\n";
		return $ret;
	}



	

package DumpSchema::Oracle;

	use base "DumpSchema";

sub list_top_level {
	my $dbh = $_[0]{dbh};

	my $rows = $dbh->selectall_arrayref("SELECT DISTINCT owner FROM all_objects");
	return map {$_->[0]} @$rows;
}


sub list_tables {
	my $dbh = shift()->{dbh};
	my ($top_level_name) = @_;

	my $rows = $dbh->selectall_arrayref("select table_name from all_tables WHERE owner = '$top_level_name'");
	return map {$_->[0]} @$rows;
}


# The user should cut-n-paste the latest entry from tnsnames.ora, verbatim.
# However, we need to move the SID name to a different place before it can work
# in a DBI->connect() call.
sub fix_tnsnames {
    my ($tnsname) = @_;
    $tnsname =~ s/^\s*(\S[^=]*)=//s;
    my $sid = $1;
    $tnsname =~ s/(\(\s*connect_data\s*=)/$1(sid=$sid)/s;
    return $tnsname;
}



sub describe_table {
	my $dbh = shift()->{dbh};
	my ($top_level_name, $table) = @_;

	my ($table_comment) = $dbh->selectrow_array("SELECT comments FROM all_tab_comments WHERE owner=? AND table_name=?",
			{},
			$top_level_name, $table);
	if (defined($table_comment)) {
		$table_comment = "table comment:  $table_comment\n";
	} else {
		$table_comment = "";
	}

	# describe <tablename> doesn't work over SQL!  That's an SQL*Plus internal thing
	#my $rows = $dbh->selectall_arrayref("SELECT column_name, data_type, data_length, nullable FROM all_tab_columns WHERE owner=? AND table_name=?",
	#my $rows = $dbh->selectall_arrayref("SELECT column_name, data_type, nullable FROM all_tab_columns LEFT JOIN all_col_comments ON WHERE owner=? AND table_name=?",
	my $rows = $dbh->selectall_arrayref("SELECT s.column_name, data_type, data_length, nullable, comments FROM all_tab_columns s LEFT JOIN all_col_comments c ON s.owner=c.owner AND s.table_name=c.table_name AND s.column_name=c.column_name WHERE s.owner=? AND s.table_name=?",
			{Slice=>{}},
			$top_level_name, $table);

	#print Data::Dumper::Dumper $rows; exit;
	return $table_comment
		. DumpSchema::render_table($rows,
			[qw[  COLUMN_NAME DATA_TYPE DATA_LENGTH NULLABLE COMMENTS ]]);
}


__END__
:endofperl
