#!/usr/bin/perl

# Looks for regexp matches within a local mirror of CPAN.
#
# Designed to work with CPAN::Mini.
#
# Searches through .tar.gz'd files, so this takes a lot of CPU and some clock time.  However, it minimizes long-term disk space.
#
# To install all prerequisites, you'll probably want to run:
#
#       cpanm CGI::Tiny Pod::Parser Text::LineNumber



# TODO:
#
#       - integrate  https://metacpan.org/dist/PPIx-Grep/view/bin/ppigrep   into this?
#                       or  https://metacpan.org/dist/App-Grepl/view/bin/grepl  ?
#           - or just do like Perl::Metrics::Simple::Analysis::File does, and 1) parse with PPI, and
#             2) use PPI to prune all comments, pod, and anything after __END__:
#                https://github.com/matisse/Perl-Metrics-Simple/blob/3b8ce3f/lib/Perl/Metrics/Simple/Analysis/File.pm#L378-L388
#
#       - important -- for domain=unlimited searches, it should DETERMINE IF THE MATCH was in documentation-only or not
#               - this documentation-only flag should be shown on reports, particularly the HTML report
#               - the documentation-only flag should be set for all non-Perl and non-XS code (eg. 'README', 'Todo', ...)
#
#       - release this to CPAN as CPAN::Mini::Grep   and CPAN::Mini::Grep::HTML
#
#       - add flags to search different domains:
#               Perl code only, no comments
#               Perl code only, comments included
#               POD only (which includes both .pod files, as well as Perl code with POD interspersed)
#               XS code only
#               EVERYTHING / unrestricted
#
#       - (possibly)  in a fork of this script:  add search-indexing functionality, at least to be able to narrow down the search?
#               - KinoSearch looks good


    use strict;
    use warnings;

    use Archive::Tar        ();     # Perl core
    use CGI::Tiny           ();
    use File::Basename      ();     # Perl core
    use Pod::Parser         ();     # Perl core
    use Text::LineNumber    ();

    use Data::Dumper;               # Perl core


    # the location of your CPAN::Mini mirror
    my $mirror_location = '/home/ubuntu/minicpan/mirror/authors/';
    my $log_location = 'logs/';


my $eval_pattern = shift or die <<"EOF";
    Please specify a Perl snippet of regexp(es), for matching files.

    For example:
        $0 '/matches_something/ && /matches_something_else/'
EOF

-d $mirror_location or die "\$mirror_location is set incorrectly ($mirror_location)\n";

$Archive::Tar::WARN = 0;        # quiet warning messages

my $log_filename = "${log_location}grep." . time();
tee($log_filename);

print "   Searching for:  $eval_pattern\n";
print "HTML result file:  $log_filename.html\n";
# see https://github.com/DeeNewcum/dotfiles/blob/master/bin/url
my $url = `url $log_filename.html 2>/dev/null`;
if ($url) {
    $url =~ s#/$##;     # I'm not sure why 'url' does this
    print "HTML result file:  $url";
}
print "\n";

open my $html, '>', "$log_filename.html"        or die $!;
my $prev_file = select($html);
$|++;       # enable autoflush
select($prev_file);
html_header();



my @archives;
open PIN, "-|", "find", $mirror_location, "-type", "f", "-o", "-type", "l"
        or die $!;
while (<PIN>) {
    chomp;
    next if (m#/(?:CHECKSUMS|RECENT)$#);        # these are text files
    if (/\.(?:tar\.gz|tgz|tar\.bz2)$/i) {
        push(@archives, $_)     
    } else {
        ################## TODO -- we need to be able to process .zip files and .pm.gz files too ##################
        #warn "Unable to process $_\n";
    }
}

# sort by distribution name -- without this, the results end up being sorted by author name
        sub distribution_name {  local $_ = shift;  s#^.*/##;  $_  }
@archives = sort {lc(distribution_name($a)) cmp lc(distribution_name($b))} @archives;

foreach my $archive (@archives) {
    search_archive($archive);
}



##################################################################
## process each tarball / zip file / bzipball in local CPAN mirror
##################################################################
sub search_archive {
    my $tarball = shift;

    #print "============== $tarball ==============\n";

    # tarballs that we get hung up on for one reason or another
    return if ($tarball =~ m#/Lingua-StanfordCoreNLP-#);

    # Archive::Tar is able to handle gzip compression and bzip2 compression, and it seems to handle
    # .zip files too?
    my $tar = Archive::Tar->new($tarball);

    foreach my $filename ($tar->list_files()) {
        #next unless (filename_filter($filename));
        (my $filename_sans_package = $filename) =~ s#^[^/]*/##s;
        next unless (filename_filter($filename_sans_package));

        my $contents = $tar->get_content($filename);

        ### CONFIGURATION:  enable or disable this (currently manually, later via flags)
        #$contents = remove_pod($contents);                     

        next unless ($contents);
        my $is_match = -1;
        {
            local $_ = $contents;
            $is_match = eval "$eval_pattern; return \$-[0]";
        }
        #if ($contents =~ /$pattern/o) {
        if (defined($is_match) && $is_match > 0) {
            my $text_module = Text::LineNumber->new($contents);
            my $line_pos = $text_module->off2lnr($is_match);

            my $module;
            #$module = parse_package_name($contents)     if ($filename =~ /\.pm$/);
            $module = get_Pod_NAME_module__from_string($contents)    if ($filename =~ /\.(?:pm|pod)$/);
            print_hit($tarball, $module, $filename, $line_pos);
        }
    }
}


sub filename_filter {
    local $_ = shift;

    ### CONFIGURATION:  enable or disable these (currently manually, later via flags)

    # only search .xs files
    #return (/\.xs$/);

    #return unless (/\.pm$/);
    return if (/^META\.yml$|^Meta\.json$|^Build\.PL$|^Makefile\.PL$|^dist.ini$|^Changes$/);

    return if (m#^inc/#si);
    return if (m#^t/#si || /\.t$/);

    return 1;
}


# get the name of the first package defined in the provided Perl source code
sub parse_package_name {
    my ($file_contents) = @_;

    if ($file_contents =~ /\bpackage\s+([a-z][a-z0-9:_]*)\s*;/si) {
        return $1;
    }
    return undef;
}



BEGIN {
    our %seen;

    ############################################################
    ## print a single search result, a single row in the table
    ############################################################
    sub print_hit {
        my ($tarball, $module, $inside_filename, $line) = @_;

        my $author = File::Basename::basename(File::Basename::dirname($tarball));

        #print Dumper \@_, $author; exit;

        (my $distribution = $tarball) =~ s#.*/##;
        $distribution =~ s/\.(?:tar\.gz|tgz|tar\.bz2)$//;
        my $distro_with_version = $distribution;
        $distribution =~ s/-[0-9\.]+$//s;

        $inside_filename =~ s#^[^/]*/##s;

        $module = '-' unless (defined($module) && $module =~ /\S/);

        printf "%-40s  %-40s  %s\n", $distribution, $module, $inside_filename;

        print $html "<tr><td><a href='https://metacpan.org/dist/$distribution'>$distribution</a>\n";
        if ($module eq '-') {
            print $html "    <td><a href='https://metacpan.org/release/$author/$distro_with_version/'>-</a>\n";
        } else {
            print $html "    <td><a href='https://metacpan.org/pod/$module'>$module</a>\n";
        }
        print $html "    <td><a href='https://metacpan.org/dist/$distribution/source/$inside_filename#L$line'>$inside_filename</a>\n";
    }
}




# replicate everything that goes to STDOUT to a file too  (uses a forked subprocess)
use autodie;
sub tee {
    my ($filename) = @_;
    open my $origstdout, '>&STDOUT';
    open my $fh, ">$filename";
    if (!open STDOUT, '|-') {
        ## child process
        while (sysread(STDIN, my $buffer, 1024)) {
            syswrite($origstdout, $buffer);
            syswrite($fh, $buffer);
        }
        exit;
    }
    ## parent process continues on and returns
    close $origstdout;
    close $fh;
}


# quickly read a whole file
sub slurp {my$p=open(my$f,"$_[0]")or die$!;my@o=<$f>;close$f;waitpid($p,0);wantarray?@o:join("",@o)}

# display a string to the user, via less
sub less {my$pid=open my$less,"|less";print$less @_;close$less;waitpid$pid,0}





# Avoid searching documentation-only text, by removing it.
#
# PerlTidy's --delete-pod and --delete-all-comments could also be used for this
sub remove_pod {
    my $perl_code = shift;

    my $fh = IO::String->new($perl_code);
    open my $devnull, ">/dev/null"  or die $!;

    my $parser = Pod::Parser::RemovePod->new();
    $parser->parseopts(-want_nonPODs => 1);
    $parser->{NonPod} = '';
    $parser->parse_from_filehandle($fh, $devnull);
    return $parser->{NonPod};
}




sub html_header {
    print $html <<'EOF';
<style>
    /* --==##  links aren't underlined unless you :hover  ##==-- */
    a:hover {text-decoration:underline}
    a {text-decoration:none}
    @media print { a {text-decoration:underline} }

    /* --==##  make h1/h2/h3 stand out with bars  ##==-- */
    h1, h2, h3 {padding:0.3em; border-top:2px solid #000; border-bottom:2px solid #000;
    background-color:#ccc; margin-top:2em}
    body>h1:first-child, body>h2:first-child, body>h3:first-child {margin-top:0}

    /* --==##  table cells have a nice border  ##==-- */
    table.wikitable {border-collapse:collapse}
    table.wikitable td, table.wikitable th {border:1px solid #aaa; padding:0.3em}
    table.wikitable th {background-color:#000; color:#fff}
    table.wikitable th a {color:#aaf}
    table.wikitable th a:visited {color:#faf}

    /* --==##  kbd has gray background  ##==-- */
    kbd {background-color:#bbb}

    /* --==##  selectively make ul/ol spaced (non-cascading)  ##==-- */
    ul.spaced > li, ol.spaced > li {margin-bottom:1em}
    .spaced > li > .spaced {margin-top:1em}

    /* --==##  CSS reset  ##==-- */
    a img {border:0}
</style>


EOF

    print $html "<p><b>Results for:</b> <kbd>", CGI::Tiny::escape_html($eval_pattern), "</kbd>";
    print $html "<p><br><table class=wikitable>\n";
}


BEGIN {
    package Pod::Parser::RemovePod;

        use vars qw[@ISA];
        @ISA = ("Pod::Parser");
        use Pod::Parser;

    sub preprocess_paragraph {
        my ($self, $text, $line_num) = @_;

        if ($self->cutting()) {
            #print "$text\n";
            $self->{NonPod} .= $text;
        }

        return $text;
    }

    # quelch POD parse errors
    sub errorsub {
        sub { 1 };
    }

}



# use Pod::Select;
# use IO::String;
# 
# # Given a file with POD documentation in it,
# # looks for the NAME section, and if there, looks for a module name
# # there, using the semi-standard formatting of (module name)(dash).
# # Return it if it's found, otherwise return undef.
# sub get_Pod_NAME_module {
#     my ($fh_or_filename) = @_;
# 
#     my $out = new IO::String;
# 
#     podselect({-output => $out, -sections => ["NAME"]}, $fh_or_filename);
# 
#     my $NAME_section = ${ $out->string_ref };
# 
#     if ($NAME_section) {
#         $NAME_section =~ s/^.*?[\n\r]+//s;
#         if ($NAME_section =~ /^(\S+)\s+-\s+/s) {
#             return $1;
#         }
#     }
#     return undef;
# }



use Pod::Simple::SimpleTree ();     # Perl core

sub get_Pod_NAME_module__from_string {
    my ($file_contents) = @_;

    my $tree = Pod::Simple::SimpleTree->new->parse_string_document($file_contents);

    my $return_next_one = 0;
    foreach my $token ( @{$tree->{root}} ) {
        next unless (ref($token) eq 'ARRAY');

        if ($token->[0] eq 'head1' && $token->[2] eq 'NAME') {
            $return_next_one++;
            next;
        }
        if ($return_next_one && $token->[0] eq 'Para') {
            my $NAME_section = $token->[2];
            if ($NAME_section =~ /^(\S+)\s+-\s+/s) {
                return $1;
            }
            return undef;
        }
    }
    return undef;
}
